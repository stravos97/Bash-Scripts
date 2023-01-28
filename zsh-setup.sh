#!/bin/bash

# Update package list
sudo apt-get update

# Check if Zsh is already installed
if ! command -v zsh >/dev/null 2>&1; then
    # Install Zsh
    sudo apt-get install zsh -y
else
    echo "Zsh is already installed"
fi

# Make Zsh the default shell
#chsh -s $(which zsh)

# Make Zsh the default shell for all users
if [ "$SHELL" != "/bin/zsh" ]; then
    chsh -s $(which zsh)
    echo "Zsh set as the default shell for all users"
else
    echo "Zsh is already set as the default shell for all users"
fi

# Check if Oh My Zsh is already installed
if [ ! -d ~/.oh-my-zsh ]; then
    # Install Oh My Zsh
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
    echo "Oh My Zsh is already installed"
fi

# Set Zsh as the default shell for the current user
if ! grep -Fxq "exec zsh" ~/.bashrc; then
    echo "exec zsh" >> ~/.bashrc
else
    echo "Zsh is already set as the default shell for the current user"
fi

# Check if .zshrc file exists
if [ -f ~/.zshrc ]; then
    # Check if the "plugins" line already exists in .zshrc
    if grep -q "^plugins=" ~/.zshrc; then
        # Replace the "plugins" line with the specified string
        sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions colored-man-pages zsh-completions zsh-history-substring-search pass zsh-syntax-highlighting)/' ~/.zshrc
    fi
else
    echo "~/.zshrc file does not exist. Please make sure it exists before running the script."
fi

#Check if the zsh-completions plugin is already cloned
if [ ! -d ~/.oh-my-zsh/custom/plugins/zsh-completions ]; then
    git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions
else
    echo "zsh-completions plugin is already cloned or there is a seperate issue cloning the repo from that source"
fi

#Check if the zsh-autosuggestions plugin is already cloned
if [ ! -d ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
else
    echo "zsh-autosuggestions plugin is already cloned or there is a seperate issue cloning the repo from that source"
fi

#Check if the zsh-syntax-highlighting plugin is already cloned
if [ ! -d ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
else
    echo "zsh-syntax-highlighting plugin is already cloned or there is a seperate issue cloning the repo from that source"
fi

#Check if the zsh-history-substring-search plugin is already cloned
if [ ! -d ~/.oh-my-zsh/custom/plugins/zsh-history-substring-search ]; then
    git clone https://github.com/zsh-users/zsh-history-substring-search ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-history-substring-search
else
    echo "zsh-history-substring-search plugin is already cloned or there is a seperate issue cloning the repo from that source"
fi

# Restart the terminal
exec zsh

source ~/.zshrc
