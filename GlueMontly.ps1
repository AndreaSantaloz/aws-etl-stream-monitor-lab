$MONTHLY_OUTPUT="s3://$BUCKET_NAME/processed/energy_consumption_monthly/"
$BUCKET_NAME="ulpgc-employees"
$ROLE_ARN=$(aws iam get-role --role-name LabRole --query 'Role.Arn' --output text)
$DATABASE="energy_db"
$TABLE="energy_consumption_five_minutes"

#Almacenamos  el script mensual  que observa los datos cada mes
aws s3 cp energy_aggregation_monthly.py s3://$BUCKET_NAME/scripts/
# Crea la tarea
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

#Comienza la tarea
aws glue start-job-run --job-name energy-monthly-aggregation
#Comienza la tarea
aws glue get-job-runs --job-name energy-monthly-aggregation --max-items 1