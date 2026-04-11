import type { NextFunction, Request, Response } from "express";
import { auth } from "../config/firebase";
import { errorResponse } from "../utils/http";

export async function requireAuth(req: Request, res: Response, next: NextFunction): Promise<void> {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    errorResponse(res, 401, "UNAUTHORIZED", "Token no enviado o formato invalido.");
    return;
  }

  const token = authHeader.replace("Bearer ", "").trim();

  try {
    const decoded = await auth.verifyIdToken(token);

    req.user = {
      uid: decoded.uid,
      email: decoded.email,
    };

    next();
  } catch (_error) {
    errorResponse(res, 401, "INVALID_TOKEN", "El token enviado no es valido.");
  }
}