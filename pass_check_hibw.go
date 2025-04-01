package main

import (
        "bufio"
        "bytes"
        "crypto/sha1"
        // "errors" - Removed unused import
        "flag"
        "fmt"
        "io"
        "log"
        "net/http"
        "os"
        "os/exec"
        "os/user"
        "path/filepath"
        "strings"
        "sync"
        "time"
)

const (
        hibpApiUrl    = "https://api.pwnedpasswords.com/range/"
        userAgent     = "Go-Pass-Pwned-Checker/1.0" // Remember to set a descriptive User-Agent
        numWorkers    = 10                          // Number of concurrent checkers
        colorRed      = "\033[31m"
        colorGreen    = "\033[32m"
        colorYellow   = "\033[33m"
        colorBlue     = "\033[34m"
        colorReset    = "\033[0m"
)

// CheckInput now only needs the entry name relative to the store root
type CheckInput struct {
        EntryName string
}

type CheckResult struct {
        EntryName string
        IsPwned   bool
        Error     error
        Skipped   bool // Flag to indicate if processing was skipped (e.g., empty password/decryption error)
}

// Map to store decrypted passwords before checking
var decryptedPasswords map[string]string

// Global password store path needed for decryption
var globalPasswordStorePath string

func main() {
        log.SetFlags(0) // Remove timestamp prefix from log messages

        // Check if input is being piped
        stat, _ := os.Stdin.Stat()
        isPiped := (stat.Mode() & os.ModeCharDevice) == 0

        if isPiped {
                handlePipeMode()
        } else {
                handleFullScanMode()
        }
}

// handlePipeMode reads from stdin and checks the first line as a password.
func handlePipeMode() {
        scanner := bufio.NewScanner(os.Stdin)
        if scanner.Scan() {
                password := scanner.Text()
                if password == "" {
                        fmt.Fprintf(os.Stderr, "%sReceived empty password from stdin.%s\n", colorYellow, colorReset)
                        os.Exit(0)
                }
                isPwned, err := checkPasswordPwned(password)
                if err != nil {
                        fmt.Fprintf(os.Stderr, "%sError checking password: %v%s\n", colorRed, err, colorReset)
                        os.Exit(2)
                }
                if isPwned {
                        fmt.Printf("%sPWNED!%s\n", colorRed, colorReset)
                        os.Exit(1)
                } else {
                        fmt.Printf("%sSAFE.%s\n", colorGreen, colorReset)
                        os.Exit(0)
                }
        }
        if err := scanner.Err(); err != nil {
                fmt.Fprintf(os.Stderr, "%sError reading from stdin: %v%s\n", colorRed, err, colorReset)
                os.Exit(2)
        }
        fmt.Fprintf(os.Stderr, "%sNo input received from stdin.%s\n", colorYellow, colorReset)
        os.Exit(0)
}

// handleFullScanMode scans the password store.
func handleFullScanMode() {
        passDir := flag.String("pass-dir", "", "Path to password store directory (default: ~/.password-store)")
        verbose := flag.Bool("verbose", false, "Enable verbose output for debugging")
        flag.Parse()

        var err error
        globalPasswordStorePath, err = getPasswordStorePath(*passDir) // Set global path
        if err != nil {
                log.Fatalf("%sError determining password store path: %v%s", colorRed, err, colorReset)
        }

        // Check if the directory actually exists
        if _, err := os.Stat(globalPasswordStorePath); os.IsNotExist(err) {
                log.Fatalf("%sPassword store directory not found: %s%s", colorRed, globalPasswordStorePath, colorReset)
        } else if err != nil {
                log.Fatalf("%sError accessing password store directory %s: %v%s", colorRed, globalPasswordStorePath, err, colorReset)
        }

        fmt.Printf("%sUsing password store: %s%s\n", colorBlue, globalPasswordStorePath, colorReset)

        // --- Step 1: List entries using filesystem walk ---
        fmt.Printf("%sScanning for .gpg files...%s\n", colorBlue, colorReset)
        entries, err := listPassEntries(globalPasswordStorePath)
        if err != nil {
                log.Fatalf("%sError finding password files: %v%s", colorRed, err, colorReset)
        }

        fmt.Printf("%sFound %d password files. Decrypting...%s\n", colorBlue, len(entries), colorReset)
        fmt.Printf("%sNote: This relies on gpg-agent caching. You may be prompted for your passphrase.%s\n", colorYellow, colorReset)

        // --- Step 2: Decrypt and Show Progress ---
        decryptedPasswords = make(map[string]string) // Initialize the global map
        decryptionSkippedCount := 0 // Count files that decrypted but were empty
        decryptionErrorCount := 0   // Count actual GPG errors

        // Set up a progress indicator
        total := len(entries)
        processed := 0

        for _, entryName := range entries {
                // Show progress
                processed++
                if processed%10 == 0 || processed == total {
                        fmt.Printf("\r%sDecrypting: %d/%d (%d%%)%s", 
                                colorBlue, processed, total, (processed*100)/total, colorReset)
                }

                // Construct full path for decryption
                fullPath := filepath.Join(globalPasswordStorePath, entryName+".gpg")
                if *verbose {
                        fmt.Printf("\nProcessing: %s\n", entryName)
                }

                password, err := decryptGpgFile(fullPath)

                if err != nil {
                        // Only show detailed error in verbose mode
                        if *verbose {
                                fmt.Fprintf(os.Stderr, "%sWarning: Failed to decrypt %s: %v%s\n", 
                                        colorYellow, entryName, err, colorReset)
                        }
                        decryptionErrorCount++
                        continue // Skip this file
                }

                if password == "" {
                        // File decrypted successfully but was empty
                        if *verbose {
                                fmt.Fprintf(os.Stderr, "%sSkipping empty password in %s%s\n", 
                                        colorYellow, entryName, colorReset)
                        }
                        decryptionSkippedCount++
                        continue // Skip empty passwords
                }

                decryptedPasswords[entryName] = password // Store password keyed by relative entry name
        }
        fmt.Println() // Finish the progress line

        actualToProcess := len(decryptedPasswords)
        if actualToProcess == 0 {
                fmt.Printf("%sNo non-empty passwords found after decryption phase (skipped: %d, errors: %d).%s\n", 
                        colorYellow, decryptionSkippedCount, decryptionErrorCount, colorReset)
                return
        }

        fmt.Printf("%sSuccessfully decrypted %d passwords. Checking against HIBP...%s\n", 
                colorGreen, actualToProcess, colorReset)

        // --- Step 3: Concurrency Setup for HIBP Checks ---
        var wg sync.WaitGroup
        // Jobs channel now sends only the entry name (key to the map)
        jobs := make(chan string, actualToProcess)
        results := make(chan CheckResult, actualToProcess)

        // Start workers
        for w := 1; w <= numWorkers; w++ {
                wg.Add(1)
                go hibpCheckWorker(w, jobs, results, &wg) // Use the new worker function
        }

        // Send jobs (entry names)
        for entryName := range decryptedPasswords {
                jobs <- entryName
        }
        close(jobs) // No more jobs to send

        // Wait for all workers to finish
        wg.Wait()
        close(results) // No more results expected

        // --- Step 4: Process HIBP Check Results ---
        pwnedCount := 0
        hibpErrorCount := 0
        checkedCount := 0

        fmt.Println("\n--- HIBP Check Results ---")
        for result := range results {
                // We should only get results for entries that had passwords now
                checkedCount++
                if result.Error != nil {
                        fmt.Printf("%sError checking '%s' against HIBP: %v%s\n", colorYellow, result.EntryName, result.Error, colorReset)
                        hibpErrorCount++
                } else if result.IsPwned {
                        fmt.Printf("%sPWNED: '%s'%s\n", colorRed, result.EntryName, colorReset)
                        pwnedCount++
                }
        }

        fmt.Println("\n--- Final Summary ---")
        fmt.Printf("%sPassword Files Found: %d%s\n", colorBlue, len(entries), colorReset)
        fmt.Printf("%sDecryption Errors: %d%s\n", colorYellow, decryptionErrorCount, colorReset)
        fmt.Printf("%sEmpty/Skipped Files: %d%s\n", colorYellow, decryptionSkippedCount, colorReset)
        fmt.Printf("%sPasswords Checked: %d%s\n", colorBlue, checkedCount, colorReset)
        fmt.Printf("%sPwned Found:   %d%s\n", colorRed, pwnedCount, colorReset)
        if hibpErrorCount > 0 {
                fmt.Printf("%sHIBP Check Errors: %d%s\n", colorYellow, hibpErrorCount, colorReset)
        }
        fmt.Printf("%sScan complete.%s\n", colorGreen, colorReset)

        if pwnedCount > 0 {
                os.Exit(1) // Exit with error code if passwords are pwned
        }
}

// hibpCheckWorker function processes HIBP checks using pre-decrypted passwords
func hibpCheckWorker(id int, jobs <-chan string, results chan<- CheckResult, wg *sync.WaitGroup) {
        defer wg.Done()
        for entryName := range jobs {
                password, ok := decryptedPasswords[entryName]
                if !ok || password == "" {
                        // This case should ideally not be reached if decryption logic is correct
                        results <- CheckResult{EntryName: entryName, Skipped: true}
                        continue
                }

                // Check the password against HIBP
                isPwned, checkErr := checkPasswordPwned(password)
                results <- CheckResult{EntryName: entryName, IsPwned: isPwned, Error: checkErr, Skipped: false}

                // Optional delay to be nice to the API
                // time.Sleep(50 * time.Millisecond)
        }
}

// getPasswordStorePath determines the correct path for the password store.
func getPasswordStorePath(passDirFlag string) (string, error) {
        if passDirFlag != "" {
                absPath, err := filepath.Abs(passDirFlag)
                if err != nil {
                        return "", fmt.Errorf("invalid path specified in -pass-dir: %w", err)
                }
                if _, statErr := os.Stat(absPath); os.IsNotExist(statErr) {
                        return "", fmt.Errorf("specified pass-dir does not exist: %s", absPath)
                } else if statErr != nil {
                        return "", fmt.Errorf("error accessing specified pass-dir %s: %w", absPath, statErr)
                }
                return absPath, nil
        }
        if envDir := os.Getenv("PASSWORD_STORE_DIR"); envDir != "" {
                absPath, err := filepath.Abs(envDir)
                if err != nil {
                        return "", fmt.Errorf("invalid path in PASSWORD_STORE_DIR env var: %w", err)
                }
                if _, statErr := os.Stat(absPath); os.IsNotExist(statErr) {
                        return "", fmt.Errorf("PASSWORD_STORE_DIR does not exist: %s", absPath)
                } else if statErr != nil {
                        return "", fmt.Errorf("error accessing PASSWORD_STORE_DIR %s: %w", absPath, statErr)
                }
                return absPath, nil
        }
        usr, err := user.Current()
        if err != nil {
                return "", err
        }
        defaultPath := filepath.Join(usr.HomeDir, ".password-store")
        // Check existence in the main function now
        return defaultPath, nil
}

// listPassEntries finds all .gpg files in the password store by directly walking the filesystem.
// Returns relative entry names (without the .gpg extension) suitable for pass operations.
func listPassEntries(passDir string) ([]string, error) {
        var entries []string
        err := filepath.Walk(passDir, func(path string, info os.FileInfo, err error) error {
                if err != nil {
                        return err // Pass errors up the chain
                }

                // Skip directories and non-.gpg files
                if info.IsDir() || !strings.HasSuffix(info.Name(), ".gpg") {
                        return nil
                }

                // Calculate the relative path from the passDir
                relPath, err := filepath.Rel(passDir, path)
                if err != nil {
                        return err
                }

                // Remove the .gpg extension and add to entries
                entry := strings.TrimSuffix(relPath, ".gpg")
                entries = append(entries, entry)
                return nil
        })

        if err != nil {
                return nil, fmt.Errorf("error scanning password store: %w", err)
        }

        if len(entries) == 0 {
                return nil, fmt.Errorf("no .gpg files found in password store at %s", passDir)
        }

        return entries, nil
}

// decryptGpgFile executes `gpg --decrypt <filePath>` and returns the first line.
// filePath should be the full absolute path to the .gpg file.
// Returns the password, or an empty string if decryption fails or file is empty.
func decryptGpgFile(filePath string) (string, error) {
        cmd := exec.Command("gpg", "--quiet", "--batch", "--decrypt", filePath)
        var out bytes.Buffer
        var stderr bytes.Buffer
        cmd.Stdout = &out
        cmd.Stderr = &stderr

        err := cmd.Run()
        if err != nil {
                // Return the error so the main loop can handle it properly
                return "", fmt.Errorf("gpg decryption failed: %w", err)
        }

        // Decryption command succeeded, now read the output
        scanner := bufio.NewScanner(&out)
        if scanner.Scan() {
                return scanner.Text(), nil // Return the first line (password)
        }
        if scanErr := scanner.Err(); scanErr != nil {
                // Error reading the output stream after successful decryption
                return "", fmt.Errorf("error reading gpg decrypt output: %w", scanErr)
        }
        // Decryption successful but file was empty
        return "", fmt.Errorf("password file is empty")
}

// checkPasswordPwned checks a single password against the HIBP Pwned Passwords API.
func checkPasswordPwned(password string) (bool, error) {
        // 1. Calculate SHA-1 hash
        h := sha1.New()
        if _, err := h.Write([]byte(password)); err != nil {
                return false, fmt.Errorf("failed to write password to hash: %w", err)
        }
        hashBytes := h.Sum(nil)
        hashString := fmt.Sprintf("%X", hashBytes) // Uppercase Hex

        // 2. Split hash into prefix (5 chars) and suffix
        if len(hashString) < 5 {
                return false, fmt.Errorf("unexpectedly short SHA1 hash generated") // Should not happen
        }
        prefix := hashString[:5]
        suffix := hashString[5:]

        // 3. Query HIBP API
        url := hibpApiUrl + prefix
        req, err := http.NewRequest("GET", url, nil)
        if err != nil {
                return false, fmt.Errorf("error creating request: %w", err)
        }
        req.Header.Set("User-Agent", userAgent)
        req.Header.Set("Add-Padding", "true") // Add padding for privacy

        client := &http.Client{Timeout: 15 * time.Second} // Use a reasonable timeout
        resp, err := client.Do(req)
        if err != nil {
                return false, fmt.Errorf("error making request to HIBP (%s): %w", url, err)
        }
        defer resp.Body.Close()

        // Handle rate limiting specifically
        if resp.StatusCode == http.StatusTooManyRequests {
                retryAfter := resp.Header.Get("Retry-After")
                // Give a more specific error message for rate limiting
                return false, fmt.Errorf("rate limited by HIBP API (wait %s seconds)", retryAfter)
        }

        if resp.StatusCode != http.StatusOK {
                bodyBytes, _ := io.ReadAll(resp.Body)
                return false, fmt.Errorf("HIBP API returned non-200 status for prefix %s: %d %s - Body: %s", prefix, resp.StatusCode, resp.Status, string(bodyBytes))
        }

        // 4. Check response body for the suffix
        scanner := bufio.NewScanner(resp.Body)
        for scanner.Scan() {
                line := scanner.Text()
                parts := strings.Split(line, ":")
                if len(parts) == 2 && strings.EqualFold(parts[0], suffix) { // Case-insensitive compare
                        return true, nil // Found the suffix!
                }
        }

        if err := scanner.Err(); err != nil {
                return false, fmt.Errorf("error reading HIBP response body for prefix %s: %w", prefix, err)
        }

        // Suffix not found in the response
        return false, nil
}
