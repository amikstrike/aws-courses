#!/usr/bin/env bash

BUCKET_NAME="w6-oivchenko-s3"
REGION=$(aws configure get region)


FOR_PUBLIC="calc-0.0.1-SNAPSHOT.jar"
FOR_PRIVATE="persist3-0.0.1-SNAPSHOT.jar"

aws s3 mb s3://${BUCKET_NAME}
aws s3 cp ../${FOR_PUBLIC} s3://${BUCKET_NAME}/${FOR_PUBLIC}
aws s3 cp ../${FOR_PRIVATE} s3://${BUCKET_NAME}/${FOR_PRIVATE}

aws s3api create-bucket --bucket ${BUCKET_NAME} --region ${REGION}

aws s3 cp ./rds-script.sql s3://${BUCKET_NAME}/
aws s3 cp ./dynamodb-script.sh s3://${BUCKET_NAME}/

aws s3api wait object-exists --bucket ${BUCKET_NAME} --key dynamodb-script.sh