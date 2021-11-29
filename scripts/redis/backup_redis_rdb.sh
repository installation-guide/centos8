#!/bin/bash
#
## redis backup script
## usage
## redis-backup.sh <wait>

## Redis is very data backup friendly since you can copy RDB files while the database is running: the RDB is never modified once       produced, and while it gets produced it uses a temporary name and is renamed into its final destination atomically using rename(2)     only when the new snapshot is complete.

# Scripts & Files
 
## using command: ACL GETUSER admin
[ -f /etc/sysconfig/redis ] && export $(grep -w '^REDISCLI_AUTH' /etc/sysconfig/redis)

REDIS_PORT=1379
RDB_FILE=${RDB_FILE:-"/app/redis/v6.2.5/data/redis_${REDIS_PORT}.dump"}
WAIT=${1:-60} ## default wait for 60 seconds
RETENTION_DAYS=${RETENTION_DAYS:-7}

REDIS_CLI=${REDIS_CLI:-"/app/redis/v6.2.5/bin/redis-cli"}

# Directories
TEMP_PATH=${TEMP_PATH:-"/app/redis/v6.2.5/tmp"}
TEMP_FILE_NAME="redis_${REDIS_PORT}_dump_$(date +%Y%m%d).tar.gz"
TEMP_DB_FILE="$TEMP_PATH/$TEMP_FILE_NAME"

BACKUP_DIR=${BACKUP_DIR:-"/app/redis/v6.2.5/archived"}
BACKUP_FILE="$BACKUP_DIR/$TEMP_FILE_NAME"

test -d $BACKUP_DIR || {
 echo "[$REDIS_PORT] Create backup directory $BACKUP_DIR" && mkdir -p $BACKUP_DIR
}

test -d $TEMP_PATH || {
 echo "[$REDIS_PORT] Create temp directory $TEMP_PATH" && mkdir -p $TEMP_PATH
}

CLI="$REDIS_CLI -p $REDIS_PORT"
if [ ! -f $BACKUP_FILE ]; then
  # perform a bgsave before copy
  echo bgsave | $CLI
  echo "[$REDIS_PORT] waiting for $wait seconds..."
  sleep $WAIT

  # archived data
  try=5
  while [ $try -gt 0 ] ; do
     ## redis-cli output dos format line feed '\r\n', remove '\r'
     bg=$(echo 'info Persistence' | $CLI | awk -F: '/rdb_bgsave_in_progress/{sub(/\r/, "", $0); print $2}')
     ok=$(echo 'info Persistence' | $CLI | awk -F: '/rdb_last_bgsave_status/{sub(/\r/, "", $0); print $2}')
     if [[ "$bg" = "0" ]] && [[ "$ok" = "ok" ]] ; then
       # -p: keeps mode, ownership and timestamp. The command is same as --preserve=mode,ownership,timestamps
       # -u: copy only when the SOURCE file is newer than the destination file or when the destination file is missing
       tar cvf - $RDB_FILE | gzip -9 - > $TEMP_DB_FILE
       cp -pu $TEMP_DB_FILE $BACKUP_FILE
       if [ $? = 0 ] ; then
         echo "[$REDIS_PORT] redis rdb $TEMP_DB_FILE copied to $BACKUP_FILE"
         echo "Removing file $TEMP_DB_FILE..."
         rm -fv $TEMP_DB_FILE
         break
       else
         echo "[$REDIS_PORT] >> Failed to copy $TEMP_DB_FILE to $BACKUP_FILE!"
         echo "Removing file $TEMP_DB_FILE..."
         rm -fv $TEMP_DB_FILE
         break
       fi
     fi
   try=$((try - 1))
   echo "[$REDIS_PORT] redis maybe busy, waiting and retry in 10s..."
   sleep 10
  done
fi

#find $BACKUP_DIR -name "*.tar.gz" -type f -cmin +10 -print
# remove old files
find $BACKUP_DIR -name "*.tar.gz" -type f -mtime +$RETENTION_DAYS -delete;
echo "[$REDIS_PORT] remove files older than $RETENTION_DAYS"

exit 1