#!/bin/bash
####
####
#### Script for database backup using mysqldump
####
#### By Abdulrahman Dimashki <idimsh@gmail.com>
####
#### Update-6: 2018-09-22
#### - Added --events --triggers --routines options to mysqldump command
#### Update-5: 2017-12-14
#### - Added parameter to compress the sql files using zip and it is the default unless requested.
#### Update-5: 2017-12-12
#### - now the default is to use extended insert, previously --skip-extended-insert was added to dump command
####   unless command line parameter --extended, -ex is added, now ---no-extended, -nex will result in skip extended
#### Update-4: 2013-11-08
####  - added performance_schema to execluded tabled
#### Update-3: 2012-11-22
####  - added the options to perform a backup with extended-insert or without
####    as opposed to mysqldump --skip-extended-insert command line option.
#### Update-2: 2012-11-17
####  - enhanced the help text.
#### Update-1: 2012-08-16
####  - added exclude tables and table data option.
####  - added timestamp option.
####  - set default file to be /etc/mysql/debian.cnf if no option is provided
####    for it and no '-u' option is passed.
#### Created: 2011-06-08
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
_m_db= #mysql database
_m_extended="--extended-insert" #mysqldump extended insert switch

_et= #excluded tables
_ed= #excluded tables data
_ts= #append timestamp
_comp=1 # compress the sql files

df=/etc/mysql/debian.cnf

_out_d="${SCRIPT_DIR}/dump"

exclude_egrep='mysql|information_schema|performance_schema'

ts=$(date +'%Y-%m-%dT%H-%M-%S')

##############################################################
##############################################################
function usage() {
  echo \
"
MySQL Backup Script, using mysqldump, by Dimsh <idimsh@gmail.com>

This script will dump all databases in the connected to MySQL engine except
'mysql' and 'information_schema' databases, and place the dumped databases
each in a single file named: {DB-name}.sql inside
directory: [${SCRIPT_DIR}/dump] by default.

The following 'mysqldump' command line options are always used while performing
the backup, and these can't be changed or overridden.

--default-character-set=utf8 \\
--opt \\
--compact \\
--add-drop-table \\
--add-locks \\
--disable-keys \\
--set-charset

Usage: $0 [< --defaults-file=<file> | -df=<file> >] [-t] [-nc] [-D <db-name>] [-o <out-dir>] [< --extended | -ex >] [-ed <tables>] [-et <tables>] [-u <username>] [-p<password>] [-S <socket>] [-h <host>] [-P <port>]

  options:

    --defaults-file=<file>,
    -df=<file>             : ini file name which contains username, pass, and
                             other options used by MySQL client to connect to a
                             server, defaults to '$df'
                             if no username is provided via '-u' parameter.
    -t : append timestamp in the form '$ts'
         to resulting database dump file name, so instead if the file name
         being: '{DB-name}.sql' it
         becomes: '{DB-name}-$ts.sql'.
    -D : Database name, if provided, only this DB will be dumpped, else all
         databases.
    -o : output directory, default to: [${SCRIPT_DIR}/dump], each dumped
         database will has its own file in this directory.
    --no-extended,
    -nex : execute the dump command with '--skip-extended-insert' argument, else and
          by default the 'mysqldump' command is always added the
          '--extended-insert' command line option (which is mysqldump default).
    -ed : comma seperated list of table names or wildcard names for tables in
          any of the databases seleted to be backed up which the script will
          exclude their data keeping table definition.
          ex.: 'cache_*,watchdog' will exclude the data for tables whos name is
          'watchdog' or the table name starts with 'cache_' in any database
          selected for backup (so if no -D option is passed then in all
          databases, else just in the database selected).
    -et : comma seperated list of table names or wildcard names for tables which
          will be excluded COMPLETELY from backup in any of the databases
          seleted to be backed up.
    -nc : No Compression: do not compress the result .sql files into .sql.zip files.
          The default is to do compression.

  All other options are the same for those related to 'mysqldump' command.
"
  exit 0
}

function startWithDash() {
  printf -- "$1" | egrep -q -- '^-' && return 0 || return 1
}

function _check_zip() { zip --help -h 1>/dev/null 2>&1; return $?; }

_check_zip
[ $? -ne 0 ] && _comp=

##############################################################
##############################################################
printf -- "$*" | egrep -q -- '(^| )(-h|--help)( |$)' && usage

while [ -n "$*" ]; do
  case "x$1" in
    x--defaults-file* | x-df*)
      _m_def_file="$(printf -- $1|sed 's#^(--defaults-file=\?\|-df)\?##')"
      [ -z "$_m_def_file" ] && { shift; _m_def_file="$1"; }
      [ -z "$_m_def_file" ] || startWithDash "$_m_def_file" && { echo "command line option '--defaults-file' expects a file name paramter" >&2; exit 1; }
      ;;

    x-t)
      _ts=1
      ;;

    x-nc)
      _comp=
      ;;

    x-D*)
      _m_db="$(printf -- $1|sed 's#^-D##')"
      [ -z "$_m_db" ] && { shift; _m_db="$1"; }
      [ -z "$_m_db" ] || startWithDash "$_m_db" && { echo "command line option '-D' expects a database name paramter" >&2; exit 1; }
      ;;

    x-o*)
      _out_d="$(printf -- $1|sed 's#^-o##')"
      [ -z "$_out_d" ] && { shift; _out_d="$1"; }
      [ -z "$_out_d" ] || startWithDash "$_out_d" && { echo "command line option '-o' expects a directory name paramter" >&2; exit 1; }
      ;;

    x--no-extended|x-nex)
      _m_extended="--skip-extended-insert"
      ;;

    x-et*)
      _et="$(printf -- $1|sed 's#^-et##')"
      [ -z "$_et" ] && { shift; _et="$1"; }
      [ -z "$_et" ] || startWithDash "$_et" && { echo "command line option '-et' expects comma seperated list of table names or wildcard names" >&2; exit 1; }
      ;;

    x-ed*)
      _ed="$(printf -- $1|sed 's#^-ed##')"
      [ -z "$_ed" ] && { shift; _ed="$1"; }
      [ -z "$_ed" ] || startWithDash "$_ed" && { echo "command line option '-ed' expects comma seperated list of table names or wildcard names" >&2; exit 1; }
      ;;

    x-u*)
      _m_user="$(printf -- $1|sed 's#^-u##')"
      [ -z "$_m_user" ] && { shift; _m_user="$1"; }
      [ -z "$_m_user" ] || startWithDash "$_m_user" && { echo "command line option '-u' expects a user name paramter" >&2; exit 1; }
      ;;

    x-p*)
      _m_pass="$(printf -- $1|sed 's#^-p##')"
      [ -z "$_m_pass" ] && { shift; _m_pass="$1"; }
      [ -z "$_m_pass" ] || startWithDash "$_m_pass" && { echo "command line option '-p' expects a password paramter" >&2; exit 1; }
      ;;

    x-S*)
      _m_socket="$(printf -- $1|sed 's#^-S##')"
      [ -z "$_m_socket" ] && { shift; _m_socket="$1"; }
      [ -z "$_m_socket" ] || startWithDash "$_m_socket" && { echo "command line option '-S' expects a socket file name paramter" >&2; exit 1; }
      ;;

    x-P*)
      _m_port="$(printf -- $1|sed 's#^-P##')"
      [ -z "$_m_port" ] && { shift; _m_port="$1"; }
      [ -z "$_m_port" ] || startWithDash "$_m_port" && { echo "command line option '-P' expects port number paramter" >&2; exit 1; }
      ;;

    x-h*)
      _m_host="$(printf -- $1|sed 's#^-h##')"
      [ -z "$_m_host" ] && { shift; _m_host="$1"; }
      [ -z "$_m_host" ] || startWithDash "$_m_host" && { echo "command line option '-h' expects a hostname paramter" >&2; exit 1; }
      ;;

    *)
      echo "invalid command line option '$1'" >&2
      exit 2
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

if [ -n "$_et" ]; then
  declare -a skip_tables
  c=0
  for i in $(printf -- "$_et" | tr ',' ' '); do
    skip_tables[$c]="$i"
    c=$(($c+1))
  done
  skip_tables_idx=$((${#skip_tables[*]} - 1))
fi

if [ -n "$_ed" ]; then
  declare -a skip_data
  c=0
  for i in $(printf -- "$_ed" | tr ',' ' '); do
    skip_data[$c]="$i"
    c=$(($c+1))
  done
  skip_data_idx=$((${#skip_data[*]} - 1))
fi

if [ -z "$_m_db" ]; then
  cmd_mysql_dbs="mysql ${cmd_opts} -e 'SHOW DATABASES' -BN | egrep -v '${exclude_egrep}' 2>/dev/null"
  mysql_dbs=`bash -c "$cmd_mysql_dbs"`
  [ $? -ne 0 ] && { echo "failed to get database list" >&2; echo "command: [$cmd_mysql_dbs] failed" >&2; exit 3; }
else
  mysql_dbs="$_m_db"
fi

_out_d="$(echo "$_out_d" | sed 's#/\+$##g')"
if [ ! -d "$_out_d" ]; then
  mkdir -p "$_out_d"
  [ $? -ne 0 ] && { echo -e "\nfailed to create output directory: [$_out_d]\n" >&2; exit 3; }
fi

exit_c=0
cnt_dbs=$(echo "$mysql_dbs"|wc -w)
[ -z "$_m_db" ] && echo "found $cnt_dbs databases"
if [ $cnt_dbs -gt 0 ]; then
  c=1
  for db in $mysql_dbs;
  do
    echo -n "${c}/${cnt_dbs}  ... DB: $db"
    c=$(($c+1))
    [ -z "$_ts" ] && out_file="${_out_d}/${db}-db.sql" || out_file="${_out_d}/${db}-$ts.sql"

    if [ -z "$_et" ] && [ -z "$_ed" ]; then
      #cmd_dump="mysqldump ${cmd_opts} --opt $db > '$out_file'"
      mysqldump ${cmd_opts} --opt --skip-comments $_m_extended --events --triggers --routines $db > "$out_file"
      [ $? -ne 0 ] && exit_c=5
    else
      cmd_mysql_tbls="mysql ${cmd_opts} -D $db -e 'SHOW TABLES' -BN 2>/dev/null"
      mysql_tbls=`bash -c "$cmd_mysql_tbls"`
      [ $? -ne 0 ] && { echo "failed to get tables list for database [$db]" >&2; echo "command: [$cmd_mysql_tbls] failed" >&2; exit 3; }

      echo -n '' > "$out_file"

      for tbl in $mysql_tbls;
      do
        if [ -n "$_et" ]; then
          for x in $(seq 0 $skip_tables_idx);
          do
            case "$tbl" in
              ${skip_tables[$x]}) continue 2
              ;;
            esac
          done
        fi
        no_data=
        if [ -n "$_ed" ]; then
          for x in $(seq 0 $skip_data_idx);
          do
            case "$tbl" in
              ${skip_data[$x]}) no_data=1
              # break the for loop
              break
              ;;
            esac
          done
        fi
        if [ -z "$no_data" ]; then
          mysqldump ${cmd_opts} --opt --compact $_m_extended --add-drop-table --add-locks --disable-keys --set-charset $db $tbl >> "$out_file"
          [ $? -ne 0 ] && { echo "failed to tables backup table: [$db].[$tbl]" >&2; exit 3; } || echo -e "\n\n" >> "$out_file"
        else
          mysqldump ${cmd_opts} --opt --compact $_m_extended --add-drop-table --add-locks --disable-keys --set-charset --no-data $db $tbl >> "$out_file"
          [ $? -ne 0 ] && { echo "failed to tables backup table: [$db].[$tbl]" >&2; exit 3; } || echo -e "\n\n" >> "$out_file"
        fi
      done

       ## dump the stored procedures, events, and triggers first
      mysqldump ${cmd_opts} --opt --no-create-db --no-create-info --no-data --events --triggers --routines $db > "$out_file"
      [ $? -ne 0 ] && exit_c=5
    fi

    if [ -n "$_comp" ]; then
      base="$(basename "$out_file")"
      dir="$(dirname "$out_file")"
      $(cd "$dir"; zip -6mq "$base".zip "$base")
      [ $? -ne 0 ] && { echo "failed to compress DB [$db]" >&2; }
      _file_size=$(ls -lh "${dir}/${base}.zip" | cut -d" " -f5)
    else
      _file_size=$(ls -lh "$out_file" | cut -d" " -f5)
    fi

    # this will append to the EOL for the previous echo which prints the DB file name being exported.
    echo " ($_file_size)"
  done
fi

exit $exit_c
