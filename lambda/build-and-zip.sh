#!/bin/bash
echo "Compilando TypeScript..."
npx tsc

echo "Instalando dependências de produção..."
npm install --production

echo "Criando pacote lambda.zip com PowerShell..."
powershell "bestzip lambda.zip dist node_modules package.json"

echo "Pacote criado: lambda.zip"