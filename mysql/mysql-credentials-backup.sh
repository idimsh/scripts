#!/bin/bash
####
####
#### Script for MySQL credentials backup using DROP USER and GRANT commands
####
#### By Abdulrahman Dimashki <idimsh@gmail.com>
#### Created: 2011-06-13
#### Update-1: 2012-11-17
####  - set default file to be /etc/mysql/debian.cnf if no option is provided
####    for it and no '-u' option is passed.
####
#### ----------------------
####
####

##############################################################
## Preparation ###############################################
##############################################################
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

SCRIPT_NAME="$(cd $(dirname "$0"); pwd -P)/$(basename "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_NAME")"

_m_def_file= #mysql defaults-file
_m_user= #mysql user
_m_pass= #mysql pass
_m_host= #mysql host
_m_socket= #mysql socket
_m_port= #mysql port

df=/etc/mysql/debian.cnf

_excl=

##############################################################
##############################################################
function usage() {
  echo \
"
MySQL credentials backup Script, using DROP USER and GRANT commands,
by Dimsh <idimsh@gmail.com>

This script will print DROP USER ... GRANT commands for users defined
in the connected to MySQL engine.

Usage: $0 [< --defaults-file=<file> | -df=<file> >] [-e <excludes>] [-u <username>] [-p<password>] [-S <socket>] [-h <host>] [-P <port>]

  options:

    --defaults-file=<file>,
    -df=<file>             : ini file name which contains username, pass, and
                             other options used by MySQL client to connect to a
                             server, defaults to '$df'
                             if no username is provided via '-u' parameter.
    -e : comma seperated list of entries each represents an excluded username,
         hostname, or both (user@host).
         - An entry without an '@' sign is a username.
         - An entry starts with '@' sign is a hostname.
         - If the '@' sign is in the middle the entry is a user at host.
"
  exit 0
}

function startWithDash() {
  printf -- "$1" | egrep -q -- '^-' && return 0 || return 1
}

function escapeSingleQuote () {
  escapeSingleQuote_ret="$(printf -- "$1" | sed "s#'#\\\'#g")"
}

function trimString () {
  trimString_ret="$(printf -- "$1" | sed 's#^[ \t\r]\+##g' | sed 's#[ \t\r]\+$##g')"
}

function trimStringCommas () {
  trimStringCommas_ret="$(printf -- "$1" | sed 's#^[, \t\r]\+##g' | sed 's#[, \t\r]\+$##g')"
}

function exclUsers() {
  exclUsers_ret=""
  local wc_l
  local i
  local line

  printf -- "$1" | tr ',' '\n' > "$tmp1"
  wc_l=$(cat "$tmp1" | wc -l)
  [ -z "$wc_l" ] || [ $wc_l -eq 0 ] && return 0

  for i in $(seq 1 $wc_l)
  do
    line="$(head -n $i "$tmp1" | tail -n1)"
    if ! printf -- "$line" | egrep -q '@'; then
      escapeSingleQuote "$line"
      exclUsers_ret="${exclUsers_ret} '${escapeSingleQuote_ret}',"
    fi
  done

  trimStringCommas "$exclUsers_ret"
  exclUsers_ret="$trimStringCommas_ret"
}


function exclHosts() {
  exclHosts_ret=""
  local wc_l
  local i
  local line

  printf -- "$1" | tr ',' '\n' > "$tmp1"
  wc_l=$(cat "$tmp1" | wc -l)
  [ -z "$wc_l" ] || [ $wc_l -eq 0 ] && return 0

  for i in $(seq 1 $wc_l)
  do
    line="$(head -n $i "$tmp1" | tail -n1)"
    if printf -- "$line" | egrep -q '^@'; then
      line="$(printf -- "$line" | sed 's#^@##g')"
      escapeSingleQuote "$line"
      exclHosts_ret="${exclHosts_ret} '${escapeSingleQuote_ret}',"
    fi
  done

  trimStringCommas "$exclHosts_ret"
  exclHosts_ret="$trimStringCommas_ret"
}

function exclUsersAtHosts() {
  exclUsersAtHosts_ret=""
  local wc_l
  local i
  local line
  local line2

  printf -- "$1" | tr ',' '\n' > "$tmp1"
  wc_l=$(cat "$tmp1" | wc -l)
  [ -z "$wc_l" ] || [ $wc_l -eq 0 ] && return 0

  for i in $(seq 1 $wc_l)
  do
    line="$(head -n $i "$tmp1" | tail -n1)"
    if printf -- "$line" | egrep -q '^[^@]+@.'; then
      line2="$(printf -- "$line" | sed 's#^\([^@]\+\)@.*#\1#g')"
      escapeSingleQuote "$line2"
      exclUsersAtHosts_ret="${exclUsersAtHosts_ret} \"'${escapeSingleQuote_ret}'@"

      line2="$(printf -- "$line" | sed 's#^[^@]\+@\(.*\)#\1#g')"
      escapeSingleQuote "$line2"
      exclUsersAtHosts_ret="${exclUsersAtHosts_ret}'${escapeSingleQuote_ret}'\","
    fi
  done

  trimStringCommas "$exclUsersAtHosts_ret"
  exclUsersAtHosts_ret="$trimStringCommas_ret"
}


tmp1=/tmp/deleteme_$$_1
tmp2=/tmp/deleteme_$$_2
_exit_code=1
function my_exit() {
  exit $_exit_code
}
trap "rm -f $tmp1 $tmp2; my_exit" INT TERM EXIT

##############################################################
##############################################################
printf -- "$*" | egrep -q -- '(^| )(-h|--help)( |$)' && usage

while [ -n "$*" ]; do
  case "x$1" in
    x--defaults-file*)
      _m_def_file="$(echo $1|sed 's#^--defaults-file=\?##')"
      [ -z "$_m_def_file" ] && { shift; _m_def_file="$1"; }
      [ -z "$_m_def_file" ] || startWithDash "$_m_def_file" && { echo "command line option '--defaults-file' expects a file name paramter" >&2; _exit_code=1; exit $_exit_code; }
      ;;

    x-u*)
      _m_user="$(echo $1|sed 's#^-u##')"
      [ -z "$_m_user" ] && { shift; _m_user="$1"; }
      [ -z "$_m_user" ] || startWithDash "$_m_user" && { echo "command line option '-u' expects a user name paramter" >&2; _exit_code=1; exit $_exit_code; }
      ;;

    x-p*)
      _m_pass="$(echo $1|sed 's#^-p##')"
      [ -z "$_m_pass" ] && { shift; _m_pass="$1"; }
      [ -z "$_m_pass" ] || startWithDash "$_m_pass" && { echo "command line option '-p' expects a password paramter" >&2; _exit_code=1; exit $_exit_code; }
      ;;

    x-S*)
      _m_socket="$(echo $1|sed 's#^-S##')"
      [ -z "$_m_socket" ] && { shift; _m_socket="$1"; }
      [ -z "$_m_socket" ] || startWithDash "$_m_socket" && { echo "command line option '-S' expects a socket file name paramter" >&2; _exit_code=1; exit $_exit_code; }
      ;;

    x-P*)
      _m_port="$(echo $1|sed 's#^-P##')"
      [ -z "$_m_port" ] && { shift; _m_port="$1"; }
      [ -z "$_m_port" ] || startWithDash "$_m_port" && { echo "command line option '-P' expects port number paramter" >&2; _exit_code=1; exit $_exit_code; }
      ;;

    x-h*)
      _m_host="$(echo $1|sed 's#^-h##')"
      [ -z "$_m_host" ] && { shift; _m_host="$1"; }
      [ -z "$_m_host" ] || startWithDash "$_m_host" && { echo "command line option '-h' expects a hostname paramter" >&2; _exit_code=1; exit $_exit_code; }
      ;;

    x-e*)
      _excl="$(echo $1|sed 's#^-e##')"
      [ -z "$_excl" ] && { shift; _excl="$1"; }
      [ -z "$_excl" ] || startWithDash "$_excl" && { echo "command line option '-e' expects comma seperated list of paramter" >&2; _exit_code=1; exit $_exit_code; }
      ;;

    *)
      echo "invalid command line option '$1'" >&2
      _exit_code=2; exit $_exit_code
      ;;
  esac
  shift
done

if [ -n "$_m_def_file" ]; then
  cmd_opts="--defaults-file=${_m_def_file} --default-character-set=utf8"
else
  [ -n "$_m_user" ] && cmd_opts="--default-character-set=utf8" || cmd_opts="--defaults-file=${df} --default-character-set=utf8"
fi
[ -n "$_m_user" ] && cmd_opts=" ${cmd_opts} -u${_m_user}"
[ -n "$_m_pass" ] && cmd_opts=" ${cmd_opts} -p${_m_pass}"
[ -n "$_m_host" ] && cmd_opts=" ${cmd_opts} -h${_m_host}"
[ -n "$_m_port" ] && cmd_opts=" ${cmd_opts} -P${_m_port}"
[ -n "$_m_socket" ] && cmd_opts=" ${cmd_opts} -S${_m_socket}"

##############################################################
##############################################################

q="SELECT CONCAT(\"'\", user, \"'@'\", host, \"'\") as uh FROM mysql.user";

if [ -n "$_excl" ]; then

  exclUsers "$_excl"
  [ -n "$exclUsers_ret" ] && q="${q} WHERE user NOT IN ($exclUsers_ret)"

  exclHosts "$_excl"
  if [ -n "$exclHosts_ret" ]; then
    [ -z "$exclUsers_ret" ] && q="${q} WHERE" || q="${q} AND"
    q="${q} host NOT IN ($exclHosts_ret)"
  fi

  exclUsersAtHosts "$_excl"
  [ -n "$exclUsersAtHosts_ret" ] && q="${q} HAVING uh NOT IN ($exclUsersAtHosts_ret)"

fi

q="${q} ORDER BY user, host"

#echo -e "executing query:\n[$q]\n"
cmd_mysql="mysql ${cmd_opts} -BN"
cmd_mysql_safe="$(echo "$cmd_mysql" | sed 's# -p[^ ]*##g')"
mysql_users="$(echo "$q" | $cmd_mysql)"
[ $? -ne 0 ] && { echo "failed to get users list" >&2; echo "command: [$cmd_mysql_safe -e '$q'] failed" >&2; _exit_code=3; exit $_exit_code; }



echo "$mysql_users" > $tmp2
wc_l=$(cat "$tmp2" | wc -l)
[ -z "$wc_l" ] || [ $wc_l -eq 0 ] && { echo "no users found" >&2; _exit_code=4; exit $_exit_code; }

echo -en "" > $tmp1

for i in $(seq 1 $wc_l)
do
  uh="$(head -n $i "$tmp2" | tail -n1)"

  echo "GRANT USAGE ON *.* TO ${uh};" >> $tmp1
  # next line is for older MySQL servers which does not revoke when DROP is issued.
  echo "REVOKE ALL PRIVILEGES, GRANT OPTION FROM ${uh};" >> $tmp1
  echo "DROP USER ${uh};" >> $tmp1
  echo "" >> $tmp1
done

echo "# --
# --
# -- --------------------- -------------- ---------- ---- -
# -- --------------------- -------------- ---------- ---- -
# --
" >> $tmp1

for i in $(seq 1 $wc_l)
do
  uh="$(head -n $i "$tmp2" | tail -n1)"
  q="SHOW GRANTS FOR ${uh}"
  mysql_grants="$(echo "$q" | $cmd_mysql)"
  [ $? -ne 0 ] && { echo "failed to get grants for user ${uh}" >&2; echo "command: [$cmd_mysql_safe -e '$q'] failed" >&2; _exit_code=5; exit $_exit_code; }
  echo "$mysql_grants" | sed 's#$#;#g' >> $tmp1
  echo "" >> $tmp1
done


_date="$(date '+%Y-%m-%d %H:%M:%S %z')"
_server_ver="$(echo "SHOW GLOBAL VARIABLES LIKE 'version%'" | $cmd_mysql -s | sed 's#^[^\t]*\t##g' | tr '\n' ' ')"

echo "# --
# -- MySQL Grants Backup, Generated on ${_date}
# -- Created using: 'Dimsh MySQL credentials backup script', <idimsh@gmail.com>
# -- Server: ${_server_ver}
# --
# --
# -- Excluded user(s):"
[ -n "$exclUsers_ret" ] && echo " ${exclUsers_ret}" | tr ',' '\n' | sed 's@^@# --  @g' || echo "# --   -NONE-"
echo "# --
# -- Excluded host(s):"
[ -n "$exclHosts_ret" ] && echo " ${exclHosts_ret}" | tr ',' '\n' | sed 's@^@# --  @g' || echo "# --   -NONE-"
echo "# --
# -- Excluded user@host:"
[ -n "$exclUsersAtHosts_ret" ] && echo " ${exclUsersAtHosts_ret}" | tr ',' '\n' | sed 's@^@# --  @g' || echo "# --   -NONE-"
echo "# ----------------------------------------
# ----------------------------------------
# --
# --"
cat $tmp1
_exit_code=0; exit $_exit_code

