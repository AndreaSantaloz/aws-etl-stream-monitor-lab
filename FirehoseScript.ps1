
$AWS_REGION="us-east-1"
$ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
$BUCKET_NAME="ulpgc-employees"
$ROLE_ARN=$(aws iam get-role --role-name LabRole --query 'Role.Arn' --output text)
$LAMBDA_ARN=$(aws lambda get-function --function-name employee-firehose-lambda --query 'Configuration.FunctionArn' --output text)


zip firehose.zip firehose.py

aws lambda create-function `
    --function-name "employee-firehose-lambda" `
    --runtime "python3.12" `
    --role $ROLE_ARN `
    --handler "firehose.lambda_handler" `
    --zip-file "fileb://firehose.zip" `
    --timeout 60 `
    --memory-size 128


aws lambda update-function-code `
    --function-name employee-firehose-lambda `
    --zip-file fileb://firehose.zip


aws firehose create-delivery-stream `
    --delivery-stream-name employee-delivery-stream `
    --delivery-stream-type KinesisStreamAsSource `
    --kinesis-stream-source-configuration "KinesisStreamARN=arn:aws:kinesis $AWS_REGION : $ACCOUNT_ID"":stream/employee-stream,RoleARN=$ROLE_ARN" `
    --extended-s3-destination-configuration '{
        "BucketARN": "arn:aws:s3:::'"$BUCKET_NAME"'",
        "RoleARN": "'"$ROLE_ARN"'",
        "Prefix": "raw/employee_consumption_five_minutes/processing_date=!{partitionKeyFromLambda:processing_date}/",
        "ErrorOutputPrefix": "errors/!{firehose:error-output-type}/",
        "BufferingHints": {
            "SizeInMBs": 64,
            "IntervalInSeconds": 60
        },
        "DynamicPartitioningConfiguration": {
            "Enabled": true,
            "RetryOptions": {
                "DurationInSeconds": 300
            }
        },
        "ProcessingConfiguration": {
            "Enabled": true,
            "Processors": [
                {
                    "Type": "Lambda",
                    "Parameters": [
                        {
                            "ParameterName": "LambdaArn",
                            "ParameterValue": "'"$LAMBDA_ARN"'"
                        },
                        {
                            "ParameterName": "BufferSizeInMBs",
                            "ParameterValue": "1"
                        },
                        {
                            "ParameterName": "BufferIntervalInSeconds",
                            "ParameterValue": "60"
                        }
                    ]
                }
            ]
        }
    }'
