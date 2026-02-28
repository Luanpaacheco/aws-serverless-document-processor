# Script para configurar recursos AWS no LocalStack
Write-Host "=== Configurando recursos AWS ===" -ForegroundColor Cyan

$endpoint = "http://localhost:4566"

# Adicionar alunos
Write-Host "`nAdicionando alunos de teste..." -ForegroundColor Yellow

aws dynamodb put-item --table-name Alunos --item '{\"matricula\":{\"S\":\"1001\"},\"nome\":{\"S\":\"Joao Silva\"},\"curso\":{\"S\":\"Engenharia de Software\"},\"email\":{\"S\":\"joao.silva@pucrs.br\"},\"telefone\":{\"S\":\"(51) 99999-1001\"}}' --endpoint-url $endpoint

aws dynamodb put-item --table-name Alunos --item '{\"matricula\":{\"S\":\"1002\"},\"nome\":{\"S\":\"Maria Souza\"},\"curso\":{\"S\":\"Design Digital\"},\"email\":{\"S\":\"maria.souza@pucrs.br\"},\"telefone\":{\"S\":\"(51) 99999-1002\"}}' --endpoint-url $endpoint

aws dynamodb put-item --table-name Alunos --item '{\"matricula\":{\"S\":\"1003\"},\"nome\":{\"S\":\"Pedro Lima\"},\"curso\":{\"S\":\"Administracao\"},\"email\":{\"S\":\"pedro.lima@pucrs.br\"}}' --endpoint-url $endpoint

Write-Host "Alunos adicionados!" -ForegroundColor Green

# Configurar trigger SQS
Write-Host "`nConfigurando trigger SQS..." -ForegroundColor Yellow

$queueArn = aws sqs get-queue-attributes --queue-url http://localhost:4566/000000000000/documents-queue --attribute-names QueueArn --query 'Attributes.QueueArn' --output text --endpoint-url $endpoint

if ($queueArn) {
    aws lambda create-event-source-mapping --function-name document-processor --batch-size 1 --event-source-arn $queueArn --endpoint-url $endpoint
    Write-Host "Trigger SQS configurado!" -ForegroundColor Green
}

Write-Host "`n=== Recursos configurados! ===" -ForegroundColor Green
