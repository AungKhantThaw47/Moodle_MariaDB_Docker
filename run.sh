#!/bin/bash

# shellcheck disable=SC1091
now=`date +"%Y-%m-%d-%H-%M-%S"`
trap "mysqldump -u root bitnami_moodle > /bitnami/datasql/export_${now}.sql" SIGTERM
set -o errexit
set -o nounset
set -o pipefail
# set -o xtrace # Uncomment this line for debugging purposes

echo "run_sh"

# Load libraries
. /opt/bitnami/scripts/libos.sh
. /opt/bitnami/scripts/libmariadb.sh

# Load MariaDB environment variables
. /opt/bitnami/scripts/mariadb-env.sh

# mysqld_safe does not allow logging to stdout/stderr, so we stick with mysqld
EXEC="${DB_SBIN_DIR}/mysqld"

flags=("--defaults-file=${DB_CONF_DIR}/my.cnf" "--basedir=${DB_BASE_DIR}" "--datadir=${DB_DATA_DIR}" "--socket=${DB_SOCKET_FILE}")
[[ -z "${DB_PID_FILE:-}" ]] || flags+=("--pid-file=${DB_PID_FILE}")

# Add flags specified via the 'DB_EXTRA_FLAGS' environment variable
read -r -a db_extra_flags <<< "$(mysql_extra_flags)"
[[ "${#db_extra_flags[@]}" -gt 0 ]] && flags+=("${db_extra_flags[@]}")

# Add flags passed to this script
flags+=("$@")

# Fix for MDEV-16183 - mysqld_safe already does this, but we are using mysqld
LD_PRELOAD="$(find_jemalloc_lib)${LD_PRELOAD:+ "$LD_PRELOAD"}"
export LD_PRELOAD

info "** Starting MariaDB **"
if am_i_root; then
    # exec gosu "$DB_DAEMON_USER" "$EXEC" "${flags[@]}"
    val=`gosu "$DB_DAEMON_USER" "$EXEC" "${flags[@]}" &`
else
    # exec "$EXEC" "${flags[@]}"
    val=`"$EXEC" "${flags[@]}" &`
fi
echo "$val"
i=1
is_ready=true
FILE=/bitnami/mariadb_moodle/import_ready.txt
while true;
do
	if [ "$is_ready" = true ] ; then
    	if test -f "$FILE" ; then
			echo "$FILE exists"
			unset is_ready
			is_ready=false
			fileCheck=true
			ls /bitnami/datasql/export_* 2>/dev/null || fileCheck=false
			if [ "$fileCheck" = true ] ; then
				to_run=`ls -t /bitnami/datasql/export_* | head -1`
				echo "mysql -u root bitnami_moodle < $to_run"
			fi
		fi
	fi
	((i++))
done