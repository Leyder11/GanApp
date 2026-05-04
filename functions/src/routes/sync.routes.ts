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

function needsVacaValidation(collection: keyof typeof syncCollectionMap): boolean {
  return (
    collection === "prod_leche" ||
    collection === "eventos_reproductivos" ||
    collection === "eventos_veterinarios" ||
    collection === "historial_crecimiento"
  );
}

async function isOwnedActiveVaca(uid: string, vacaId: string): Promise<boolean> {
  const vacaDoc = await db.collection(COLLECTIONS.vacas).doc(vacaId).get();
  if (!vacaDoc.exists) {
    return false;
  }
  const data = vacaDoc.data();
  return !!data && data.ownerUid === uid && data.isDeleted !== true;
}

syncRouter.post("/push", async (req, res) => {
  try {
    const uid = req.user?.uid;
    if (!uid) {
      return errorResponse(res, 401, "UNAUTHORIZED", "Usuario no autenticado.");
    }

    const parsed = syncPushSchema.safeParse(req.body);
    if (!parsed.success) {
      console.error("Sync push schema validation failed:", parsed.error);
      return errorResponse(res, 400, "INVALID_PAYLOAD", "Payload de sincronizacion invalido.", parsed.error.flatten());
    }

    console.log(`[SYNC-PUSH] User ${uid} pushing ${parsed.data.actions.length} actions`);

    const applied: Array<{ collection: string; operation: string; id: string }> = [];
    const rejected: Array<{ collection: string; operation: string; id: string; reason: string }> = [];

    for (const action of parsed.data.actions) {
      const collectionName = syncCollectionMap[action.collection];
      const docRef = db.collection(collectionName).doc(action.id);
      const payload = (action.payload ?? {}) as Record<string, unknown>;
      const payloadVacaId = typeof payload.vacaId === "string" ? payload.vacaId.trim() : "";

      console.log(`[SYNC-PUSH] Processing action: collection=${action.collection}, operation=${action.operation}, id=${action.id}`);

      try {
        if (needsVacaValidation(action.collection)) {
          if (action.operation === "create") {
            if (!payloadVacaId) {
              console.warn(`[SYNC-PUSH] Rejected: missing vacaId for ${action.id}`);
              rejected.push({
                collection: action.collection,
                operation: action.operation,
                id: action.id,
                reason: "vacaId es obligatorio para este modulo.",
              });
              continue;
            }

            const validVaca = await isOwnedActiveVaca(uid, payloadVacaId);
            if (!validVaca) {
              console.warn(`[SYNC-PUSH] Rejected: invalid vaca ${payloadVacaId} for ${action.id}`);
              rejected.push({
                collection: action.collection,
                operation: action.operation,
                id: action.id,
                reason: "La vaca referenciada no existe o no pertenece al usuario.",
              });
              continue;
            }
          }

          if (action.operation === "update" && payloadVacaId) {
            const validVaca = await isOwnedActiveVaca(uid, payloadVacaId);
            if (!validVaca) {
              console.warn(`[SYNC-PUSH] Rejected: invalid vaca ${payloadVacaId} for update ${action.id}`);
              rejected.push({
                collection: action.collection,
                operation: action.operation,
                id: action.id,
                reason: "La vaca referenciada no existe o no pertenece al usuario.",
              });
              continue;
            }
          }
        }

        if (action.operation === "create") {
          await docRef.set({
            ...payload,
            ownerUid: uid,
            isDeleted: false,
            deletedAt: null,
            createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          }, { merge: true });

          console.log(`[SYNC-PUSH] Applied create for ${action.id}`);
          applied.push({ collection: action.collection, operation: action.operation, id: action.id });
          continue;
        }

        const existingDoc = await docRef.get();
        if (!existingDoc.exists || existingDoc.data()?.ownerUid !== uid) {
          console.warn(`[SYNC-PUSH] Rejected: doc not found or no permission for ${action.id}`);
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
            ...payload,
            updatedAt: FieldValue.serverTimestamp(),
          }, { merge: true });

          console.log(`[SYNC-PUSH] Applied update for ${action.id}`);
          applied.push({ collection: action.collection, operation: action.operation, id: action.id });
          continue;
        }

        await docRef.update({
          isDeleted: true,
          deletedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        console.log(`[SYNC-PUSH] Applied delete for ${action.id}`);
        applied.push({ collection: action.collection, operation: action.operation, id: action.id });
      } catch (_error) {
        console.error(`[SYNC-PUSH] Action error for ${action.id}:`, _error);
        rejected.push({
          collection: action.collection,
          operation: action.operation,
          id: action.id,
          reason: "No se pudo aplicar la accion.",
        });
      }
    }

    console.log(`[SYNC-PUSH] Complete: ${applied.length} applied, ${rejected.length} rejected`);
    return successResponse(res, {
      appliedCount: applied.length,
      rejectedCount: rejected.length,
      applied,
      rejected,
    });
  } catch (error) {
    console.error("[SYNC-PUSH] Endpoint error:", error);
    return errorResponse(res, 500, "INTERNAL_ERROR", "Error al procesar sincronizacion.", { error: String(error) });
  }
});