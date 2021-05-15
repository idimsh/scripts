## ~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/
## Bash aliases for Ubuntu and Debian systems (mostly), called terminal enhancements
##
## Usage:
## echo -e "\n\n## idimsh bash aliases ####\n. /opt/bash-aliases\n\n" | sudo tee -a /root/.bashrc /etc/skel/.bashrc /home/*/.bashrc
##
## To be sourced from .bashrc for dark terminal background
## ~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\
export EDITOR=nano
export HISTSIZE=2000
export HISTCONTROL=ignoredups

if [ -f ~/.inputrc ]; then
    if ! grep -q "set bell-style none" ~/.inputrc; then
        echo "" >> ~/.inputrc
        echo "set bell-style none" >> ~/.inputrc
        echo "" >> ~/.inputrc
    fi
else
    echo "" >> ~/.inputrc
    echo "set bell-style none" >> ~/.inputrc
    echo "" >> ~/.inputrc
fi

export PS1='${debian_chroot:+($debian_chroot)}\[\033[1;31m\]\h\[\033[0m\]:\[\033[1;32m\]\w\[\033[0m\]\$ '

alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias grep='grep --color=auto'

alias chown='chown --preserve-root'
alias chmod='chmod --preserve-root'

alias ll='ls -lAph --color=auto'
alias lt='ls -lAph --color=auto -t'

alias ps1='ps -efH'
alias ps2='ps aux -H'

alias clear='echo -e "clear\ncup $(tput lines) 0"|tput -S'
alias ns='netstat -vntlp'

## apt-cache search
alias ac-s='apt-cache search'
## apt-cache search names only
alias ac-sn='apt-cache --names-only search'
## apt-cache show
alias ac-sh='apt-cache show'

#alias apt-get='apt-get -V'

## a trick from: https://wiki.archlinux.org/index.php/Sudo#Passing_aliases
## to pass aliases with 'sudo'
alias sudo='sudo '

alias dmysql='mysql --defaults-file=/etc/mysql/debian.cnf --default-character-set=utf8'

alias dmysqldump='mysqldump --defaults-file=/etc/mysql/debian.cnf --default-character-set=utf8 --opt --events --triggers --routines --tz-utc'

alias themysqldump='mysqldump --defaults-file=/etc/mysql/debian.cnf --default-character-set=utf8 --opt --events --triggers --routines --tz-utc --lock-all-tables --add-drop-database --databases'

export CFLAGS="-march=native -O3 -pipe"
export CXXFLAGS="${CFLAGS}"
########################################################
## Functions
function dmysql_drop_create () {
    local ans

    if [ -z "$1" ]; then
        echo "no database; pass the database name as the first parameter" >&2
        return 1
    fi

    read -p "delete database [$1] (y/n) ? " ans
    echo
    if [ "$ans" != "y" ]; then
        echo "aborted" >&2
        return 1
    fi
    dmysql -e "DROP DATABASE IF EXISTS $1"
    if [ $? -ne 0 ]; then
        echo "error DROPPING database [$1]" >&2
        return 1
    fi
    dmysql -e "CREATE DATABASE $1 DEFAULT CHARACTER SET utf8"
    if [ $? -ne 0 ]; then
        echo "error CREATING database [$1]" >&2
        return 1
    fi
    return 0
}

function duplicity_convert_date () {
    [ -n "$1" ] && date +'%Y-%m-%dT%H:%M:%S' --date "$1" || date +'%Y-%m-%dT%H:%M:%S'
}
########################################################

## Disable bell, from: https://serverfault.com/a/26408
## does not work on xterm, got: setterm: terminal xterm does not support --blength
#setterm -blength 0

# Directories colors are so dark
# @see https://askubuntu.com/questions/466198/how-do-i-change-the-color-for-directories-with-ls-in-the-console
LS_COLORS=$LS_COLORS:'di=0;36:' ; export LS_COLORS
