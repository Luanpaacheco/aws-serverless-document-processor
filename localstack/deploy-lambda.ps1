# Script PowerShell para deploy da Lambda no LocalStack
param(
    [string]$EndpointUrl = "http://localhost:4566"
)

Write-Host "=== Deploy Lambda para LocalStack ===" -ForegroundColor Cyan

# Verificar se o arquivo lambda.zip existe
if (-not (Test-Path "../lambda/lambda.zip")) {
    Write-Host "Arquivo lambda.zip nao encontrado!" -ForegroundColor Red
    Write-Host "Execute o script de build primeiro:" -ForegroundColor Yellow
    Write-Host "  cd lambda" -ForegroundColor Yellow
    Write-Host "  npm run package" -ForegroundColor Yellow
    exit 1
}

Write-Host "`nArquivo lambda.zip encontrado" -ForegroundColor Green

# Verificar se LocalStack está rodando
Write-Host "`nVerificando LocalStack..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "$EndpointUrl/_localstack/health" -TimeoutSec 5
    Write-Host "LocalStack esta rodando" -ForegroundColor Green
} catch {
    Write-Host "LocalStack nao esta rodando!" -ForegroundColor Red
    Write-Host "Inicie com: docker-compose up -d" -ForegroundColor Yellow
    exit 1
}

# Verificar se a função Lambda já existe
Write-Host "`nVerificando funcao Lambda existente..." -ForegroundColor Yellow
$functionExists = $false
try {
    aws lambda get-function --function-name document-processor --endpoint-url $EndpointUrl 2>$null
    $functionExists = $LASTEXITCODE -eq 0
} catch {
    $functionExists = $false
}

if ($functionExists) {
    Write-Host "Funcao Lambda ja existe. Atualizando codigo..." -ForegroundColor Yellow
    
    aws lambda update-function-code `
        --function-name document-processor `
        --zip-file fileb://../lambda/lambda.zip `
        --endpoint-url $EndpointUrl
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Codigo da Lambda atualizado com sucesso!" -ForegroundColor Green
    } else {
        Write-Host "Erro ao atualizar Lambda" -ForegroundColor Red
        exit 1
    }
    
} else {
    Write-Host "Criando nova funcao Lambda..." -ForegroundColor Yellow
    
    # Criar função Lambda
    aws lambda create-function `
        --function-name document-processor `
        --runtime nodejs18.x `
        --role arn:aws:iam::000000000000:role/lambda-role `
        --handler index.handler `
        --zip-file fileb://../lambda/lambda.zip `
        --environment "Variables={AWS_ENDPOINT=http://host.docker.internal:4566,BUCKET_NAME=documents-bucket}" `
        --timeout 60 `
        --memory-size 512 `
        --endpoint-url $EndpointUrl
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Erro ao criar Lambda" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Funcao Lambda criada!" -ForegroundColor Green
    
    # Configurar trigger SQS
    Write-Host "`nConfigurando trigger SQS..." -ForegroundColor Yellow
    
    $queueUrl = "http://localhost:4566/000000000000/documents-queue"
    $queueArn = aws sqs get-queue-attributes `
        --queue-url $queueUrl `
        --attribute-names QueueArn `
        --query 'Attributes.QueueArn' `
        --output text `
        --endpoint-url $EndpointUrl
    
    if ($queueArn) {
        aws lambda create-event-source-mapping `
            --function-name document-processor `
            --batch-size 1 `
            --event-source-arn $queueArn `
            --endpoint-url $EndpointUrl
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Trigger SQS configurado!" -ForegroundColor Green
        } else {
            Write-Host "Aviso: Nao foi possivel configurar o trigger (pode ja existir)" -ForegroundColor Yellow
        }
    }
}

Write-Host "`n=== Deploy concluido com sucesso! ===" -ForegroundColor Green
Write-Host "`nProximos passos:" -ForegroundColor Cyan
Write-Host "1. Testar a Lambda enviando mensagem para a fila:" -ForegroundColor White
Write-Host '   aws sqs send-message --queue-url http://localhost:4566/000000000000/documents-queue --message-body ''{"jobId":"test-001","matricula":"1001"}'' --endpoint-url http://localhost:4566' -ForegroundColor Gray
Write-Host "`n2. Verificar logs da Lambda:" -ForegroundColor White
Write-Host "   docker logs -f pucrs-docs-simulate-localstack-1" -ForegroundColor Gray
Write-Host "`n3. Listar objetos no S3:" -ForegroundColor White
Write-Host "   aws s3 ls s3://documents-bucket --recursive --endpoint-url http://localhost:4566" -ForegroundColor Gray
