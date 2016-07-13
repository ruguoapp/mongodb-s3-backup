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
EOF
}

MONGODB_HOST=
MONGODB_USER=
MONGODB_PASSWORD=
AWS_ACCESS_KEY=
AWS_SECRET_KEY=
S3_PATH=

while getopts "h:u:p:k:s:o:" OPTION
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
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo $DIR
# Store the current date in YYYY-mm-DD-HHMMSS
DATE=$(date "+%F-%H%M%S")
FILE_NAME="backup-$DATE"
ARCHIVE_NAME="$FILE_NAME.tar.gz"

# Dump the database
mongodump --host="$MONGODB_HOST" --authenticationDatabase=admin --username="$MONGODB_USER" --password="$MONGODB_PASSWORD" --archive="$DIR/$ARCHIVE_NAME" --gzip

# Send the file to the backup drive or S3

aws s3 cp $DIR/$ARCHIVE_NAME $S3_PATH/
rm $DIR/$ARCHIVE_NAME
