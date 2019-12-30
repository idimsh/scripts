## ~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/~/
## Git aliases
##
## Usage:
## echo -e "\n\n## idimsh bash aliases ####\n. /opt/git-aliases\n\n" | sudo tee -a /root/.bashrc /etc/skel/.bashrc /home/*/.bashrc
##
## To be sourced from .bashrc
## ~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\

# git update sub modules
alias gusm='git submodule update --init --recursive'

# git submodules update
alias gsmu='git submodule update --init --recursive'

# git log one line
alias glol='git log --oneline --max-count=30'

# git log formatted
alias gl='git log --pretty=format:"%C(auto,yellow)%h %C(auto,cyan)%>(20,trunc)%ad %C(auto,green)%<(20,trunc)%aN%C(auto,reset)%s%C(auto,red)% gD% D" --date=format:"%Y-%m-%d %H:%M:%S" --max-count=30'

## Git list by update time local
alias gupdl='git for-each-ref --sort=-committerdate refs/heads --format="%(HEAD)%(color:yellow)%(refname:short) %(color:bold green)%(committerdate:relative)|%(color:blue)%(subject)|%(color:magenta)%(authorname)%(color:reset)"'

## Git list by update time remote
alias gupdr='git for-each-ref --sort=-committerdate refs/remotes --format="%(HEAD)%(color:yellow)%(refname:short) %(color:bold green)%(committerdate:relative)|%(color:blue)%(subject)|%(color:magenta)%(authorname)%(color:reset)"'

########################################################
## Functions
function git_tag_delete_local () {
    local ans

    if [ -z "$1" ]; then
        echo "no tag given; pass the tag to delete as the first parameter" >&2
        return 1
    fi

    if [ -n "$2" ]; then
        ans="$2"
    else
        read -p "delete local tag [$1] (y/n) ? " ans
        echo
    fi
    if [ "$ans" != "y" ]; then
        echo "aborted" >&2
        return 1
    fi
    git tag -d $1
    if [ $? -ne 0 ]; then
        echo "error deleting local tag [$1]" >&2
        return 2
    fi
    return 0
}

function git_tag_delete_remote () {
  local ans

    if [ -z "$1" ]; then
        echo "no tag given; pass the tag to delete as the first parameter" >&2
        return 1
    fi

    if [ -n "$2" ]; then
        ans="$2"
    else
        read -p "delete remote tag [$1] (y/n) ? " ans
        echo
    fi
    if [ "$ans" != "y" ]; then
        echo "aborted" >&2
        return 1
    fi
    git push --delete origin $1
    if [ $? -ne 0 ]; then
        echo "error deleting remote tag [$1]" >&2
        return 2
    fi
    return 0
}

function git_tag_delete_all () {
    git_tag_delete_local "$1" "$2"
    rv=$?
    if [ $rv -eq 0 ] || [ $rv -eq 2 ]; then
        git_tag_delete_remote "$1" "$2"
        return $?
    fi
    return $rv
}
