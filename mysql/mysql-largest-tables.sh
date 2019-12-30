#!/bin/bash
####
#### MySql largest table finder, per database or per engine
####
#### By Abdulrahman Dimashki <idimsh@gmail.com>
####
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

_db= #database specific
while getopts ":D:" opt; do
  case $opt in
    D)
      _db="$OPTARG"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

tmp=/tmp/"$(basename $0)".$$

if [ -z "$_db" ]; then
cat > $tmp << EOF
SELECT CONCAT(table_schema, '.', table_name)                                  table_name,
       CONCAT(ROUND(table_rows / 1000, 2), 'K')                               rows,
       CONCAT(ROUND(data_length / ( 1024 * 1024), 2), 'M')                    DATA,
       CONCAT(ROUND(index_length / ( 1024 * 1024 ), 2), 'M')                  idx,
       CONCAT(ROUND(( data_length + index_length ) / ( 1024 * 1024), 2), 'M') total_size,
       ROUND(index_length / data_length, 2)                                   idxfrac
FROM   information_schema.TABLES
ORDER  BY data_length + index_length DESC
LIMIT  10;

EOF
else
cat > $tmp << EOF
SELECT CONCAT(table_schema, '.', table_name)                                  table_name,
       CONCAT(ROUND(table_rows / 1000, 2), 'K')                               rows,
       CONCAT(ROUND(data_length / ( 1024 * 1024), 2), 'M')                    DATA,
       CONCAT(ROUND(index_length / ( 1024 * 1024 ), 2), 'M')                  idx,
       CONCAT(ROUND(( data_length + index_length ) / ( 1024 * 1024), 2), 'M') total_size,
       ROUND(index_length / data_length, 2)                                   idxfrac
FROM   information_schema.TABLES
WHERE table_schema='${_db}'
ORDER  BY data_length + index_length DESC
LIMIT  10;

EOF
fi

mysql --defaults-file=/etc/mysql/debian.cnf < $tmp | column -t
rm -f $tmp
