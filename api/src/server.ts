import express from "express";
import { Request, Response } from "express";
import AWS from "aws-sdk";
import { v4 as uuidv4 } from "uuid";

const app = express();
app.use(express.json());

const endpoint = process.env.AWS_ENDPOINT || "http://localhost:4566";

const dynamo = new AWS.DynamoDB.DocumentClient({
  endpoint,
  region: "us-east-1",
});

const sqs = new AWS.SQS({ endpoint, region: "us-east-1" });

const QUEUE_URL =
  process.env.QUEUE_URL || "http://localhost:4566/000000000000/documents-queue";

app.post("/request-document", async (req: Request, res: Response) => {
  const { matricula } = req.body;
  if (!matricula)
    return res.status(400).json({ error: "matricula obrigatoria" });

  const jobId = uuidv4();
  const job = { jobId, matricula, status: "pending", pdfKey: null };
  try {
    await dynamo.put({ TableName: "Jobs", Item: job }).promise();
    await sqs
      .sendMessage({
        QueueUrl: QUEUE_URL,
        MessageBody: JSON.stringify({ jobId, matricula }),
      })
      .promise();
    res.json({ jobId, status: "pending" });
  } catch (err) {
    console.log(err);
    res.status(500).json({ error: "erro interno" });
  }
});

app.get("/request-document/:id", async (req: Request, res: Response) => {
  const { id } = req.params;
  try {
    const result = await dynamo
      .get({ TableName: "Jobs", Key: { jobId: id } })
      .promise();
    if (!result.Item)
      return res.status(404).json({ error: "Job não encontrado" });
    res.json(result.Item);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Erro interno" });
  }
});

app.listen(3000, () => console.log("API rodando na porta 3000"));
