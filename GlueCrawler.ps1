$BUCKET_NAME = "ulpgc-employees"
$DB_NAME    = "employees_db"
$CRAWLER_NAME = "employee-raw-crawler"

# Verificar variables
if (-not $BUCKET_NAME -or -not $DB_NAME) {
    Write-Error "Las variables BUCKET_NAME y DB_NAME deben estar definidas"
    return
}

# Obtener ROLE_ARN
$ROLE_ARN = aws iam get-role --role-name LabRole --query 'Role.Arn' --output text
if ($LASTEXITCODE -ne 0) {
    Write-Error "No se pudo obtener el ARN del rol LabRole"
    return
}

# 1. Verificar si el crawler existe
Write-Host "Verificando crawler: $CRAWLER_NAME" -ForegroundColor Cyan
aws glue get-crawler --name $CRAWLER_NAME 2>$null

if ($LASTEXITCODE -ne 0) {
    Write-Host "Creando crawler..." -ForegroundColor Yellow
    # Crear crawler
    aws glue create-crawler `
        --name $CRAWLER_NAME `
        --role $ROLE_ARN `
        --database-name $DB_NAME `
        --targets "{\`"S3Targets\`": [{\`"Path\`": \`"s3://$BUCKET_NAME/raw/realtime_ops_fleet\`"}]}"    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Crawler creado exitosamente" -ForegroundColor Green
        Start-Sleep -Seconds 5
    } else {
        Write-Error "Error creando crawler"
        return
    }
} else {
    Write-Host "Crawler ya existe" -ForegroundColor Gray
}

# 2. Iniciar crawler
Write-Host "Iniciando crawler..." -ForegroundColor Cyan
aws glue start-crawler --name $CRAWLER_NAME

if ($LASTEXITCODE -eq 0) {
    Write-Host "Crawler iniciado exitosamente" -ForegroundColor Green
} else {
    Write-Warning "No se pudo iniciar el crawler. Verificando estado..."
    aws glue get-crawler --name $CRAWLER_NAME
}