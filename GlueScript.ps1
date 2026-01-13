
$AWS_REGION="us-east-1"
$ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
$BUCKET_NAME="ulpgc-employees"
$ROLE_ARN=$(aws iam get-role --role-name LabRole --query 'Role.Arn' --output text)
$LAMBDA_ARN=$(aws lambda get-function --function-name employee-firehose-lambda --query 'Configuration.FunctionArn' --output text)



aws glue create-database --database-input "{\"Name\":\"energy_db\"}"

aws glue create-crawler \
    --name energy-raw-crawler \
    --role $ROLE_ARN \
    --database-name energy_db \
    --targets "{\"S3Targets\": [{\"Path\": \"s3://$BUCKET_NAME/raw/energy_consumption_five_minutes\"}]}"

aws glue start-crawler --name energy-raw-crawler


--- GLUE ETL

aws s3 cp energy_aggregation_daily.py s3://$BUCKET_NAME/scripts/
aws s3 cp energy_aggregation_monthly.py s3://$BUCKET_NAME/scripts/

export DATABASE="energy_db"
export TABLE="energy_consumption_five_minutes"
export DAILY_OUTPUT="s3://$BUCKET_NAME/processed/energy_consumption_daily/"
export MONTHLY_OUTPUT="s3://$BUCKET_NAME/processed/energy_consumption_monthly/"
export ROLE_ARN=$(aws iam get-role --role-name LabRole --query 'Role.Arn' --output text)

aws glue create-job \
    --name energy-monthly-aggregation \
    --role $ROLE_ARN \
    --command '{
        "Name": "glueetl",
        "ScriptLocation": "s3://'"$BUCKET_NAME"'/scripts/energy_aggregation_monthly.py",
        "PythonVersion": "3"
    }' \
    --default-arguments '{
        "--database": "'"$DATABASE"'",
        "--table": "'"$TABLE"'",
        "--output_path": "s3://'"$BUCKET_NAME"'/processed/energy_consumption_monthly/",
        "--enable-continuous-cloudwatch-log": "true",
        "--spark-event-logs-path": "s3://'"$BUCKET_NAME"'/logs/"
    }' \
    --glue-version "4.0" \
    --number-of-workers 2 \
    --worker-type "G.1X"

aws glue create-job \
    --name energy-daily-aggregation \
    --role $ROLE_ARN \
    --command '{
        "Name": "glueetl",
        "ScriptLocation": "s3://'"$BUCKET_NAME"'/scripts/energy_aggregation_daily.py",
        "PythonVersion": "3"
    }' \
    --default-arguments '{
        "--database": "'"$DATABASE"'",
        "--table": "'"$TABLE"'",
        "--output_path": "s3://'"$BUCKET_NAME"'/processed/energy_consumption_daily/",
        "--enable-continuous-cloudwatch-log": "true",
        "--spark-event-logs-path": "s3://'"$BUCKET_NAME"'/logs/"
    }' \
    --glue-version "4.0" \
    --number-of-workers 2 \
    --worker-type "G.1X"


aws glue start-job-run --job-name energy-daily-aggregation

aws glue start-job-run --job-name energy-monthly-aggregation

# Ver estado
aws glue get-job-runs --job-name energy-daily-aggregation --max-items 1
aws glue get-job-runs --job-name energy-monthly-aggregation --max-items 1