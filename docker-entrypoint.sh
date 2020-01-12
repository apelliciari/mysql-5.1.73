#!/bin/bash
set -e

if [ ! -d '/var/lib/mysql/mysql' -a "${1%_safe}" = 'mysqld' ]; then
	if [ -z "$MYSQL_ROOT_PASSWORD" -a -z "$MYSQL_ALLOW_EMPTY_PASSWORD" ]; then
		echo >&2 'error: database is uninitialized and MYSQL_ROOT_PASSWORD not set'
		echo >&2 '  Did you forget to add -e MYSQL_ROOT_PASSWORD=... ?'
		exit 1
	fi
        
	echo >&2 'mysql install db (root)...'
	
	mysql_install_db --datadir=/var/lib/mysql ## can't use --user=mysql because it's bugged with shared volumes on docker
	
	# These statements _must_ be on individual lines, and _must_ end with
	# semicolons (no line breaks or comments are permitted).
	# TODO proper SQL escaping on ALL the things D:
	echo >&2 'creating first time SQL script file'
	TEMP_FILE='/tmp/mysql-first-time.sql'
	cat > "$TEMP_FILE" <<-EOSQL
		DELETE FROM mysql.user ;
		CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
		GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION ;
		DROP DATABASE IF EXISTS test ;
	EOSQL
	
	if [ "$MYSQL_DATABASE" ]; then
		echo >&2 "adding > create database $MYSQL_DATABASE..."
		echo "CREATE DATABASE IF NOT EXISTS $MYSQL_DATABASE ;" >> "$TEMP_FILE"
	fi
	
	if [ "$MYSQL_USER" -a "$MYSQL_PASSWORD" ]; then
		
		echo >&2 "adding > create user $MYSQL_USER..."
		echo "CREATE USER '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD' ;" >> "$TEMP_FILE"
		
		if [ "$MYSQL_DATABASE" ]; then
				
			echo >&2 'adding > grant the user everything...'
			echo "GRANT ALL ON $MYSQL_DATABASE.* TO '$MYSQL_USER'@'%' ;" >> "$TEMP_FILE"
		fi
	fi
	
	echo >&2 'adding > flush privileges...'
	echo 'FLUSH PRIVILEGES ;' >> "$TEMP_FILE"


	echo >&2 "set with --init-file $TEMP_FILE"
	set -- "$@" --init-file="$TEMP_FILE"
fi


echo >&2 'chown mysql /var/lib/mysql'
chown -R mysql:mysql /var/lib/mysql


echo >&2 "exec $@"
exec "$@"
