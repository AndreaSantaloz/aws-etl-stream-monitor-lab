import boto3

client = boto3.client('athena')

response = client.start_query_execution(
    QueryString="SELECT * FROM employees_db.emloyee-monthly-aggregation WHERE timestamp = '2026-01-15T13:04:30Z'",
    QueryExecutionContext={
        'Database': 'employees_db'
    },
    ResultConfiguration={
        'OutputLocation': 's3://ulpgc-employees/queries/' 
    }
)