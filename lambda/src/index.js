import AWS from "aws-sdk";
import PDFDocument from "pdfkit";
const dynamo = new AWS.DynamoDB.DocumentClient({
    endpoint: process.env.AWS_ENDPOINT || "http://localstack:4566",
    region: "us-east-1",
});
const s3 = new AWS.S3({
    endpoint: process.env.AWS_ENDPOINT || "http://localstack:4566",
    region: "us-east-1",
});
const BUCKET_NAME = process.env.BUCKET_NAME || "documents-bucket";
export const handler = async (event, context) => {
    console.log("evento recebido");
    for (const record of event.Records) {
        try {
            await processRecord(record);
        }
        catch (e) {
            console.error("erro ao processar registro", e);
            throw e;
        }
    }
};
async function processRecord(record) {
    const { jobId, matricula } = JSON.parse(record.body);
    console.log(`processando job${jobId} da matricula ${matricula}`);
    const alunoRes = await dynamo
        .get({ TableName: "Aluno", Key: { matricula } })
        .promise();
    if (!alunoRes.Item) {
        console.log("matricula de aluno nao existe");
        await markJobFailed(jobId);
        return;
    }
    const aluno = alunoRes.Item;
    const pdfBuffer = await generatePDF(aluno);
    await s3
        .putObject({
        Bucket: BUCKET_NAME,
        Key: `${jobId}.pdf`,
        Body: pdfBuffer,
        ContentType: "application/pdf",
    })
        .promise();
    console.log(`job ${jobId} concluido com sucesso`);
}
async function markJobFailed(jobId) {
    await dynamo
        .update({
        TableName: "Jobs",
        Key: { jobId },
        UpdateExpression: "set #status = :s",
        ExpressionAttributeNames: { "#status": "status" },
        ExpressionAttributeValues: { ":s": "FAILED" },
    })
        .promise();
}
function generatePDF(aluno) {
    return new Promise((resolve, reject) => {
        try {
            const doc = new PDFDocument();
            const buffers = [];
            doc.on("data", buffers.push.bind(buffers));
            doc.on("end", () => resolve(Buffer.concat(buffers)));
            doc.text(`Nome: ${aluno.nome}`);
            doc.text(`Matrícula: ${aluno.matricula}`);
            doc.text(`Curso: ${aluno.curso}`);
            doc.end();
        }
        catch (err) {
            reject(err);
        }
    });
}
//# sourceMappingURL=index.js.map