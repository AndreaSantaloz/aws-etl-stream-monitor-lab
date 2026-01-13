$DAILY_OUTPUT="s3://$BUCKET_NAME/processed/energy_consumption_daily/"
$BUCKET_NAME="ulpgc-employees"
$ROLE_ARN=$(aws iam get-role --role-name LabRole --query 'Role.Arn' --output text)
$DATABASE="energy_db"
$TABLE="energy_consumption_five_minutes"

#Almacenamos  el script mensual  que observa los datos cada día
aws s3 cp energy_aggregation_daily.py s3://$BUCKET_NAME/scripts/
# Crea la tarea
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


#Comienza la tarea
aws glue start-job-run --job-name energy-daily-aggregation
#Comienza la tarea
aws glue get-job-runs --job-name energy-daily-aggregation --max-items 1
