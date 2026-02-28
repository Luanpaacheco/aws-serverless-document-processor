# Script PowerShell para build e empacotamento da Lambda
Write-Host "=== Build Lambda Function ===" -ForegroundColor Cyan

# Limpar diretório dist anterior
Write-Host "`nLimpando diretorio dist..." -ForegroundColor Yellow
if (Test-Path "dist") {
    Remove-Item -Recurse -Force dist
}

# Compilar TypeScript
Write-Host "`nCompilando TypeScript..." -ForegroundColor Yellow
npx tsc
if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro na compilacao TypeScript!" -ForegroundColor Red
    exit 1
}

# Remover lambda.zip anterior
if (Test-Path "lambda.zip") {
    Remove-Item -Force lambda.zip
}

# Instalar dependências de produção se necessário
Write-Host "`nVerificando dependencias..." -ForegroundColor Yellow
if (-not (Test-Path "node_modules")) {
    Write-Host "Instalando dependencias..." -ForegroundColor Yellow
    npm install
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Erro ao instalar dependencias!" -ForegroundColor Red
        exit 1
    }
}

# Criar pacote ZIP
Write-Host "`nCriando pacote lambda.zip..." -ForegroundColor Yellow

# Criar estrutura temporária
$tempDir = "temp_lambda"
if (Test-Path $tempDir) {
    Remove-Item -Recurse -Force $tempDir
}
New-Item -ItemType Directory -Path $tempDir | Out-Null

# Copiar arquivos necessários
Write-Host "Copiando arquivos..." -ForegroundColor Yellow
# Copiar conteúdo de dist/ direto na raiz (não a pasta dist/)
Copy-Item -Path "dist/*" -Destination $tempDir/ -Recurse
Copy-Item package.json $tempDir/

# Copiar node_modules completo
Write-Host "Copiando node_modules..." -ForegroundColor Yellow
Copy-Item -Recurse node_modules $tempDir/

# Criar ZIP
if (Get-Command bestzip -ErrorAction SilentlyContinue) {
    Write-Host "Usando bestzip..." -ForegroundColor Yellow
    # Entrar na pasta temp_lambda e criar o ZIP a partir de dentro dela
    Push-Location $tempDir
    bestzip ../lambda.zip *
    Pop-Location
} else {
    Write-Host "Usando Compress-Archive..." -ForegroundColor Yellow
    Compress-Archive -Path "$tempDir/*" -DestinationPath "lambda.zip" -Force
}

# Limpar
Remove-Item -Recurse -Force $tempDir

Write-Host "`nPacote criado com sucesso: lambda.zip" -ForegroundColor Green
$zipSize = (Get-Item lambda.zip).Length / 1KB
Write-Host "Tamanho: $zipSize KB" -ForegroundColor Green
