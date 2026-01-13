
$AWS_REGION="us-east-1"
$ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
$BUCKET_NAME="ulpgc-employees"
$ROLE_ARN=$(aws iam get-role --role-name LabRole --query 'Role.Arn' --output text)


# Creamos la base de datos y creamos el crawler
aws glue create-database --database-input "{\"Name\":\"energy_db\"}"
aws glue create-crawler \
    --name energy-raw-crawler \
    --role $ROLE_ARN \
    --database-name energy_db \
    --targets "{\"S3Targets\": [{\"Path\": \"s3://$BUCKET_NAME/raw/energy_consumption_five_minutes\"}]}"

aws glue start-crawler --name energy-raw-crawler


