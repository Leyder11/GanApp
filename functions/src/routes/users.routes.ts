import { FieldValue } from "firebase-admin/firestore";
import { Router } from "express";
import { db } from "../config/firebase";
import { requireAuth } from "../middleware/auth";
import { COLLECTIONS } from "../types/entities";
import { mapDoc } from "../utils/firestore";
import { errorResponse, successResponse } from "../utils/http";
import { updateProfileSchema } from "../validation/schemas";

export const usersRouter = Router();

usersRouter.use(requireAuth);

usersRouter.get("/me", async (req, res) => {
  const uid = req.user?.uid;
  if (!uid) {
    return errorResponse(res, 401, "UNAUTHORIZED", "Usuario no autenticado.");
  }

  const doc = await db.collection(COLLECTIONS.users).doc(uid).get();
  if (!doc.exists) {
    return errorResponse(res, 404, "USER_NOT_FOUND", "Perfil de usuario no encontrado.");
  }

  return successResponse(res, mapDoc(doc.id, doc.data() ?? {}));
});

usersRouter.patch("/me", async (req, res) => {
  const uid = req.user?.uid;
  if (!uid) {
    return errorResponse(res, 401, "UNAUTHORIZED", "Usuario no autenticado.");
  }

  const parsed = updateProfileSchema.safeParse(req.body);
  if (!parsed.success) {
    return errorResponse(res, 400, "INVALID_PAYLOAD", "Datos de perfil invalidos.", parsed.error.flatten());
  }

  const userRef = db.collection(COLLECTIONS.users).doc(uid);
  const doc = await userRef.get();
  if (!doc.exists) {
    return errorResponse(res, 404, "USER_NOT_FOUND", "Perfil de usuario no encontrado.");
  }

  await userRef.update({
    ...parsed.data,
    updatedAt: FieldValue.serverTimestamp(),
  });

  const updatedDoc = await userRef.get();
  return successResponse(res, mapDoc(updatedDoc.id, updatedDoc.data() ?? {}));
});