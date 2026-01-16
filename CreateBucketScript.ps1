
$BUCKET_NAME="ulpgc-employees"

#Poner nombre único sabiendo el dataset que escojamos
aws s3 mb s3://$BUCKET_NAME
aws s3api put-object --bucket $BUCKET_NAME --key raw/
aws s3api put-object --bucket $BUCKET_NAME --key raw/realtime_ops_fleet/
aws s3api put-object --bucket $BUCKET_NAME --key processed/
aws s3api put-object --bucket $BUCKET_NAME --key processed/montly_realtime_employees/
aws s3api put-object --bucket $BUCKET_NAME --key processed/daily_realtime_employees/
aws s3api put-object --bucket $BUCKET_NAME --key config/
aws s3api put-object --bucket $BUCKET_NAME --key scripts/
aws s3api put-object --bucket $BUCKET_NAME --key queries/
aws s3api put-object --bucket $BUCKET_NAME --key queries/athena-queries/
aws s3api put-object --bucket $BUCKET_NAME --key scripts/
aws s3api put-object --bucket $BUCKET_NAME --key errors/