#!/bin/bash

echo "updating pgbouncer userlist.txt"
# Combine the files and sort them
cat /etc/pgbouncer/users.txt /opt/bitnami/pgbouncer/conf/userlist.txt | sort > combined_sorted.txt

# Use awk to remove duplicates, keeping the last occurrence
awk '!seen[$1]++' combined_sorted.txt > /opt/bitnami/pgbouncer/conf/userlist.txt

# Clean up intermediate file
rm combined_sorted.txt

echo "updating pgbouncer.ini"

cp /bitnami/pgbouncer/conf/pgbouncer.ini /opt/bitnami/pgbouncer/conf/pgbouncer.ini

echo "reloading pgbouncer"

psql -p 6432 -U pgbouncer -c "RELOAD" pgbouncer
