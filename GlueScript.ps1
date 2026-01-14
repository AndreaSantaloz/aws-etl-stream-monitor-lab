# 0. Configuración de variables
$BUCKET_NAME = "ulpgc-employees"
$DB_NAME = "employees_db"
$CRAWLER_NAME = "employee-raw-crawler"

try {
    $ROLE_ARN = aws iam get-role --role-name LabRole --query 'Role.Arn' --output text
    if ($LASTEXITCODE -ne 0) { throw "No se pudo obtener el ARN del rol. Verifica que 'LabRole' existe." }
} catch {
    Write-Error "Error fatal al obtener configuración inicial: $_"
    return
}

# 1. Gestión de la Base de Datos
try {
    Write-Host "Verificando base de datos '$DB_NAME'..." -ForegroundColor Cyan
    aws glue get-database --name $DB_NAME 2>$null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "La base de datos no existe. Creándola..." -ForegroundColor Yellow
        aws glue create-database --database-input "{\`"Name\`":\`"$DB_NAME\`"}" 
        Write-Host "Base de datos creada con éxito." -ForegroundColor Green
    } else {
        Write-Host "La base de datos '$DB_NAME' ya existe. Saltando paso." -ForegroundColor Gray
    }
} catch {
    Write-Warning "Hubo un problema con la base de datos: $_"
}

# 2. Gestión del Crawler
try {
    Write-Host "Verificando crawler '$CRAWLER_NAME'..." -ForegroundColor Cyan
    aws glue get-crawler --name $CRAWLER_NAME 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "El crawler no existe. Creándolo..." -ForegroundColor Yellow        
         aws glue create-crawler `
            --name "employee-raw-crawler" `
            --role $ROLE_ARN `
            --database-name "$DB_NAME " `
            --targets "{\`"S3Targets\`": [{\`"Path\`": \`"s3://$BUCKET_NAME/raw/employee_consumption_five_minutes\`"}]}"

        Write-Host "Crawler creado con éxito." -ForegroundColor Green
    } else {
        Write-Host "El crawler '$CRAWLER_NAME' ya existe. Saltando paso." -ForegroundColor Gray
    }
} catch {
    Write-Warning "No se pudo gestionar el crawler: $_"
}

# 3. Iniciar el Crawler
try {
    Write-Host "Iniciando crawler..." -ForegroundColor Cyan
    aws glue start-crawler --name "employee-raw-crawler" 
    Write-Host "Crawler iniciado correctamente." -ForegroundColor Green
} catch {
    # El crawler puede fallar al iniciar si ya se está ejecutando
    Write-Warning "No se pudo iniciar el crawler (posiblemente ya esté en ejecución o procesando)."
}