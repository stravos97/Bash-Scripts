#!/bin/bash

#Note this script has a dependency of zsh being your shell. If it's not modify this line "export PATH="/home/$USER/.local/bin:$PATH" >> ~/.zshrc" to point to your bashrc. Zsh can also be installed using the zsh-setup.sh script

# Check if the path "/home/$USER/.local/bin" exists in the $PATH variable
if [[ ":$PATH:" == *":/home/$USER/.local/bin:"* ]]; then
    echo "The path /home/$USER/.local/bin exists in the \$PATH variable."
else
    echo "The path /home/$USER/.local/bin does not exist in the \$PATH variable. Adding it to your ~/.zshrc file..."
    export PATH="/home/$USER/.local/bin:$PATH" >> ~/.zshrc
fi

videos=(
"https://www.youtube.com/watch?v=ZJCS1wqQKwI&list=WL&index=1"
"https://www.youtube.com/watch?v=V1bFr2SWP1I&list=WL&index=2"
"https://www.youtube.com/watch?v=XMbvcp480Y4&list=WL&index=3"
"https://www.youtube.com/watch?v=Gs2ocwf8gaM&list=WL&index=4"
"https://www.youtube.com/watch?v=isxvXITTLLY&list=WL&index=5"
"https://www.youtube.com/watch?v=HNpLuXOg7xQ&list=WL&index=6"
"https://www.youtube.com/watch?v=KXp6Ta0bWr4&list=WL&index=7"
"https://www.youtube.com/watch?v=q6-ZGAGcJrk&list=WL&index=8"
"https://www.youtube.com/watch?v=4om1rQKPijI&list=WL&index=9"
"https://www.youtube.com/watch?v=o6WgxEs1KMo&list=WL&index=10"
"https://www.youtube.com/watch?v=fmI_Ndrxy14&list=WL&index=11"
"https://www.youtube.com/watch?v=4z9TdDCWN7g&list=WL&index=12"
"https://www.youtube.com/watch?v=jWa_gPt9COA&list=WL&index=13"
"https://www.youtube.com/watch?v=EuPfXQEhomo&list=WL&index=14"
"https://www.youtube.com/watch?v=RYxVyxK2Rik&list=WL&index=15"
"https://www.youtube.com/watch?v=fGlnRahtqM0&list=WL&index=16"
"https://www.youtube.com/watch?v=Wga5A6R9BJg&list=WL&index=17"
"https://www.youtube.com/watch?v=Dcf36Ffwsa8&list=WL&index=18"
"https://www.youtube.com/watch?v=4wxUxPiNP9w&list=WL&index=19"
"https://www.youtube.com/watch?v=Q6omsDyFNlk&list=WL&index=20"
"https://www.youtube.com/watch?v=P1L-Jfhq2IQ&list=WL&index=21"
"https://www.youtube.com/watch?v=uMK0prafzw0&list=WL&index=22"
"https://www.youtube.com/watch?v=scTkQEP9_Bw&list=WL&index=23"
"https://www.youtube.com/watch?v=8Btm7g_I7O4&list=WL&index=24"
"https://www.youtube.com/watch?v=WIKqgE4BwAY&list=WL&index=25"
"https://www.youtube.com/watch?v=_mdMb6bRXt4&list=WL&index=26"
"https://www.youtube.com/watch?v=M0d4qM7gCH8&list=WL&index=27"
"https://www.youtube.com/watch?v=QzHXt6n1QhM&list=WL&index=28"
"https://www.youtube.com/watch?v=d9NF2edxy-M&list=WL&index=29"
"https://www.youtube.com/watch?v=UjEpw4O-WNI&list=WL&index=30"
"https://www.youtube.com/watch?v=cAnQQcIncq0&list=WL&index=31"
"https://www.youtube.com/watch?v=M8-vje-bq9c&list=WL&index=32"
"https://www.youtube.com/watch?v=urzWY6sqVGw&list=WL&index=33"
"https://www.youtube.com/watch?v=t4kkzsRJObE&list=WL&index=34"
"https://www.youtube.com/watch?v=hjJOQ7bBfCs&list=WL&index=35"
"https://www.youtube.com/watch?v=kPlhX6kcPC8&list=WL&index=36"
"https://www.youtube.com/watch?v=Nl4opbNt8_E&list=WL&index=37"
"https://www.youtube.com/watch?v=_mVW8tgGY_w&list=WL&index=38"
"https://www.youtube.com/watch?v=0JQ0xnJyb0A&list=WL&index=39"
"https://www.youtube.com/watch?v=K_xTet06SUo&list=WL&index=40"
"https://www.youtube.com/watch?v=vYV-XJdzupY&list=WL&index=41"
"https://www.youtube.com/watch?v=Q2meWkWqc-I&list=WL&index=42"
"https://www.youtube.com/watch?v=yzC4hFK5P3g&list=WL&index=43"
"https://www.youtube.com/watch?v=HEkerSi5Fig&list=WL&index=44"
"https://www.youtube.com/watch?v=Hh9yZWeTmVM&list=WL&index=45"
"https://www.youtube.com/watch?v=6YZlFdTIdzM&list=WL&index=46"
"https://www.youtube.com/watch?v=wq7ftOZBy0E&list=WL&index=47"
"https://www.youtube.com/watch?v=TI0DGvqKZTI&list=WL&index=48"
"https://www.youtube.com/watch?v=v8H3ATlY4qM&list=WL&index=49"
"https://www.youtube.com/watch?v=HtINGkFQL8M&list=WL&index=50"
"https://www.youtube.com/watch?v=ZnJ7uOK4nYg&list=WL&index=51"
"https://www.youtube.com/watch?v=n5c8mgsnrGE&list=WL&index=52"
"https://www.youtube.com/watch?v=osKkMKolWQ8&list=WL&index=53"
"https://www.youtube.com/watch?v=cJbNvCOpCME&list=WL&index=54"
"https://www.youtube.com/watch?v=5Fi3TK5s0pY&list=WL&index=55"
"https://www.youtube.com/watch?v=QD-HBDC6YtA&list=WL&index=56"
"https://www.youtube.com/watch?v=TP5Br2WUBNs&list=WL&index=57"
"https://www.youtube.com/watch?v=o9IJff64R-U&list=WL&index=58"
"https://www.youtube.com/watch?v=1pS-EdhFEac&list=WL&index=59"
"https://www.youtube.com/watch?v=n3Go8ub9a1k&list=WL&index=60"
"https://www.youtube.com/watch?v=MThhnNVncnY&list=WL&index=61"
"https://www.youtube.com/watch?v=5Fix7P6aGXQ&list=WL&index=62"
"https://www.youtube.com/watch?v=MQM7CNoAsBI&list=WL&index=63"
"https://www.youtube.com/watch?v=VMg4TgF5kyQ&list=WL&index=64"
"https://www.youtube.com/watch?v=qpIdoaaPa6U&list=WL&index=65"
"https://www.youtube.com/watch?v=1s74PBDvbcA&list=WL&index=66"
"https://www.youtube.com/watch?v=8zCwFCKOfJY&list=WL&index=67"
"https://www.youtube.com/watch?v=La3_VmvLkPU&list=WL&index=68"
"https://www.youtube.com/watch?v=_Fwf45pIAtM&list=WL&index=69"
"https://www.youtube.com/watch?v=ROhKkih6Z8Y&list=WL&index=70"
"https://www.youtube.com/watch?v=2dp511yXXjc&list=WL&index=71"
"https://www.youtube.com/watch?v=UU6uviZdveA&list=WL&index=72"
"https://www.youtube.com/watch?v=KpQMc_WItCY&list=WL&index=73"
"https://www.youtube.com/watch?v=QUBvVTNRp4Q&list=WL&index=74"
"https://www.youtube.com/watch?v=bVl3om0-GFE&list=WL&index=75"
"https://www.youtube.com/watch?v=4dF1uxUTYZI&list=WL&index=76"
"https://www.youtube.com/watch?v=8LZgzAZ2lpQ&list=WL&index=77"
"https://www.youtube.com/watch?v=sYeBnmwiWzA&list=WL&index=78"
"https://www.youtube.com/watch?v=DMH-GARKr1U&list=WL&index=79"
"https://www.youtube.com/watch?v=6-n_szx2XRE&list=WL&index=80"
"https://www.youtube.com/watch?v=1n-g0IhmNuQ&list=WL&index=81"
"https://www.youtube.com/watch?v=udra3Mfw2oo&list=WL&index=82"
"https://www.youtube.com/watch?v=kclXuc_J50Y&list=WL&index=83"
"https://www.youtube.com/watch?v=bPk9bSvQQoc&list=WL&index=84"
"https://www.youtube.com/watch?v=OulN7vTDq1I&list=WL&index=85"
"https://www.youtube.com/watch?v=u9Dg-g7t2l4&list=WL&index=86"
"https://www.youtube.com/watch?v=xEBXgfeKng4&list=WL&index=87"
"https://www.youtube.com/watch?v=Lg0ftVeXGkg&list=WL&index=88"
"https://www.youtube.com/watch?v=sEQf5lcnj_o&list=WL&index=89"
"https://www.youtube.com/watch?v=aFzeMMgHaLQ&list=WL&index=90"
"https://www.youtube.com/watch?v=D5kyjnlDNZs&list=WL&index=91"
"https://www.youtube.com/watch?v=tc1eirTklMI&list=WL&index=92"
"https://www.youtube.com/watch?v=ntM3P0a6Fs4&list=WL&index=93"
"https://www.youtube.com/watch?v=SUO0-YvZmVI&list=WL&index=94"
"https://www.youtube.com/watch?v=lvMhyO51Jv0&list=WL&index=95"
"https://www.youtube.com/watch?v=M37Zox4Ts2A&list=WL&index=96"
"https://www.youtube.com/watch?v=pIBoAh4OXhQ&list=WL&index=97"
"https://www.youtube.com/watch?v=B9gMJsvgzg4&list=WL&index=98"
"https://www.youtube.com/watch?v=VBBFDb0hC4Y&list=WL&index=99"
"https://www.youtube.com/watch?v=1YoYbpBGaJM&list=WL&index=100"
"https://www.youtube.com/watch?v=eVH1Y15omgE&list=WL&index=101"
"https://www.youtube.com/watch?v=w_HaezV0DqI&list=WL&index=102"
"https://www.youtube.com/watch?v=hnLsfnchbGs&list=WL&index=103"
"https://www.youtube.com/watch?v=hrpxwgSbnc4&list=WL&index=104"
"https://www.youtube.com/watch?v=XMCYNH1EJTg&list=WL&index=105"
"https://www.youtube.com/watch?v=AEIVhBS6baE&list=WL&index=106"
"https://www.youtube.com/watch?v=fBGSJ3sbivI&list=WL&index=107"
"https://www.youtube.com/watch?v=HGbW44AEHeM&list=WL&index=108"
"https://www.youtube.com/watch?v=EDZFMClmP24&list=WL&index=109"
"https://www.youtube.com/watch?v=A7lxd7RL1To&list=WL&index=110"
"https://www.youtube.com/watch?v=9h5vLqHky7w&list=WL&index=111"
"https://www.youtube.com/watch?v=aH5aq4V0Ywk&list=WL&index=112"
"https://www.youtube.com/watch?v=qWzq4l_ZtPA&list=WL&index=113"
"https://www.youtube.com/watch?v=e5EGMW5PJ08&list=WL&index=114"
"https://www.youtube.com/watch?v=Q_Knzwe15PY&list=WL&index=115"
"https://www.youtube.com/watch?v=3zCg-RtmjGk&list=WL&index=116"
"https://www.youtube.com/watch?v=r2O0G_llw1k&list=WL&index=117"
"https://www.youtube.com/watch?v=86OleyaP2xA&list=WL&index=118"
"https://www.youtube.com/watch?v=Lzp7YIbbWgY&list=WL&index=119"
"https://www.youtube.com/watch?v=9Jy8pK7tTzg&list=WL&index=120"
"https://www.youtube.com/watch?v=gXEIRq4xRqw&list=WL&index=121"
"https://www.youtube.com/watch?v=5D_RekMvRwQ&list=WL&index=122"
"https://www.youtube.com/watch?v=ZrhFEBLWHs4&list=WL&index=123"
"https://www.youtube.com/watch?v=7NoPDyOEYkQ&list=WL&index=124"
"https://www.youtube.com/watch?v=y5zQTmkY7GI&list=WL&index=125"
"https://www.youtube.com/watch?v=HBN21pD3Dig&list=WL&index=126"
"https://www.youtube.com/watch?v=P_SlAzsXa7E&list=WL&index=127"
"https://www.youtube.com/watch?v=DXoj5KIyJSo&list=WL&index=128"
"https://www.youtube.com/watch?v=-ZCVCSApdAI&list=WL&index=129"
"https://www.youtube.com/watch?v=wxGA4h7eOC8&list=WL&index=130"
"https://www.youtube.com/watch?v=ZnZEoOJ-cxE&list=WL&index=131"
"https://www.youtube.com/watch?v=F4Zu5ZZAG7I&list=WL&index=132"
"https://www.youtube.com/watch?v=D-eVF_G_p-Y&list=WL&index=133"
"https://www.youtube.com/watch?v=mII9NZ8MMVM&list=WL&index=134"
"https://www.youtube.com/watch?v=KaNqCPGxJM0&list=WL&index=135"
"https://www.youtube.com/watch?v=vAgin9V80sQ&list=WL&index=136"
"https://www.youtube.com/watch?v=RNO3QqpcUH8&list=WL&index=137"
"https://www.youtube.com/watch?v=ZbM6WbUw7Bs&list=WL&index=138"
"https://www.youtube.com/watch?v=DfTUs-s_XkI&list=WL&index=139"
"https://www.youtube.com/watch?v=lSLR6uKTZX4&list=WL&index=140"
"https://www.youtube.com/watch?v=EFqjlSzBa7Y&list=WL&index=141"
"https://www.youtube.com/watch?v=cVO4Ism7_94&list=WL&index=142"
"https://www.youtube.com/watch?v=Kt_JePg86b8&list=WL&index=143"
"https://www.youtube.com/watch?v=4rWxrTpqnAc&list=WL&index=144"
"https://www.youtube.com/watch?v=fEmBCiEnREQ&list=WL&index=145"
"https://www.youtube.com/watch?v=O8pQYHSTeok&list=WL&index=146"
"https://www.youtube.com/watch?v=IKZSP-mvslk&list=WL&index=147"
"https://www.youtube.com/watch?v=t9Le57GzYA8&list=WL&index=148"
"https://www.youtube.com/watch?v=CR7TN-j4lY4&list=WL&index=149"
"https://www.youtube.com/watch?v=IRhS4Iux50E&list=WL&index=150"
"https://www.youtube.com/watch?v=7WO1eJv8JoE&list=WL&index=151"
"https://www.youtube.com/watch?v=1AULdtZ7y4c&list=WL&index=152"
"https://www.youtube.com/watch?v=atY2Z0J6zX8&list=WL&index=153"
"https://www.youtube.com/watch?v=7p1y7HmKVDQ&list=WL&index=154"
"https://www.youtube.com/watch?v=MFXYxusZEhM&list=WL&index=155"
"https://www.youtube.com/watch?v=nw5Mc5bpq-A&list=WL&index=156"
"https://www.youtube.com/watch?v=SOySR3DJO5Q&list=WL&index=157"
"https://www.youtube.com/watch?v=Lq6n7Hlgjw4&list=WL&index=158"
"https://www.youtube.com/watch?v=UqZwYFicVSU&list=WL&index=159"
"https://www.youtube.com/watch?v=1o8oIELbNxE&list=WL&index=160"
"https://www.youtube.com/watch?v=-8CbI1iG4To&list=WL&index=161"
"https://www.youtube.com/watch?v=n7G8dP38V2g&list=WL&index=162"
"https://www.youtube.com/watch?v=ytm00onkEjA&list=WL&index=163"
"https://www.youtube.com/watch?v=wPHxqp-K94c&list=WL&index=164"
"https://www.youtube.com/watch?v=4yEarx_vkqI&list=WL&index=165"
"https://www.youtube.com/watch?v=15ry8nvYLdQ&list=WL&index=166"
"https://www.youtube.com/watch?v=xjmyh_S4uQ0&list=WL&index=167"
"https://www.youtube.com/watch?v=IZs2i3Bpxx4&list=WL&index=168"
"https://www.youtube.com/watch?v=Y9rMafxR2mM&list=WL&index=169"
"https://www.youtube.com/watch?v=vnKZ4pdSU-s&list=WL&index=170"
"https://www.youtube.com/watch?v=VBmCJEehYtU&list=WL&index=171"
"https://www.youtube.com/watch?v=NUC2EQvdzmY&list=WL&index=172"
"https://www.youtube.com/watch?v=SBGFbsVO2YE&list=WL&index=173"
"https://www.youtube.com/watch?v=YthChN1Wq8M&list=WL&index=174"
"https://www.youtube.com/watch?v=YRD8jAk274I&list=WL&index=175"
"https://www.youtube.com/watch?v=0xc3XdOiGGI&list=WL&index=176"
"https://www.youtube.com/watch?v=ypWwCRGQ19w&list=WL&index=177"
"https://www.youtube.com/watch?v=9mw_BlW7LjM&list=WL&index=178"
"https://www.youtube.com/watch?v=jcifngvnh54&list=WL&index=179"
"https://www.youtube.com/watch?v=tz6WRiNwujQ&list=WL&index=180"
"https://www.youtube.com/watch?v=OpQFFLBMEPI&list=WL&index=181"
"https://www.youtube.com/watch?v=NR7-n-D2HhA&list=WL&index=182"
"https://www.youtube.com/watch?v=BR74ZadqjNA&list=WL&index=183"
"https://www.youtube.com/watch?v=zAPhp9LYq44&list=WL&index=184"
"https://www.youtube.com/watch?v=p2M8GzCBZkM&list=WL&index=185"
"https://www.youtube.com/watch?v=6QvMcQ2Eejo&list=WL&index=186"
"https://www.youtube.com/watch?v=TGaAIQr-ifI&list=WL&index=187"
"https://www.youtube.com/watch?v=eGq1BifpN2Y&list=WL&index=188"
"https://www.youtube.com/watch?v=xjWTr3H-Nfg&list=WL&index=189"
"https://www.youtube.com/watch?v=IoMby17t7cE&list=WL&index=190"
"https://www.youtube.com/watch?v=NHffhGkpgFA&list=WL&index=191"
"https://www.youtube.com/watch?v=jvipPYFebWc&list=WL&index=192"
"https://www.youtube.com/watch?v=bY3As3lKMno&list=WL&index=193"
"https://www.youtube.com/watch?v=QpNd9rIzMNo&list=WL&index=194"
"https://www.youtube.com/watch?v=jltM5qYn25w&list=WL&index=195"
"https://www.youtube.com/watch?v=ghyamhuKpd8&list=WL&index=196"
"https://www.youtube.com/watch?v=n3NHem937Xs&list=WL&index=197"
"https://www.youtube.com/watch?v=lkbWIfP3mLw&list=WL&index=198"
"https://www.youtube.com/watch?v=YkQ9ztLQzUg&list=WL&index=199"
"https://www.youtube.com/watch?v=IKaNodcBiLA&list=WL&index=200"
"https://www.youtube.com/watch?v=K27piaWwGXU&list=WL&index=201"
"https://www.youtube.com/watch?v=f9gqem723Lk&list=WL&index=202"
"https://www.youtube.com/watch?v=k4amY5uIyjo&list=WL&index=203"
"https://www.youtube.com/watch?v=npNc5P_66tQ&list=WL&index=204"
"https://www.youtube.com/watch?v=1j-PdKGz0qQ&list=WL&index=205"
"https://www.youtube.com/watch?v=bYMHQWE2Xzw&list=WL&index=206"
"https://www.youtube.com/watch?v=GZAZN5KihvQ&list=WL&index=207"
"https://www.youtube.com/watch?v=junBJZRDFzk&list=WL&index=208"
"https://www.youtube.com/watch?v=wHWbZmg2hzU&list=WL&index=209"
"https://www.youtube.com/watch?v=-BdbiZcNBXg&list=WL&index=210"
"https://www.youtube.com/watch?v=du035tg-SwY&list=WL&index=211"
"https://www.youtube.com/watch?v=naleynXS7yo&list=WL&index=212"
"https://www.youtube.com/watch?v=6qpudAhYhpc&list=WL&index=213"
"https://www.youtube.com/watch?v=IiQA3XSw5UM&list=WL&index=214"
"https://www.youtube.com/watch?v=BESJqphtp2U&list=WL&index=215"
"https://www.youtube.com/watch?v=jxstE6A_CYQ&list=WL&index=216"
"https://www.youtube.com/watch?v=UWS0tCM-sog&list=WL&index=217"
"https://www.youtube.com/watch?v=LPmclUWF8XE&list=WL&index=218"
"https://www.youtube.com/watch?v=MPR3o6Hnf2g&list=WL&index=219"
"https://www.youtube.com/watch?v=XoTx7Rt4dig&list=WL&index=220"
"https://www.youtube.com/watch?v=h6HLDV0T5Q8&list=WL&index=221"
"https://www.youtube.com/watch?v=Lg-wNxJ5XxY&list=WL&index=222"
"https://www.youtube.com/watch?v=BVomQtrtMTM&list=WL&index=223"
"https://www.youtube.com/watch?v=sqIHrGPCYfE&list=WL&index=224"
"https://www.youtube.com/watch?v=A3oNsutt3-o&list=WL&index=225"
"https://www.youtube.com/watch?v=eH4F1Tdb040&list=WL&index=226"
"https://www.youtube.com/watch?v=o55YRz_XS14&list=WL&index=227"
"https://www.youtube.com/watch?v=QJvayXD8HzI&list=WL&index=228"
"https://www.youtube.com/watch?v=i9sDXBTntNg&list=WL&index=229"
"https://www.youtube.com/watch?v=cjES8831wKc&list=WL&index=230"
"https://www.youtube.com/watch?v=LyBIT0Q7fOc&list=WL&index=231"
"https://www.youtube.com/watch?v=ScNjKTw9p2M&list=WL&index=232"
"https://www.youtube.com/watch?v=VucYNcP-jpI&list=WL&index=233"
"https://www.youtube.com/watch?v=EsXU9UC-3Xg&list=WL&index=234"
"https://www.youtube.com/watch?v=TeVTCnU7chU&list=WL&index=235"
"https://www.youtube.com/watch?v=tkm0TNFzIeg&list=WL&index=236"
"https://www.youtube.com/watch?v=WyGrnr4TRQs&list=WL&index=237"
"https://www.youtube.com/watch?v=iq7npmYlOK8&list=WL&index=238"
"https://www.youtube.com/watch?v=pQMnTULMslE&list=WL&index=239"
"https://www.youtube.com/watch?v=Vb7zejK_oTI&list=WL&index=240"
"https://www.youtube.com/watch?v=48f26CeT710&list=WL&index=241"
"https://www.youtube.com/watch?v=PKBbtr6bKMI&list=WL&index=242"
"https://www.youtube.com/watch?v=WOcwbAI-nHA&list=WL&index=243"
"https://www.youtube.com/watch?v=Uoieqb5zeAQ&list=WL&index=244"
"https://www.youtube.com/watch?v=xLT2gHkFj1Q&list=WL&index=245"
"https://www.youtube.com/watch?v=EJxGnCJMZc8&list=WL&index=246"
"https://www.youtube.com/watch?v=d7o8Zqh3JYQ&list=WL&index=247"
"https://www.youtube.com/watch?v=lJ1NYJQnJTI&list=WL&index=248"
"https://www.youtube.com/watch?v=jAGgKE82034&list=WL&index=249"
"https://www.youtube.com/watch?v=htd_DLRZDCs&list=WL&index=250"
"https://www.youtube.com/watch?v=WZjFMj7OHTw&list=WL&index=251"
"https://www.youtube.com/watch?v=6Ca-640qPKc&list=WL&index=252"
"https://www.youtube.com/watch?v=ISvclahE6J4&list=WL&index=253"
"https://www.youtube.com/watch?v=jxJnIKSlZq4&list=WL&index=254"
"https://www.youtube.com/watch?v=yAEmq_ydb7U&list=WL&index=255"
"https://www.youtube.com/watch?v=B53jiatsuBs&list=WL&index=256"
"https://www.youtube.com/watch?v=k1sjm9Yciu8&list=WL&index=257"
"https://www.youtube.com/watch?v=HH6Vg7Ob8oU&list=WL&index=258"
"https://www.youtube.com/watch?v=9mnoiRqh0dQ&list=WL&index=259"
"https://www.youtube.com/watch?v=S9eJgMOf4m0&list=WL&index=260"
"https://www.youtube.com/watch?v=o-YHCaBWN3s&list=WL&index=261"
"https://www.youtube.com/watch?v=7C_yCosO1_w&list=WL&index=262"
"https://www.youtube.com/watch?v=LKroRc-gZVA&list=WL&index=263"
"https://www.youtube.com/watch?v=WNXvFG98npU&list=WL&index=264"
"https://www.youtube.com/watch?v=l_T-l4f2w8g&list=WL&index=265"
"https://www.youtube.com/watch?v=_ti45faewW4&list=WL&index=266"
"https://www.youtube.com/watch?v=gDXCgKnNtvw&list=WL&index=267"
"https://www.youtube.com/watch?v=aydKPFaf4oY&list=WL&index=268"
"https://www.youtube.com/watch?v=daKaqfdE9wA&list=WL&index=269"
"https://www.youtube.com/watch?v=mmQKjCuHTlk&list=WL&index=270"
"https://www.youtube.com/watch?v=F-2hw0B7RK8&list=WL&index=271"
"https://www.youtube.com/watch?v=a1Yb3b4nEEY&list=WL&index=272"
"https://www.youtube.com/watch?v=26chN1qk0lk&list=WL&index=273"
"https://www.youtube.com/watch?v=71rSc6LXlSo&list=WL&index=274"
"https://www.youtube.com/watch?v=mkMVyw-7avI&list=WL&index=275"
"https://www.youtube.com/watch?v=ADKrmdO6zwY&list=WL&index=276"
"https://www.youtube.com/watch?v=xyd9V3GTljA&list=WL&index=277"
"https://www.youtube.com/watch?v=Qon6phzSGWQ&list=WL&index=278"
"https://www.youtube.com/watch?v=dDnwuokL07o&list=WL&index=279"
"https://www.youtube.com/watch?v=NK2gm8Xtmjc&list=WL&index=280"
"https://www.youtube.com/watch?v=CYnC9VhcAJA&list=WL&index=281"
"https://www.youtube.com/watch?v=JtPx5ABwwoo&list=WL&index=282"
"https://www.youtube.com/watch?v=MizSkQFw-yM&list=WL&index=283"
"https://www.youtube.com/watch?v=uUFhRg877Uk&list=WL&index=284"
"https://www.youtube.com/watch?v=aWVmRwnAJ98&list=WL&index=285"
"https://www.youtube.com/watch?v=E5RIuPrXuuE&list=WL&index=286"
"https://www.youtube.com/watch?v=a1oByfD1z4g&list=WL&index=287"
"https://www.youtube.com/watch?v=obmmlMpeRvs&list=WL&index=288"
"https://www.youtube.com/watch?v=uGeK-Op8ONc&list=WL&index=289"
"https://www.youtube.com/watch?v=Yi7QX1XEdiw&list=WL&index=290"
"https://www.youtube.com/watch?v=bDnfhYTWtpQ&list=WL&index=291"
"https://www.youtube.com/watch?v=7BZ0WUm_v54&list=WL&index=292"
"https://www.youtube.com/watch?v=W3dleyWCEaY&list=WL&index=293"
"https://www.youtube.com/watch?v=xgHwKU905rY&list=WL&index=294"
"https://www.youtube.com/watch?v=mayliqsE8J8&list=WL&index=295"
"https://www.youtube.com/watch?v=GJD-im_4xNI&list=WL&index=296"
"https://www.youtube.com/watch?v=wP0rMqOZ7ew&list=WL&index=297"
"https://www.youtube.com/watch?v=Wym7zVq_Qtw&list=WL&index=298"
"https://www.youtube.com/watch?v=VREoSPYVsYs&list=WL&index=299"
"https://www.youtube.com/watch?v=_PL-IGC58j8&list=WL&index=300"
"https://www.youtube.com/watch?v=Xb-XKrT4CrI&list=WL&index=301"
"https://www.youtube.com/watch?v=D-zMOcNxbbw&list=WL&index=302"
"https://www.youtube.com/watch?v=IRD7WylAfkw&list=WL&index=303"
"https://www.youtube.com/watch?v=vMTAAOtjFYY&list=WL&index=304"
"https://www.youtube.com/watch?v=Kna8tEwKugw&list=WL&index=305&t=8s"
"https://www.youtube.com/watch?v=7f_rC_7Icnc&list=WL&index=306"
"https://www.youtube.com/watch?v=yJTi33SfhRs&list=WL&index=307"
"https://www.youtube.com/watch?v=l_n9M3vLaY8&list=WL&index=308"
"https://www.youtube.com/watch?v=KTYD_kN7rPg&list=WL&index=309"
"https://www.youtube.com/watch?v=zSXj6SBF6-s&list=WL&index=310"
"https://www.youtube.com/watch?v=D0ag0dsP5B4&list=WL&index=311"
"https://www.youtube.com/watch?v=X6eqGrTiUnQ&list=WL&index=312"
"https://www.youtube.com/watch?v=0b7ILLNInuM&list=WL&index=313"
"https://www.youtube.com/watch?v=VjRb3RjqncQ&list=WL&index=314"
"https://www.youtube.com/watch?v=2FhTwukQj_A&list=WL&index=315"
"https://www.youtube.com/watch?v=6Z9J5cbtZzs&list=WL&index=316"
"https://www.youtube.com/watch?v=bU0tKzy5-uE&list=WL&index=317"
"https://www.youtube.com/watch?v=5CzkgVuFMyc&list=WL&index=318"
"https://www.youtube.com/watch?v=goJmzJFMgGA&list=WL&index=319"
"https://www.youtube.com/watch?v=1LwHBw0EXe8&list=WL&index=320"
"https://www.youtube.com/watch?v=SeHhGgfY0Co&list=WL&index=321"
"https://www.youtube.com/watch?v=6wnltXLB8R4&list=WL&index=322"
"https://www.youtube.com/watch?v=kDw7smaTsPo&list=WL&index=323"
"https://www.youtube.com/watch?v=bb6oJZy4vUw&list=WL&index=324"
"https://www.youtube.com/watch?v=bpl7uKpfkFU&list=WL&index=325"
"https://www.youtube.com/watch?v=eRl31s6bDgc&list=WL&index=326"
"https://www.youtube.com/watch?v=yP-9bG4Tcu8&list=WL&index=327"
"https://www.youtube.com/watch?v=Owz2Wr5cozo&list=WL&index=328"
"https://www.youtube.com/watch?v=ux23vKaYJ6Q&list=WL&index=329"
"https://www.youtube.com/watch?v=_JHhEh45FpA&list=WL&index=330"
"https://www.youtube.com/watch?v=sN9jC-_j3zc&list=WL&index=331"
"https://www.youtube.com/watch?v=FdjaffAnQb0&list=WL&index=332"
"https://www.youtube.com/watch?v=gShTNVT19I0&list=WL&index=333"
"https://www.youtube.com/watch?v=_pjODSCQ6qs&list=WL&index=334"
"https://www.youtube.com/watch?v=zLTb4i-yC3Y&list=WL&index=335"
"https://www.youtube.com/watch?v=Bsy6dQ3zp3Y&list=WL&index=336"
"https://www.youtube.com/watch?v=FzKYXj2j0eg&list=WL&index=337"
"https://www.youtube.com/watch?v=Rs9kg8cdNsA&list=WL&index=338"
"https://www.youtube.com/watch?v=mTyYpF_jevY&list=WL&index=339"
"https://www.youtube.com/watch?v=4d3C3IfUd60&list=WL&index=340"
"https://www.youtube.com/watch?v=U46GMF6r4zY&list=WL&index=341"
"https://www.youtube.com/watch?v=f8FAJXPBdOg&list=WL&index=342"
"https://www.youtube.com/watch?v=1vMo_A0yU3o&list=WL&index=343"
"https://www.youtube.com/watch?v=XJWrOUj9EqA&list=WL&index=344"
"https://www.youtube.com/watch?v=QrC7UUcUW1s&list=WL&index=345"
"https://www.youtube.com/watch?v=PbBFFCmrtRw&list=WL&index=346"
"https://www.youtube.com/watch?v=Snq2JskSNx4&list=WL&index=347"
"https://www.youtube.com/watch?v=LEYXdZ_rVbo&list=WL&index=348"
"https://www.youtube.com/watch?v=nYmd4AAbg0U&list=WL&index=349"
"https://www.youtube.com/watch?v=8LeaAljsy7s&list=WL&index=350"
"https://www.youtube.com/watch?v=Y9fgpquiGi0&list=WL&index=351"
"https://www.youtube.com/watch?v=iWnxbI9RFeQ&list=WL&index=352"
"https://www.youtube.com/watch?v=haEc8KhTD7Q&list=WL&index=353"
"https://www.youtube.com/watch?v=NkRYAs3WTx0&list=WL&index=354"
"https://www.youtube.com/watch?v=SU-JqbOojt4&list=WL&index=355"
"https://www.youtube.com/watch?v=T44y1hg-3SE&list=WL&index=356"
"https://www.youtube.com/watch?v=1pvpsWI_AhA&list=WL&index=357"
"https://www.youtube.com/watch?v=ycrneiNryNw&list=WL&index=358"
"https://www.youtube.com/watch?v=TuAfY2dCmVE&list=WL&index=359"
"https://www.youtube.com/watch?v=VYsHSAUU1I4&list=WL&index=360"
"https://www.youtube.com/watch?v=BZLGKFWlRzY&list=WL&index=361"
"https://www.youtube.com/watch?v=V4B5zH5pN8A&list=WL&index=362"
"https://www.youtube.com/watch?v=JIhKTxTWn5E&list=WL&index=363"
"https://www.youtube.com/watch?v=QnOxfN08Sfw&list=WL&index=364"
"https://www.youtube.com/watch?v=Zq1TBnm8o8E&list=WL&index=365"
"https://www.youtube.com/watch?v=DqNvIW-us-c&list=WL&index=366"
"https://www.youtube.com/watch?v=BIaF0QKtY0c&list=WL&index=367"
"https://www.youtube.com/watch?v=uAupiBZNrak&list=WL&index=368"
"https://www.youtube.com/watch?v=10NHycKVjs0&list=WL&index=369&t=67s"
"https://www.youtube.com/watch?v=3KL9mRus19o&list=WL&index=370"
"https://www.youtube.com/watch?v=EbH0ew1vTEg&list=WL&index=371"
"https://www.youtube.com/watch?v=RXM65yCN7Qg&list=WL&index=372&t=49s"
"https://www.youtube.com/watch?v=doHWn84loBc&list=WL&index=373"
"https://www.youtube.com/watch?v=_pjmEW0gLcs&list=WL&index=374"
"https://www.youtube.com/watch?v=W-R-zxwsqMI&list=WL&index=375"
"https://www.youtube.com/watch?v=rSL3LX8YYOw&list=WL&index=376"
"https://www.youtube.com/watch?v=H38XiM2EOnQ&list=WL&index=377&t=42s"
"https://www.youtube.com/watch?v=oiKj0Z_Xnjc&list=WL&index=378"
"https://www.youtube.com/watch?v=L14akHiy1IM&list=WL&index=379"
"https://www.youtube.com/watch?v=_4jsPCI6c-k&list=WL&index=380"
"https://www.youtube.com/watch?v=rRYQbMij5-8&list=WL&index=381"
"https://www.youtube.com/watch?v=kOWBuEtuw7Y&list=WL&index=382"
"https://www.youtube.com/watch?v=L1WqtBNnORM&list=WL&index=383"
"https://www.youtube.com/watch?v=ILSe9s4qGMU&list=WL&index=384"
"https://www.youtube.com/watch?v=6p6StlCS1-w&list=WL&index=385"
"https://www.youtube.com/watch?v=mr914IEIWPs&list=WL&index=386"
"https://www.youtube.com/watch?v=ButlB87ZFmE&list=WL&index=387"
"https://www.youtube.com/watch?v=gZM95ANQu98&list=WL&index=388"
"https://www.youtube.com/watch?v=lCfmzb2mMOw&list=WL&index=389"
"https://www.youtube.com/watch?v=iME5EiX1YZQ&list=WL&index=390"
"https://www.youtube.com/watch?v=vGJTaP6anOU&list=WL&index=391"
"https://www.youtube.com/watch?v=LETB9Xgjpzw&list=WL&index=392&t=84s"
"https://www.youtube.com/watch?v=wrrbEjJEVz4&list=WL&index=393"
"https://www.youtube.com/watch?v=nYB9ZJgh5dY&list=WL&index=394"
"https://www.youtube.com/watch?v=ByHWe68CsyU&list=WL&index=395"
"https://www.youtube.com/watch?v=Sy4pmi90yhY&list=WL&index=396"
"https://www.youtube.com/watch?v=aJUgMumuFJY&list=WL&index=397"
"https://www.youtube.com/watch?v=6rCvXbfEAbw&list=WL&index=398"
"https://www.youtube.com/watch?v=gjlZn3OLqlk&list=WL&index=399"
"https://www.youtube.com/watch?v=zxCDzEzA-bo&list=WL&index=400"
"https://www.youtube.com/watch?v=0bOUOCo6NLQ&list=WL&index=401"
"https://www.youtube.com/watch?v=zUCxAmrCK7w&list=WL&index=402"
"https://www.youtube.com/watch?v=_wHXJrE53DY&list=WL&index=403"
"https://www.youtube.com/watch?v=Ji0nW8awNBs&list=WL&index=404"
"https://www.youtube.com/watch?v=hqDinxaPUK4&list=WL&index=405"
"https://www.youtube.com/watch?v=nQobOSv2kzM&list=WL&index=406"
"https://www.youtube.com/watch?v=rTPK5qCKreM&list=WL&index=407"
	)


#Set the YouTube channel URL


playlist="Watch Later"
#Create a directory for the playlist

dir_name=$(echo $playlist)
mkdir $dir_name


for video in ${videos[@]}
do
  yt-dlp \
    --format "(bestaudio[acodec^=opus]/bestaudio)/best" \
    --no-playlist \
    --throttled-rate 100K \
    --sleep-requests 1 \
    --sleep-interval 5 \
    --downloader aria2c \
    --max-sleep-interval 30 \
    --write-thumbnail \
    --embed-thumbnail \
    --extract-audio \
    --add-metadata \
    --parse-metadata "%(title)s:%(meta_title)s" \
    --check-formats \
    --xattrs \
    --concurrent-fragments 5 \
    --sponsorblock-remove default \
    $video

	
$video
done



#Download the videos in the playlist


#Convert all videos in the directory to audio-only files

echo "$(date +'%Y-%m-%d %H:%M:%S') All playlists have been downloaded and converted to audio-only files." | tee -a $LOG_FILE

#script should only download from event etc playlist