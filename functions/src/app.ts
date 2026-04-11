import cors from "cors";
import express from "express";
import { authRouter } from "./routes/auth.routes";
import { dashboardRouter } from "./routes/dashboard.routes";
import { farmsRouter } from "./routes/farms.routes";
import { resourceRouter } from "./routes/resource.routes";
import { syncRouter } from "./routes/sync.routes";
import { usersRouter } from "./routes/users.routes";
import { errorResponse, successResponse } from "./utils/http";

export const app = express();

app.use(cors({ origin: true }));
app.use(express.json({ limit: "1mb" }));

app.get("/health", (_req, res) => {
  return successResponse(res, {
    service: "ganapp-backend",
    status: "ok",
    timestamp: new Date().toISOString(),
  });
});

app.use("/api/v1/auth", authRouter);
app.use("/api/v1/users", usersRouter);
app.use("/api/v1/farms", farmsRouter);
app.use("/api/v1/dashboard", dashboardRouter);
app.use("/api/v1", resourceRouter);
app.use("/api/v1/sync", syncRouter);

app.use((err: unknown, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error(err);
  return errorResponse(res, 500, "INTERNAL_ERROR", "Ocurrio un error inesperado en el servidor.");
});