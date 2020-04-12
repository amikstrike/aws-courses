#!/bin/bash

BUCKET_NAME="oivchenko-s3-w3"
SQL_FILE_NAME="rds-script.sql"
DYNAMO_FILE_NAME="dynamodb-script.sh"

aws s3 mb "s3://$BUCKET_NAME"
aws s3 cp $SQL_FILE_NAME "s3://$BUCKET_NAME/$SQL_FILE_NAME"
aws s3 cp $DYNAMO_FILE_NAME "s3://$BUCKET_NAME/$DYNAMO_FILE_NAME"
