import type { Response } from "express";

export function successResponse<T>(res: Response, data: T, statusCode = 200): Response {
  return res.status(statusCode).json({
    ok: true,
    data,
  });
}

export function errorResponse(
  res: Response,
  statusCode: number,
  code: string,
  message: string,
  details?: unknown,
): Response {
  return res.status(statusCode).json({
    ok: false,
    error: {
      code,
      message,
      details,
    },
  });
}