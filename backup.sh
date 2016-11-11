#!/bin/bash
#
# Argument = -u user -p password -k key -s secret -b bucket
#
# To Do - Add logging of output.
# To Do - Abstract bucket region to options

set -e

export PATH="$PATH:/usr/local/bin"

usage()
{
cat << EOF
usage: $0 options

This script dumps the current mongo database, tars it, then sends it to an Amazon S3 bucket.

OPTIONS:
   -h      Mongodb host <replSetName>/<hostname1><:port>,<hostname2><:port>,<...>
   -u      Mongodb user
   -p      Mongodb password
   -k      AWS Access Key
   -s      AWS Secret Key
   -o      Amazon S3 path, e.g. s3://bucket_name/folder_name
   -d      Save to directory instead of archive
EOF
}

MONGODB_HOST=
MONGODB_USER=
MONGODB_PASSWORD=
AWS_ACCESS_KEY=
AWS_SECRET_KEY=
S3_PATH=
ARVHIE=true

while getopts "h:u:p:k:s:o:dt" OPTION
do
  case $OPTION in
    h)
      MONGODB_HOST=$OPTARG
      ;;
    u)
      MONGODB_USER=$OPTARG
      ;;
    p)
      MONGODB_PASSWORD=$OPTARG
      ;;
    k)
      AWS_ACCESS_KEY=$OPTARG
      ;;
    s)
      AWS_SECRET_KEY=$OPTARG
      ;;
    o)
      S3_PATH=$OPTARG
      ;;
    d)
      ARCHIVE=false
      ;;
    ?)
      usage
      exit
    ;;
  esac
done

if [[ -z $MONGODB_HOST ]] || [[ -z $S3_PATH ]]
then
  usage
  exit 1
fi

# Get the directory the script is being run from
DIR="/tmp"
echo $DIR
# Store the current date in YYYY-mm-DD-HHMMSS
DATE=$(date "+%F-%H%M%S")
FILE_NAME="backup-$DATE"
ARCHIVE_NAME="$FILE_NAME.tar.gz"

# Dump the database
DUMP_CMD="mongodump --host=$MONGODB_HOST" 

if [ $ARCHIVE = true ]; then
 DUMP_CMD="$DUMP_CMD --archive=$DIR/$ARCHIVE_NAME --gzip"
else
 DUMP_CMD="$DUMP_CMD --out=$DIR/$FILE_NAME"
fi

if [[ ! -z $MONGODB_USER ]] 
then
 DUMP_CMD="$DUMP_CMD --authenticationDatabase=admin --username=$MONGODB_USER --password=$MONGODB_PASSWORD"
fi

echo $DUMP_CMD
eval $DUMP_CMD

# Send the file to the backup drive or S3

if [ $ARCHIVE = true ]; then
  aws s3 cp $DIR/$ARCHIVE_NAME $S3_PATH/
  rm $DIR/$ARCHIVE_NAME
else
  find $DIR/$FILE_NAME -name _* -exec test ! -d '{}' \; -exec rename 's/_/u/' '{}' +
  aws s3 cp $DIR/$FILE_NAME $S3_PATH/$FILE_NAME/ --recursive
  rm -r $DIR/$FILE_NAME
fi
