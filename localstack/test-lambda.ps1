# Script PowerShell para testar a Lambda localmente
param(
    [string]$Matricula = "1001",
    [string]$JobId = $null,
    [string]$EndpointUrl = "http://localhost:4566"
)

Write-Host "=== Teste da Lambda LocalStack ===" -ForegroundColor Cyan

# Gerar JobId se nao fornecido
if (-not $JobId) {
    $JobId = "job-" + (Get-Date -Format "yyyyMMdd-HHmmss")
}

Write-Host "`nEnviando mensagem para fila SQS..." -ForegroundColor Yellow
Write-Host "JobId: $JobId" -ForegroundColor White
Write-Host "Matricula: $Matricula" -ForegroundColor White

$queueUrl = "http://localhost:4566/000000000000/documents-queue"
$messageBody = @{
    jobId = $JobId
    matricula = $Matricula
} | ConvertTo-Json -Compress

# Enviar mensagem para SQS
aws sqs send-message `
    --queue-url $queueUrl `
    --message-body $messageBody `
    --endpoint-url $EndpointUrl

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nMensagem enviada com sucesso!" -ForegroundColor Green
    
    Write-Host "`nAguardando processamento (5 segundos)..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    
    # Verificar status no DynamoDB
    Write-Host "`nVerificando status do job no DynamoDB..." -ForegroundColor Yellow
    $jobData = aws dynamodb get-item `
        --table-name Jobs `
        --key "{`"jobId`": {`"S`": `"$JobId`"}}" `
        --endpoint-url $EndpointUrl `
        --output json | ConvertFrom-Json
    
    if ($jobData.Item) {
        $status = $jobData.Item.status.S
        Write-Host "Status do Job: $status" -ForegroundColor $(if ($status -eq "COMPLETED") { "Green" } elseif ($status -eq "FAILED") { "Red" } else { "Yellow" })
        
        if ($jobData.Item.pdfKey) {
            $pdfKey = $jobData.Item.pdfKey.S
            Write-Host "PDF Key: $pdfKey" -ForegroundColor White
            
            Write-Host "`nBaixando PDF..." -ForegroundColor Yellow
            aws s3 cp "s3://documents-bucket/$pdfKey" "./$JobId.pdf" --endpoint-url $EndpointUrl
            
            if (Test-Path "./$JobId.pdf") {
                Write-Host "PDF baixado: $JobId.pdf" -ForegroundColor Green
                Write-Host "Tamanho: $((Get-Item ./$JobId.pdf).Length / 1KB) KB" -ForegroundColor White
            }
        }
        
        if ($jobData.Item.errorMessage) {
            Write-Host "Erro: $($jobData.Item.errorMessage.S)" -ForegroundColor Red
        }
    } else {
        Write-Host "Job nao encontrado no DynamoDB" -ForegroundColor Yellow
        Write-Host "Verifique os logs do LocalStack:" -ForegroundColor White
        Write-Host "  docker logs pucrs-docs-simulate-localstack-1 --tail 50" -ForegroundColor Gray
    }
    
} else {
    Write-Host "`nErro ao enviar mensagem" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Comandos uteis ===" -ForegroundColor Cyan
Write-Host "Ver logs LocalStack:" -ForegroundColor White
Write-Host "  docker logs -f pucrs-docs-simulate-localstack-1" -ForegroundColor Gray
Write-Host "`nListar PDFs no S3:" -ForegroundColor White
Write-Host "  aws s3 ls s3://documents-bucket/documents/ --endpoint-url $EndpointUrl" -ForegroundColor Gray
Write-Host "`nVerificar jobs no DynamoDB:" -ForegroundColor White
Write-Host "  aws dynamodb scan --table-name Jobs --endpoint-url $EndpointUrl" -ForegroundColor Gray
