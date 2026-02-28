# Script completo para inicializar o ambiente
Write-Host "=== Setup Completo LocalStack ===" -ForegroundColor Cyan

$endpoint = "http://localhost:4566"

# Verificar se LocalStack esta rodando
Write-Host "`nVerificando LocalStack..." -ForegroundColor Yellow
try {
    $health = Invoke-WebRequest -Uri "$endpoint/_localstack/health" -UseBasicParsing -TimeoutSec 5
    Write-Host "LocalStack esta rodando!" -ForegroundColor Green
} catch {
    Write-Host "LocalStack nao esta rodando!" -ForegroundColor Red
    Write-Host "Inicie com: docker-compose up -d" -ForegroundColor Yellow
    exit 1
}

# Criar bucket S3
Write-Host "`nCriando bucket S3..." -ForegroundColor Yellow
aws s3 mb s3://documents-bucket --endpoint-url $endpoint 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Bucket criado!" -ForegroundColor Green
} else {
    Write-Host "Bucket ja existe ou erro ao criar" -ForegroundColor Yellow
}

# Criar tabela Alunos
Write-Host "`nCriando tabela Alunos..." -ForegroundColor Yellow
aws dynamodb create-table `
    --table-name Alunos `
    --attribute-definitions AttributeName=matricula,AttributeType=S `
    --key-schema AttributeName=matricula,KeyType=HASH `
    --billing-mode PAY_PER_REQUEST `
    --endpoint-url $endpoint 2>$null

if ($LASTEXITCODE -eq 0) {
    Write-Host "Tabela Alunos criada!" -ForegroundColor Green
} else {
    Write-Host "Tabela Alunos ja existe ou erro ao criar" -ForegroundColor Yellow
}

# Criar tabela Jobs
Write-Host "`nCriando tabela Jobs..." -ForegroundColor Yellow
aws dynamodb create-table `
    --table-name Jobs `
    --attribute-definitions AttributeName=jobId,AttributeType=S `
    --key-schema AttributeName=jobId,KeyType=HASH `
    --billing-mode PAY_PER_REQUEST `
    --endpoint-url $endpoint 2>$null

if ($LASTEXITCODE -eq 0) {
    Write-Host "Tabela Jobs criada!" -ForegroundColor Green
} else {
    Write-Host "Tabela Jobs ja existe ou erro ao criar" -ForegroundColor Yellow
}

# Criar fila SQS
Write-Host "`nCriando fila SQS..." -ForegroundColor Yellow
aws sqs create-queue --queue-name documents-queue --endpoint-url $endpoint 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Fila criada!" -ForegroundColor Green
} else {
    Write-Host "Fila ja existe ou erro ao criar" -ForegroundColor Yellow
}

# Adicionar alunos
Write-Host "`nAdicionando alunos de teste..." -ForegroundColor Yellow
$result = aws dynamodb batch-write-item --request-items file://data/alunos-batch.json --endpoint-url $endpoint 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "Alunos adicionados!" -ForegroundColor Green
} else {
    Write-Host "Erro ao adicionar alunos ou ja existem" -ForegroundColor Yellow
}

# Verificar se Lambda existe
Write-Host "`nVerificando funcao Lambda..." -ForegroundColor Yellow
$lambdaExists = $false
try {
    aws lambda get-function --function-name document-processor --endpoint-url $endpoint 2>$null
    $lambdaExists = $LASTEXITCODE -eq 0
} catch {
    $lambdaExists = $false
}

if (-not $lambdaExists) {
    Write-Host "Lambda nao encontrada. Execute:" -ForegroundColor Yellow
    Write-Host "  cd localstack" -ForegroundColor Gray
    Write-Host "  powershell -ExecutionPolicy Bypass -File deploy-lambda.ps1" -ForegroundColor Gray
} else {
    Write-Host "Lambda encontrada!" -ForegroundColor Green
    
    # Configurar trigger SQS
    Write-Host "`nConfigurando trigger SQS..." -ForegroundColor Yellow
    $queueArn = aws sqs get-queue-attributes `
        --queue-url http://localhost:4566/000000000000/documents-queue `
        --attribute-names QueueArn `
        --query 'Attributes.QueueArn' `
        --output text `
        --endpoint-url $endpoint 2>$null
    
    if ($queueArn) {
        aws lambda create-event-source-mapping `
            --function-name document-processor `
            --batch-size 1 `
            --event-source-arn $queueArn `
            --endpoint-url $endpoint 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Trigger SQS configurado!" -ForegroundColor Green
        } else {
            Write-Host "Trigger ja existe ou erro ao configurar" -ForegroundColor Yellow
        }
    }
}

Write-Host "`n=== Setup Concluido! ===" -ForegroundColor Green
Write-Host "`nRecursos disponiveis:" -ForegroundColor Cyan
Write-Host "  - Bucket S3: documents-bucket" -ForegroundColor White
Write-Host "  - Tabelas DynamoDB: Alunos, Jobs" -ForegroundColor White
Write-Host "  - Fila SQS: documents-queue" -ForegroundColor White
Write-Host "  - Alunos de teste: 1001, 1002, 1003" -ForegroundColor White

Write-Host "`nProximos passos:" -ForegroundColor Cyan
Write-Host "1. Iniciar API:" -ForegroundColor White
Write-Host "   cd api" -ForegroundColor Gray
Write-Host "   npm run dev" -ForegroundColor Gray
Write-Host "`n2. Testar com Thunder Client:" -ForegroundColor White
Write-Host "   POST http://localhost:3000/request-document" -ForegroundColor Gray
Write-Host '   Body: {"matricula": "1001"}' -ForegroundColor Gray
