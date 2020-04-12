#!/bin/bash
REGION=us-west-2
TABLE=Message
aws dynamodb list-tables --region=${REGION}
aws dynamodb put-item --table-name ${TABLE} --item '{"Body": {"S": "var1"}, "Title": {"S": "title1"}}' --region=${REGION}
aws dynamodb put-item --table-name ${TABLE} --item '{"Body": {"S": "var2"}, "Title": {"S": "title2"}}' --region=${REGION}
aws dynamodb scan --table-name ${TABLE} --region=${REGION}
aws dynamodb query --table-name ${TABLE} --key-condition-expression "#Body = :v1" --expression-attribute-names '{"#Body": "Body"}' --expression-attribute-values '{":v1": {"S": "var1"}}' --region=${REGION}
