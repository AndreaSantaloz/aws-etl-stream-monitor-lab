# 0. Configuración de variables
$DB_NAME = "employees_db"



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

