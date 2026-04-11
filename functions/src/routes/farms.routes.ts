import { FieldValue } from "firebase-admin/firestore";
import { Router } from "express";
import { db } from "../config/firebase";
import { requireAuth } from "../middleware/auth";
import { COLLECTIONS } from "../types/entities";
import { mapDoc } from "../utils/firestore";
import { errorResponse, successResponse } from "../utils/http";
import { farmCreateSchema, farmUpdateSchema, selectFarmSchema } from "../validation/schemas";

export const farmsRouter = Router();

farmsRouter.use(requireAuth);

farmsRouter.get("/", async (req, res) => {
  const uid = req.user?.uid;
  if (!uid) {
    return errorResponse(res, 401, "UNAUTHORIZED", "Usuario no autenticado.");
  }

  let snapshot;
  try {
    snapshot = await db
      .collection(COLLECTIONS.farms)
      .where("ownerUid", "==", uid)
      .where("isDeleted", "==", false)
      .orderBy("updatedAt", "desc")
      .get();
  } catch (error) {
    console.error("Farms list fallback:", error);
    snapshot = await db
      .collection(COLLECTIONS.farms)
      .where("ownerUid", "==", uid)
      .where("isDeleted", "==", false)
      .get();
  }

  return successResponse(
    res,
    snapshot.docs.map((doc) => mapDoc(doc.id, doc.data())),
  );
});

farmsRouter.post("/", async (req, res) => {
  const uid = req.user?.uid;
  if (!uid) {
    return errorResponse(res, 401, "UNAUTHORIZED", "Usuario no autenticado.");
  }

  const parsed = farmCreateSchema.safeParse(req.body);
  if (!parsed.success) {
    return errorResponse(res, 400, "INVALID_PAYLOAD", "Datos de finca invalidos.", parsed.error.flatten());
  }

  const docRef = await db.collection(COLLECTIONS.farms).add({
    nombre: parsed.data.nombre,
    ownerUid: uid,
    isDeleted: false,
    deletedAt: null,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  const created = await docRef.get();
  return successResponse(res, mapDoc(created.id, created.data() ?? {}), 201);
});

farmsRouter.patch("/:id", async (req, res) => {
  const uid = req.user?.uid;
  if (!uid) {
    return errorResponse(res, 401, "UNAUTHORIZED", "Usuario no autenticado.");
  }

  const parsed = farmUpdateSchema.safeParse(req.body);
  if (!parsed.success) {
    return errorResponse(res, 400, "INVALID_PAYLOAD", "Datos de finca invalidos.", parsed.error.flatten());
  }

  const docRef = db.collection(COLLECTIONS.farms).doc(req.params.id);
  const existing = await docRef.get();

  if (!existing.exists || existing.data()?.ownerUid !== uid || existing.data()?.isDeleted === true) {
    return errorResponse(res, 404, "NOT_FOUND", "Finca no encontrada.");
  }

  await docRef.update({
    nombre: parsed.data.nombre,
    updatedAt: FieldValue.serverTimestamp(),
  });

  const updated = await docRef.get();
  return successResponse(res, mapDoc(updated.id, updated.data() ?? {}));
});

farmsRouter.delete("/:id", async (req, res) => {
  const uid = req.user?.uid;
  if (!uid) {
    return errorResponse(res, 401, "UNAUTHORIZED", "Usuario no autenticado.");
  }

  const docRef = db.collection(COLLECTIONS.farms).doc(req.params.id);
  const existing = await docRef.get();

  if (!existing.exists || existing.data()?.ownerUid !== uid || existing.data()?.isDeleted === true) {
    return errorResponse(res, 404, "NOT_FOUND", "Finca no encontrada.");
  }

  await docRef.update({
    isDeleted: true,
    deletedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  return successResponse(res, { id: req.params.id, deleted: true });
});

farmsRouter.post("/select", async (req, res) => {
  const uid = req.user?.uid;
  if (!uid) {
    return errorResponse(res, 401, "UNAUTHORIZED", "Usuario no autenticado.");
  }

  const parsed = selectFarmSchema.safeParse(req.body);
  if (!parsed.success) {
    return errorResponse(res, 400, "INVALID_PAYLOAD", "Seleccion de finca invalida.", parsed.error.flatten());
  }

  const farmRef = db.collection(COLLECTIONS.farms).doc(parsed.data.farmId);
  const farmDoc = await farmRef.get();
  if (!farmDoc.exists || farmDoc.data()?.ownerUid !== uid || farmDoc.data()?.isDeleted === true) {
    return errorResponse(res, 404, "NOT_FOUND", "Finca no encontrada.");
  }

  const farmName = farmDoc.data()?.nombre;

  const userRef = db.collection(COLLECTIONS.users).doc(uid);
  await userRef.update({
    currentFarmId: parsed.data.farmId,
    nombreFinca: typeof farmName === "string" ? farmName : null,
    updatedAt: FieldValue.serverTimestamp(),
  });

  const userDoc = await userRef.get();
  return successResponse(res, mapDoc(userDoc.id, userDoc.data() ?? {}));
});
