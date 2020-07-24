#!/bin/sh

set -e
set -x

if [ -z "$BACKUP_BUCKET" ]
then
  BACKUP_BUCKET=backups
  echo "BACKUP_BUCKET env var not specified, defaulting to the 'backups' bucket."
fi

if [ -z "$BACKUP_CMD" ]
then
   BACKUP_CMD="pg_dump -U postgres -f /dump postgres"
   echo "BACKUP_CMD env var not specified, defaulting to '${BACKUP_CMD}'."
fi

if [ -e $HOME/.aws/credentials ]
then
    echo "aws credentials found."
else
    echo "no ~/.aws/credentials file found. please mount one for me."
    exit 1
fi

if [ -z "$site" ]
then
  site=$(docker ps --format '{{.Names}}' | grep _backup_ | cut -d'_' -f1)
  echo "Using default site: $site"
fi

filename=$site.$(date +%Y%m%d-%H%M%S).sql
folder=$(date +%Y%m)

rm -rf /dump
rm -f /dump.lrz

docker exec -t ${site}_db_1 rm -fr /dump
docker exec -t ${site}_db_1 $BACKUP_CMD
docker cp ${site}_db_1:/dump /dump

tar cvf /dump.tar /dump
lrzip /dump.tar
rm -r /dump

aws s3 mv /dump.tar.lrz s3://$BACKUP_BUCKET/$site/$folder/$filename.tar.lrz

