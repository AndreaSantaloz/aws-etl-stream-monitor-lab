$BUCKET_NAME="ulpgc-employees"
$ROLE_ARN=$(aws iam get-role --role-name LabRole --query 'Role.Arn' --output text)
$DATABASE="emloyee_db"
$TABLE="emloyee_consumption_five_minutes"

#Almacenamos  el script mensual  que observa los datos cada mes
aws s3 cp emloyee_aggregation_monthly.py s3://$BUCKET_NAME/scripts/
# Crea la tarea
aws glue create-job `
    --name emloyee-monthly-aggregation `
    --role $ROLE_ARN `
    --command '{
        "Name": "glueetl",
        "ScriptLocation": "s3://'"$BUCKET_NAME"'/scripts/emloyee_aggregation_monthly.py",
        "PythonVersion": "3"
    }' `
    --default-arguments '{
        "--database": "'"$DATABASE"'",
        "--table": "'"$TABLE"'",
        "--output_path": "s3://'"$BUCKET_NAME"'/processed/emloyee_consumption_monthly/",
        "--enable-continuous-cloudwatch-log": "true",
        "--spark-event-logs-path": "s3://'"$BUCKET_NAME"'/logs/"
    }' `
    --glue-version "4.0" `
    --number-of-workers 2 `
    --worker-type "G.1X"

#Comienza la tarea
aws glue start-job-run --job-name employee-monthly-aggregation
#Comienza la tarea
aws glue get-job-runs --job-name employee-monthly-aggregation --max-items 1