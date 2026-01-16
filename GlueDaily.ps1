# =====================================================
# CONFIGURACIÓN Y VARIABLES
# =====================================================
$BUCKET_NAME = "ulpgc-employees"
$DATABASE    = "employees_db"
$TABLE       = "realtime_ops_fleet"
$JOB_NAME    = "employees_daily"

# ARN directo para evitar el error de AccessDenied en el GetRole
$ROLE_ARN = "arn:aws:iam::637423399710:role/LabRole" 

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   SETUP GLUE JOB - EMPLOYEES"          -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Helper function del script de Cars para crear JSONs compatibles
function New-TempJson {
    param($Content)
    $Path = [System.IO.Path]::GetTempFileName()
    $Content | ConvertTo-Json -Compress | Out-File -FilePath $Path -Encoding ASCII
    return $Path
}

# =====================================================
# 1. SUBIR SCRIPT A S3
# =====================================================
Write-Host "[1/4] Subiendo script a S3..." -ForegroundColor Yellow
aws s3 cp "employees_daily.py" "s3://$BUCKET_NAME/scripts/employees_daily.py" --quiet

# =====================================================
# 2. PREPARAR ARGUMENTOS (Sincronizado con tu Python)
# =====================================================
Write-Host "[2/4] Preparando argumentos..." -ForegroundColor Yellow

# Sincronizamos los nombres de las llaves con los args de tu script Python
$ArgsData = @{
    "--JOB_NAME"                         = $JOB_NAME
    "--database"                         = $DATABASE
    "--table_name"                       = $TABLE
    "--output_path"                      = "s3://$BUCKET_NAME/processed/daily_realtime_employees/"
    "--enable-continuous-cloudwatch-log" = "true"
    "--spark-event-logs-path"            = "s3://$BUCKET_NAME/logs/"
}

$ArgsFile = New-TempJson -Content $ArgsData

# =====================================================
# 3. CREAR GLUE JOB (Limpieza previa incluida)
# =====================================================
Write-Host "[3/4] Configurando Glue Job..." -ForegroundColor Yellow

# Eliminamos el job si existe para evitar errores de duplicado (como en el script de Cars)
aws glue delete-job --job-name $JOB_NAME 2>$null
Start-Sleep -Seconds 2

$CommandData = @{
    Name           = "glueetl"
    ScriptLocation = "s3://$BUCKET_NAME/scripts/employees_daily.py"
    PythonVersion  = "3"
}
$CmdFile = New-TempJson -Content $CommandData

try {
    aws glue create-job `
        --name $JOB_NAME `
        --role "$ROLE_ARN" `
        --glue-version "4.0" `
        --number-of-workers 2 `
        --worker-type "G.1X" `
        --command "file://$CmdFile" `
        --default-arguments "file://$ArgsFile"
        
    Write-Host "OK Job creado exitosamente" -ForegroundColor Green
}
catch {
    Write-Error "Fallo al crear el Job: $_"
    exit 1
}

# =====================================================
# 4. EJECUTAR PIPELINE
# =====================================================
Write-Host "[4/4] Ejecutando Job..." -ForegroundColor Yellow

try {
    $RunId = (aws glue start-job-run --job-name $JOB_NAME --query 'JobRunId' --output text).Trim()
    Write-Host "Job iniciado correctamente. RunId: $RunId" -ForegroundColor Cyan
}
catch {
    Write-Error "No se pudo iniciar el Job."
}

# Limpieza de archivos temporales
Remove-Item $ArgsFile, $CmdFile -ErrorAction SilentlyContinue
Write-Host "Proceso completado" -ForegroundColor Green