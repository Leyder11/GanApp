import { FieldValue } from "firebase-admin/firestore";
import { Router } from "express";
import { db } from "../config/firebase";
import { requireAuth } from "../middleware/auth";
import { COLLECTIONS } from "../types/entities";
import { managedCollections } from "../services/resources";
import { errorResponse, successResponse } from "../utils/http";
import { syncPushSchema } from "../validation/schemas";

export const syncRouter = Router();

syncRouter.use(requireAuth);

syncRouter.get("/pull", async (req, res) => {
  const uid = req.user?.uid;
  if (!uid) {
    return errorResponse(res, 401, "UNAUTHORIZED", "Usuario no autenticado.");
  }

  const since = typeof req.query.since === "string" ? req.query.since : undefined;

  const [vacas, prodLeche, eventosReproductivos, eventosVeterinarios, historialCrecimiento] =
    await Promise.all([
      managedCollections.vacas.list(uid, { includeDeleted: true, since }),
      managedCollections.prod_leche.list(uid, { includeDeleted: true, since }),
      managedCollections.eventos_reproductivos.list(uid, { includeDeleted: true, since }),
      managedCollections.eventos_veterinarios.list(uid, { includeDeleted: true, since }),
      managedCollections.historial_crecimiento.list(uid, { includeDeleted: true, since }),
    ]);

  return successResponse(res, {
    serverTime: new Date().toISOString(),
    since: since ?? null,
    changes: {
      vacas,
      prodLeche,
      eventosReproductivos,
      eventosVeterinarios,
      historialCrecimiento,
    },
  });
});

const syncCollectionMap = {
  vacas: COLLECTIONS.vacas,
  prod_leche: COLLECTIONS.prodLeche,
  eventos_reproductivos: COLLECTIONS.eventosReproductivos,
  eventos_veterinarios: COLLECTIONS.eventosVeterinarios,
  historial_crecimiento: COLLECTIONS.historialCrecimiento,
} as const;

syncRouter.post("/push", async (req, res) => {
  const uid = req.user?.uid;
  if (!uid) {
    return errorResponse(res, 401, "UNAUTHORIZED", "Usuario no autenticado.");
  }

  const parsed = syncPushSchema.safeParse(req.body);
  if (!parsed.success) {
    return errorResponse(res, 400, "INVALID_PAYLOAD", "Payload de sincronizacion invalido.", parsed.error.flatten());
  }

  const applied: Array<{ collection: string; operation: string; id: string }> = [];
  const rejected: Array<{ collection: string; operation: string; id: string; reason: string }> = [];

  for (const action of parsed.data.actions) {
    const collectionName = syncCollectionMap[action.collection];
    const docRef = db.collection(collectionName).doc(action.id);

    try {
      if (action.operation === "create") {
        await docRef.set({
          ...(action.payload ?? {}),
          ownerUid: uid,
          isDeleted: false,
          deletedAt: null,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });

        applied.push({ collection: action.collection, operation: action.operation, id: action.id });
        continue;
      }

      const existingDoc = await docRef.get();
      if (!existingDoc.exists || existingDoc.data()?.ownerUid !== uid) {
        rejected.push({
          collection: action.collection,
          operation: action.operation,
          id: action.id,
          reason: "Documento no encontrado o sin permisos.",
        });
        continue;
      }

      if (action.operation === "update") {
        await docRef.set({
          ...(action.payload ?? {}),
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });

        applied.push({ collection: action.collection, operation: action.operation, id: action.id });
        continue;
      }

      await docRef.update({
        isDeleted: true,
        deletedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      applied.push({ collection: action.collection, operation: action.operation, id: action.id });
    } catch (_error) {
      rejected.push({
        collection: action.collection,
        operation: action.operation,
        id: action.id,
        reason: "No se pudo aplicar la accion.",
      });
    }
  }

  return successResponse(res, {
    appliedCount: applied.length,
    rejectedCount: rejected.length,
    applied,
    rejected,
  });
});