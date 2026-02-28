#!/bin/bash
set -e

echo "Compilando TypeScript..."
npx tsc

echo "Instalando dependências de produção..."
npm install --production --prefix ./

echo "Criando pacote lambda.zip..."
cd dist
cp -r ../node_modules ./
zip -r ../lambda.zip ./*
cd ..

echo "Lambda package criado: lambda.zip"