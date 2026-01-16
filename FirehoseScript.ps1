
$BUCKET_NAME   = "ulpgc-employees"
$LAMBDA_NAME   = "employee-firehose-lambda"
$STREAM_NAME   = "employees"
$FIREHOSE_NAME = "employee-delivery-stream"


$ROLE_ARN   = aws iam get-role --role-name LabRole --query "Role.Arn" --output text

# =====================================================
# CREAR ZIP DE LAMBDA
# =====================================================
if (Test-Path firehose.zip) {
    Remove-Item firehose.zip
}

Compress-Archive -Path firehose.py -DestinationPath firehose.zip

# =====================================================
# CREAR O ACTUALIZAR LAMBDA
# =====================================================
$lambdaExists = aws lambda get-function --function-name $LAMBDA_NAME 2>$null

if (-not $lambdaExists) {
    Write-Host "Creando Lambda..."
    aws lambda create-function `
        --function-name $LAMBDA_NAME `
        --runtime python3.12 `
        --role $ROLE_ARN `
        --handler firehose.lambda_handler `
        --zip-file fileb://firehose.zip `
        --timeout 60 `
        --memory-size 128
} else {
    Write-Host "Actualizando código de Lambda..."
    aws lambda update-function-code `
        --function-name $LAMBDA_NAME `
        --zip-file fileb://firehose.zip
}

# Esperar a que Lambda esté activa
aws lambda wait function-active --function-name $LAMBDA_NAME

# Obtener ARN de Lambda
$LAMBDA_ARN = aws lambda get-function `
    --function-name $LAMBDA_NAME `
    --query "Configuration.FunctionArn" `
    --output text

Write-Host "Lambda ARN: $LAMBDA_ARN"

# =====================================================
# CONFIGURACIÓN FIREHOSE (JSON CORRECTO)
# =====================================================
$FirehoseConfig = @"
{
  "BucketARN": "arn:aws:s3:::$BUCKET_NAME",
  "RoleARN": "$ROLE_ARN",
  "Prefix": "raw/realtime_ops_fleet/processing_date=!{partitionKeyFromLambda:processing_date}/",
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
            "ParameterValue": "$LAMBDA_ARN"
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
}
"@

# =====================================================
# CONFIGURACIÓN DE KINESIS STREAM SOURCE
# =====================================================
$KinesisSourceConfig = @"
{
  "KinesisStreamARN": "arn:aws:kinesis:us-east-1:637423399710:stream/$STREAM_NAME",
  "RoleARN": "$ROLE_ARN"
}
"@

# =====================================================
# CREAR FIREHOSE DELIVERY STREAM
# =====================================================
Write-Host "Creando Firehose delivery stream..."

# Guardar configuraciones en archivos temporales para evitar problemas de formato
$FirehoseConfig | Out-File -FilePath firehose_config.json -Encoding ascii
$KinesisSourceConfig | Out-File -FilePath kinesis_source_config.json -Encoding ascii

try {
    aws firehose create-delivery-stream `
        --delivery-stream-name $FIREHOSE_NAME `
        --delivery-stream-type KinesisStreamAsSource `
        --kinesis-stream-source-configuration file://kinesis_source_config.json `
        --extended-s3-destination-configuration file://firehose_config.json
    
    Write-Host "Firehose delivery stream creado exitosamente!"
} finally {
    # Limpiar archivos temporales
    if (Test-Path firehose_config.json) { Remove-Item firehose_config.json }
    if (Test-Path kinesis_source_config.json) { Remove-Item kinesis_source_config.json }
}