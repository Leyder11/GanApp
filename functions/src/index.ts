import { onRequest } from "firebase-functions/v2/https";
import { app } from "./app";

export const api = onRequest(
  {
    region: "us-central1",
    invoker: "public",
    cors: true,
    memory: "256MiB",
    timeoutSeconds: 60,
  },
  app,
);