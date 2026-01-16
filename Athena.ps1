# Variables de configuración
$Database = "employees_db"
$Table = "realtime_ops_fleet"
$S3Output = "s3://ulpgc-employee/athena-consultas/"
$Region = "us-east-1"

# ============================================
# 5. ANÁLISIS DE ESTRÉS EXTREMO
# ============================================
Write-Host "ANÁLISIS DE ESTRÉS EXTREMO" -ForegroundColor Yellow
Write-Host "`nPorcentaje de empleados con estrés alto (nivel >= 8):" -ForegroundColor Cyan

try {
    # Hemos quitado $Database. de la cláusula FROM
    $q8 = (aws athena start-query-execution --query-string "SELECT 
        COUNT(CASE WHEN CAST(estres_index AS INT) >= 8 THEN 1 END) as high_stress,
        COUNT(*) as total,
        ROUND((COUNT(CASE WHEN CAST(estres_index AS INT) >= 8 THEN 1 END) * 100.0 / COUNT(*)), 2) as percentage
        FROM $Table;" --result-configuration OutputLocation=$S3Output --query-execution-context Database=$Database --region $Region --query QueryExecutionId --output text).Trim()
    
    Start-Sleep -Seconds 5
    
    # El resto del proceso de verificación se mantiene igual...
    $queryStatus = aws athena get-query-execution --query-execution-id $q8 --region $Region --output json | ConvertFrom-Json
    if ($queryStatus.QueryExecution.Status.State -eq "SUCCEEDED") {
        $extreme = aws athena get-query-results --query-execution-id $q8 --query 'ResultSet.Rows[1]' --region $Region --output json | ConvertFrom-Json
        
        if ($extreme -and $extreme.Data -and $extreme.Data.Count -ge 3) {
            $high = $extreme.Data[0].VarCharValue
            $total = $extreme.Data[1].VarCharValue
            $percent = $extreme.Data[2].VarCharValue
            Write-Host "  $high de $total empleados ($percent%)" -ForegroundColor White
        } else {
            Write-Host "  No se obtuvieron resultados válidos" -ForegroundColor Red
        }
    } else {
        Write-Host "  La consulta falló con estado: $($queryStatus.QueryExecution.Status.State)" -ForegroundColor Red
        Write-Host "  Error: $($queryStatus.QueryExecution.Status.StateChangeReason)" -ForegroundColor Red
    }
}
catch {
    Write-Host "  Error al ejecutar la consulta: $_" -ForegroundColor Red
}