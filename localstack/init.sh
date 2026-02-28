#!/bin/bash
set -x

echo "Inicializando LocalStack..."

# Criar bucket S3
echo "Criando bucket S3..."
awslocal s3 mb s3://documents-bucket
awslocal s3api put-bucket-cors --bucket documents-bucket --cors-configuration '{
  "CORSRules": [{
    "AllowedOrigins": ["*"],
    "AllowedMethods": ["GET", "PUT", "POST", "DELETE"],
    "AllowedHeaders": ["*"]
  }]
}'

# Criar tabela Alunos
echo "Criando tabela Alunos..."
awslocal dynamodb create-table \
  --table-name Alunos \
  --attribute-definitions AttributeName=matricula,AttributeType=S \
  --key-schema AttributeName=matricula,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

# Criar tabela Jobs
echo "Criando tabela Jobs..."
awslocal dynamodb create-table \
  --table-name Jobs \
  --attribute-definitions AttributeName=jobId,AttributeType=S \
  --key-schema AttributeName=jobId,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

# Criar fila SQS
echo "Criando fila SQS..."
awslocal sqs create-queue --queue-name documents-queue

# Aguardar para garantir que os serviços estão prontos
sleep 3

# Popular tabela Alunos com dados de exemplo
echo "Populando tabela Alunos..."
awslocal dynamodb put-item --table-name Alunos --item '{
  "matricula": {"S": "1001"},
  "nome": {"S": "João Silva"},
  "curso": {"S": "Engenharia de Software"},
  "email": {"S": "joao.silva@pucrs.br"},
  "telefone": {"S": "(51) 99999-1001"}
}'

awslocal dynamodb put-item --table-name Alunos --item '{
  "matricula": {"S": "1002"},
  "nome": {"S": "Maria Souza"},
  "curso": {"S": "Design Digital"},
  "email": {"S": "maria.souza@pucrs.br"},
  "telefone": {"S": "(51) 99999-1002"}
}'

awslocal dynamodb put-item --table-name Alunos --item '{
  "matricula": {"S": "1003"},
  "nome": {"S": "Pedro Lima"},
  "curso": {"S": "Administração"},
  "email": {"S": "pedro.lima@pucrs.br"},
  "telefone": {"S": "(51) 99999-1003"}
}'

awslocal dynamodb put-item --table-name Alunos --item '{
  "matricula": {"S": "1004"},
  "nome": {"S": "Ana Costa"},
  "curso": {"S": "Ciência da Computação"},
  "email": {"S": "ana.costa@pucrs.br"},
  "telefone": {"S": "(51) 99999-1004"}
}'

# Criar função Lambda se o arquivo zip estiver disponível
cd /docker-entrypoint-initaws.d
if [ -f lambda.zip ]; then
  echo "Criando função Lambda..."
  awslocal lambda create-function \
    --function-name document-processor \
    --runtime nodejs18.x \
    --role arn:aws:iam::000000000000:role/lambda-role \
    --handler index.handler \
    --zip-file fileb://lambda.zip \
    --environment Variables="{AWS_ENDPOINT=http://localstack:4566,BUCKET_NAME=documents-bucket}" \
    --timeout 60 \
    --memory-size 512

  # Configurar trigger SQS
  echo "Configurando trigger SQS..."
  QUEUE_ARN=$(awslocal sqs get-queue-attributes \
    --queue-url http://localhost:4566/000000000000/documents-queue \
    --attribute-names QueueArn \
    --query 'Attributes.QueueArn' \
    --output text)
  
  awslocal lambda create-event-source-mapping \
    --function-name document-processor \
    --batch-size 1 \
    --event-source-arn $QUEUE_ARN
  
  echo "Lambda criada e configurada com sucesso!"
else
  echo "⚠ lambda.zip não encontrado. A Lambda deve ser deployada manualmente."
  echo "Execute: cd localstack && ./deploy-lambda.ps1"
fi

echo "✓ Inicialização do LocalStack concluída!"
echo ""
echo "Serviços disponíveis:"
echo "  - S3: http://localhost:4566"
echo "  - DynamoDB: http://localhost:4566"
echo "  - SQS: http://localhost:4566"
echo "  - Lambda: http://localhost:4566"
echo ""
echo "Recursos criados:"
echo "  - Bucket: documents-bucket"
echo "  - Tabelas: Alunos, Jobs"
echo "  - Fila: documents-queue"
echo "  - Lambda: document-processor (se lambda.zip existir)"