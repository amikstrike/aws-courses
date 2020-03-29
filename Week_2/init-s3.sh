aws s3api create-bucket --bucket oivchenkos3b2 --region us-west-2 --create-bucket-configuration LocationConstraint=us-west-2
aws s3api put-public-access-block \
    --bucket oivchenkos3b2 \
    --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
aws s3api put-bucket-versioning --bucket oivchenkos3b2 --versioning-configuration Status=Enabled
echo 'test' > test.txt
aws s3 cp test.txt s3://oivchenkos3b2/test.txt

