import { SQSEvent, SQSRecord } from "aws-lambda";
import AWS from "aws-sdk";
import PDFDocument from "pdfkit";

// Tipos
interface Aluno {
  matricula: string;
  nome: string;
  curso: string;
  email?: string;
  telefone?: string;
}

interface SQSMessage {
  jobId: string;
  matricula: string;
}

// Configuração dos serviços AWS
const awsConfig = {
  endpoint: process.env.AWS_ENDPOINT || "http://localstack:4566",
  region: process.env.AWS_REGION || "us-east-1",
  s3ForcePathStyle: true, // Necessário para LocalStack
  httpOptions: {
    timeout: 10000, // Timeout de 10 segundos para debug
  },
};

// Log de configuração
console.log(`[CONFIG] Conectando ao endpoint: ${awsConfig.endpoint}`);

const dynamo = new AWS.DynamoDB.DocumentClient({
  endpoint: awsConfig.endpoint,
  region: awsConfig.region,
});

const s3 = new AWS.S3({
  endpoint: awsConfig.endpoint,
  region: awsConfig.region,
  s3ForcePathStyle: awsConfig.s3ForcePathStyle,
});

const BUCKET_NAME = process.env.BUCKET_NAME || "documents-bucket";
const ALUNOS_TABLE = process.env.ALUNOS_TABLE || "Alunos";
const JOBS_TABLE = process.env.JOBS_TABLE || "Jobs";

// Handler principal
export const handler = async (event: SQSEvent): Promise<void> => {
  console.log(`Processando ${event.Records.length} mensagens SQS`);
  
  const results = await Promise.allSettled(
    event.Records.map((record) => processRecord(record))
  );
  
  const failures = results.filter((r) => r.status === "rejected");
  if (failures.length > 0) {
    console.error(`${failures.length} mensagens falharam no processamento`);
    failures.forEach((f, idx) => {
      if (f.status === "rejected") {
        console.error(`Erro no registro ${idx}:`, f.reason);
      }
    });
  }
  
  console.log(`Processamento concluído: ${results.length - failures.length} sucessos, ${failures.length} falhas`);
};

// Processar um registro SQS
async function processRecord(record: SQSRecord): Promise<void> {
  let jobId: string | undefined;
  
  try {
    // Log do body recebido
    console.log(`[PROCESSAMENTO] Body recebido:`, record.body);
    
    // Tentar fazer parse - pode estar duplamente serializado
    let message: SQSMessage;
    try {
      message = JSON.parse(record.body);
    } catch (e) {
      // Se falhar, tentar fazer parse novamente (duplamente serializado)
      console.log("[PARSE] Tentando parse duplo...");
      message = JSON.parse(JSON.parse(record.body));
    }
    
    jobId = message.jobId;
    const { matricula } = message;
    
    console.log(`[LAMBDA] Iniciando processamento Job=${jobId} Matricula=${matricula}`);
    
    // Atualizar status para PROCESSING
    console.log(`[DB] Atualizando status para PROCESSING...`);
    await updateJobStatus(jobId, "PROCESSING");
    console.log(`[DB] Status atualizado para PROCESSING`);
    
    // Buscar aluno no DynamoDB
    console.log(`[DB] Buscando aluno matricula=${matricula}...`);
    const aluno = await getAluno(matricula);
    console.log(`[DB] Resultado: ${aluno ? 'Encontrado' : 'Não encontrado'}`);
    
    if (!aluno) {
      throw new Error(`Aluno com matrícula ${matricula} não encontrado`);
    }
    
    console.log(`[PDF] Aluno encontrado: ${aluno.nome}`);
    
    // Gerar PDF em buffer
    console.log(`[PDF] Iniciando geração de PDF...`);
    const pdfBuffer = await generatePDF(aluno);
    console.log(`[PDF] PDF gerado com sucesso: ${pdfBuffer.length} bytes`);
    
    // Salvar no S3
    const s3Key = `documents/${jobId}.pdf`;
    console.log(`[S3] Enviando PDF para ${s3Key}...`);
    await uploadToS3(s3Key, pdfBuffer);
    console.log(`[S3] PDF salvo com sucesso`);
    
    // Atualizar status no DynamoDB
    console.log(`[DB] Atualizando status para COMPLETED...`);
    await updateJobCompleted(jobId, s3Key);
    console.log(`[SUCCESS] Job ${jobId} concluído com sucesso`);
    
  } catch (error) {
    console.error(`[ERROR] Erro ao processar registro:`, error);
    
    if (jobId) {
      await markJobFailed(jobId, error instanceof Error ? error.message : "Erro desconhecido");
    }
    
    throw error; // Re-throw para o Promise.allSettled
  }
}

// Buscar aluno no DynamoDB
async function getAluno(matricula: string): Promise<Aluno | null> {
  try {
    console.log(`[GET_ALUNO] Iniciando busca...`);
    const result = await dynamo
      .get({
        TableName: ALUNOS_TABLE,
        Key: { matricula },
      })
      .promise();
    console.log(`[GET_ALUNO] Busca concluída`);
    
    return result.Item as Aluno || null;
  } catch (error) {
    console.error(`[GET_ALUNO] Erro:`, error);
    throw error;
  }
}

// Atualizar status do job
async function updateJobStatus(jobId: string, status: string): Promise<void> {
  try {
    console.log(`[UPDATE_STATUS] Iniciando update jobId=${jobId} status=${status}...`);
    const updateParams = {
      TableName: JOBS_TABLE,
      Key: { jobId },
      UpdateExpression: "set #status = :s, updatedAt = :t",
      ExpressionAttributeNames: { "#status": "status" },
      ExpressionAttributeValues: {
        ":s": status,
        ":t": new Date().toISOString(),
      },
    };
    console.log(`[UPDATE_STATUS] Parâmetros:`, JSON.stringify(updateParams).substring(0, 100));
    
    await dynamo.update(updateParams).promise();
    console.log(`[UPDATE_STATUS] Update concluído`);
  } catch (error) {
    console.error(`[UPDATE_STATUS] Erro:`, error);
    throw error;
  }
}

// Marcar job como completo
async function updateJobCompleted(jobId: string, pdfKey: string): Promise<void> {
  try {
    console.log(`[UPDATE_COMPLETED] Iniciando jobId=${jobId} pdfKey=${pdfKey}...`);
    await dynamo
      .update({
        TableName: JOBS_TABLE,
        Key: { jobId },
        UpdateExpression: "set #status = :s, pdfKey = :k, completedAt = :t",
        ExpressionAttributeNames: { "#status": "status" },
        ExpressionAttributeValues: {
          ":s": "COMPLETED",
          ":k": pdfKey,
          ":t": new Date().toISOString(),
        },
      })
      .promise();
    console.log(`[UPDATE_COMPLETED] Update concluído`);
  } catch (error) {
    console.error(`[UPDATE_COMPLETED] Erro:`, error);
    throw error;
  }
}

// Marcar job como falho
async function markJobFailed(jobId: string, errorMessage: string): Promise<void> {
  try {
    await dynamo
      .update({
        TableName: JOBS_TABLE,
        Key: { jobId },
        UpdateExpression: "set #status = :s, errorMessage = :e, failedAt = :t",
        ExpressionAttributeNames: { "#status": "status" },
        ExpressionAttributeValues: {
          ":s": "FAILED",
          ":e": errorMessage,
          ":t": new Date().toISOString(),
        },
      })
      .promise();
    
    console.log(`Job ${jobId} marcado como FAILED`);
  } catch (error) {
    console.error(`Erro ao marcar job como falho:`, error);
  }
}

// Upload para S3
async function uploadToS3(key: string, buffer: Buffer): Promise<void> {
  try {
    console.log(`[S3_UPLOAD] Iniciando envio bucket=${BUCKET_NAME} key=${key} size=${buffer.length}...`);
    await s3
      .putObject({
        Bucket: BUCKET_NAME,
        Key: key,
        Body: buffer,
        ContentType: "application/pdf",
      })
      .promise();
    console.log(`[S3_UPLOAD] Envio concluído`);
  } catch (error) {
    console.error(`[S3_UPLOAD] Erro:`, error);
    throw error;
  }
}

// Gerar PDF com PDFKit
function generatePDF(aluno: Aluno): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    try {
      const doc = new PDFDocument({
        size: "A4",
        margins: { top: 50, bottom: 50, left: 50, right: 50 },
      });
      
      const chunks: Buffer[] = [];
      
      doc.on("data", (chunk: Buffer) => chunks.push(chunk));
      doc.on("end", () => resolve(Buffer.concat(chunks)));
      doc.on("error", reject);
      
      // Cabeçalho
      doc
        .fontSize(20)
        .font("Helvetica-Bold")
        .text("DECLARAÇÃO DE MATRÍCULA", { align: "center" })
        .moveDown(2);
      
      // Informações do aluno
      doc
        .fontSize(12)
        .font("Helvetica")
        .text(`Nome: ${aluno.nome}`, { continued: false })
        .moveDown(0.5)
        .text(`Matrícula: ${aluno.matricula}`)
        .moveDown(0.5)
        .text(`Curso: ${aluno.curso}`)
        .moveDown(0.5);
      
      if (aluno.email) {
        doc.text(`E-mail: ${aluno.email}`).moveDown(0.5);
      }
      
      if (aluno.telefone) {
        doc.text(`Telefone: ${aluno.telefone}`).moveDown(0.5);
      }
      
      // Texto da declaração
      doc
        .moveDown(2)
        .fontSize(11)
        .text(
          `Declaramos para os devidos fins que o(a) aluno(a) acima identificado(a) ` +
          `está regularmente matriculado(a) nesta instituição no curso de ${aluno.curso}.`,
          { align: "justify" }
        )
        .moveDown(2);
      
      // Data e local
      const dataAtual = new Date().toLocaleDateString("pt-BR", {
        day: "2-digit",
        month: "long",
        year: "numeric",
      });
      
      doc
        .fontSize(10)
        .text(`Porto Alegre, ${dataAtual}`, { align: "center" })
        .moveDown(3)
        .text("_______________________________", { align: "center" })
        .text("Secretaria Acadêmica", { align: "center" });
      
      // Rodapé
      doc
        .fontSize(8)
        .text(
          "Este documento foi gerado automaticamente e possui validade legal.",
          50,
          doc.page.height - 50,
          { align: "center" }
        );
      
      doc.end();
    } catch (error) {
      reject(error);
    }
  });
}
