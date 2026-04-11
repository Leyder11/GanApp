import type { Router as ExpressRouter } from "express";
import { Router } from "express";
import type { ZodTypeAny } from "zod";
import { db } from "../config/firebase";
import { requireAuth } from "../middleware/auth";
import {
  eventosReproductivosService,
  eventosVeterinariosService,
  historialCrecimientoService,
  prodLecheService,
  vacasService,
} from "../services/resources";
import { COLLECTIONS } from "../types/entities";
import { errorResponse, successResponse } from "../utils/http";
import {
  eventoReproductivoCreateSchema,
  eventoReproductivoUpdateSchema,
  eventoVeterinarioCreateSchema,
  eventoVeterinarioUpdateSchema,
  historialCrecimientoCreateSchema,
  historialCrecimientoUpdateSchema,
  prodLecheCreateSchema,
  prodLecheUpdateSchema,
  vacaCreateSchema,
  vacaUpdateSchema,
} from "../validation/schemas";

type ResourceConfig = {
  service: {
    create: (ownerUid: string, payload: object) => Promise<Record<string, unknown>>;
    list: (
      ownerUid: string,
      options?: { includeDeleted?: boolean; since?: string },
    ) => Promise<Array<Record<string, unknown>>>;
    findById: (ownerUid: string, id: string) => Promise<Record<string, unknown> | null>;
    update: (ownerUid: string, id: string, payload: object) => Promise<Record<string, unknown> | null>;
    softDelete: (ownerUid: string, id: string) => Promise<boolean>;
  };
  createSchema: ZodTypeAny;
  updateSchema: ZodTypeAny;
  validateCreate?: (ownerUid: string, payload: Record<string, unknown>) => Promise<string | null>;
  validateUpdate?: (ownerUid: string, payload: Record<string, unknown>) => Promise<string | null>;
  transformCreate?: (payload: Record<string, unknown>) => Record<string, unknown>;
  transformUpdate?: (payload: Record<string, unknown>) => Record<string, unknown>;
  registerExtraRoutes?: (router: ExpressRouter) => void;
};

const DAYS_GESTATION = 283;

function normalizeDateOnly(value: unknown): string | null {
  const raw = String(value ?? "").trim();
  if (!raw) {
    return null;
  }

  const parsed = new Date(raw);
  if (Number.isNaN(parsed.getTime())) {
    return null;
  }

  return parsed.toISOString().slice(0, 10);
}

function addDays(dateIso: string, days: number): string {
  const parsed = new Date(dateIso);
  parsed.setUTCDate(parsed.getUTCDate() + days);
  return parsed.toISOString().slice(0, 10);
}

function normalizeReproductivePayload(payload: Record<string, unknown>): Record<string, unknown> {
  const tipoEvento = String(payload.tipoEvento ?? "").trim().toLowerCase();
  const fecha = normalizeDateOnly(payload.fecha);
  const normalized: Record<string, unknown> = {
    ...payload,
    tipoEvento,
    fecha: fecha ?? payload.fecha,
  };

  if (tipoEvento === "servicio" || tipoEvento === "inseminacion") {
    if (fecha) {
      normalized.fechaEstimadaParto = addDays(fecha, DAYS_GESTATION);
    }
    if (!normalized.tipoServicio) {
      normalized.tipoServicio = tipoEvento === "inseminacion" ? "ia" : "natural";
    }
  }

  if (
    tipoEvento === "diagnostico" &&
    String(payload.resultadoDiagnostico ?? "").toLowerCase() === "negativo"
  ) {
    normalized.fechaEstimadaParto = null;
  }

  if (tipoEvento === "aborto" || tipoEvento === "parto") {
    normalized.fechaEstimadaParto = null;
  }

  return normalized;
}

async function validateOwnedVacaRef(ownerUid: string, vacaId: string): Promise<string | null> {
  const vacaDoc = await db.collection(COLLECTIONS.vacas).doc(vacaId).get();
  const data = vacaDoc.data();

  if (!vacaDoc.exists || !data || data.ownerUid !== ownerUid || data.isDeleted === true) {
    return "La vaca referenciada no existe o no pertenece al usuario.";
  }

  return null;
}

async function validatePayloadVacaRef(
  ownerUid: string,
  payload: Record<string, unknown>,
  required: boolean,
): Promise<string | null> {
  const rawVacaId = payload.vacaId;

  if (rawVacaId == null) {
    return required ? "El campo vacaId es obligatorio." : null;
  }

  const vacaId = String(rawVacaId).trim();
  if (!vacaId) {
    return "El campo vacaId es obligatorio.";
  }

  return validateOwnedVacaRef(ownerUid, vacaId);
}

function buildCrudRouter(config: ResourceConfig): ExpressRouter {
  const router = Router();

  router.use(requireAuth);

  if (config.registerExtraRoutes) {
    config.registerExtraRoutes(router);
  }

  router.get("/", async (req, res) => {
    const uid = req.user?.uid;
    if (!uid) {
      return errorResponse(res, 401, "UNAUTHORIZED", "Usuario no autenticado.");
    }

    const data = await config.service.list(uid);
    return successResponse(res, data);
  });

  router.get("/:id", async (req, res) => {
    const uid = req.user?.uid;
    if (!uid) {
      return errorResponse(res, 401, "UNAUTHORIZED", "Usuario no autenticado.");
    }

    const data = await config.service.findById(uid, req.params.id);
    if (!data) {
      return errorResponse(res, 404, "NOT_FOUND", "Registro no encontrado.");
    }

    return successResponse(res, data);
  });

  router.post("/", async (req, res) => {
    const uid = req.user?.uid;
    if (!uid) {
      return errorResponse(res, 401, "UNAUTHORIZED", "Usuario no autenticado.");
    }

    const parsed = config.createSchema.safeParse(req.body);
    if (!parsed.success) {
      return errorResponse(res, 400, "INVALID_PAYLOAD", "Payload invalido.", parsed.error.flatten());
    }

    if (config.validateCreate) {
      const message = await config.validateCreate(uid, parsed.data as Record<string, unknown>);
      if (message) {
        return errorResponse(res, 400, "INVALID_REFERENCE", message);
      }
    }

    const payload = config.transformCreate
      ? config.transformCreate(parsed.data as Record<string, unknown>)
      : (parsed.data as Record<string, unknown>);

    const created = await config.service.create(uid, payload);
    return successResponse(res, created, 201);
  });

  router.patch("/:id", async (req, res) => {
    const uid = req.user?.uid;
    if (!uid) {
      return errorResponse(res, 401, "UNAUTHORIZED", "Usuario no autenticado.");
    }

    const parsed = config.updateSchema.safeParse(req.body);
    if (!parsed.success) {
      return errorResponse(res, 400, "INVALID_PAYLOAD", "Payload invalido.", parsed.error.flatten());
    }

    if (config.validateUpdate) {
      const message = await config.validateUpdate(uid, parsed.data as Record<string, unknown>);
      if (message) {
        return errorResponse(res, 400, "INVALID_REFERENCE", message);
      }
    }

    const payload = config.transformUpdate
      ? config.transformUpdate(parsed.data as Record<string, unknown>)
      : (parsed.data as Record<string, unknown>);

    const updated = await config.service.update(uid, req.params.id, payload);
    if (!updated) {
      return errorResponse(res, 404, "NOT_FOUND", "Registro no encontrado o no editable.");
    }

    return successResponse(res, updated);
  });

  router.delete("/:id", async (req, res) => {
    const uid = req.user?.uid;
    if (!uid) {
      return errorResponse(res, 401, "UNAUTHORIZED", "Usuario no autenticado.");
    }

    const deleted = await config.service.softDelete(uid, req.params.id);
    if (!deleted) {
      return errorResponse(res, 404, "NOT_FOUND", "Registro no encontrado o ya eliminado.");
    }

    return successResponse(res, { id: req.params.id, deleted: true });
  });

  return router;
}

export const resourceRouter = Router();

resourceRouter.use(
  "/vacas",
  buildCrudRouter({
    service: vacasService,
    createSchema: vacaCreateSchema,
    updateSchema: vacaUpdateSchema,
    registerExtraRoutes: (router) => {
      router.get("/:id/ficha-completa", async (req, res) => {
        const uid = req.user?.uid;
        if (!uid) {
          return errorResponse(res, 401, "UNAUTHORIZED", "Usuario no autenticado.");
        }

        const vaca = await vacasService.findById(uid, req.params.id);
        if (!vaca) {
          return errorResponse(res, 404, "NOT_FOUND", "Vaca no encontrada.");
        }

        const vacaId = String(vaca.id ?? "");

        const [reproductivo, leche, sanitario] = await Promise.all([
          eventosReproductivosService.list(uid),
          prodLecheService.list(uid),
          eventosVeterinariosService.list(uid),
        ]);

        const reproductivoByVaca = reproductivo
          .filter((r) => String(r.vacaId ?? "") === vacaId)
          .sort((a, b) => String(b.fecha ?? "").localeCompare(String(a.fecha ?? "")));

        const lecheByVaca = leche
          .filter((r) => String(r.vacaId ?? "") === vacaId)
          .sort((a, b) => String(b.fecha ?? "").localeCompare(String(a.fecha ?? "")));

        const sanitarioByVaca = sanitario
          .filter((r) => String(r.vacaId ?? "") === vacaId)
          .sort((a, b) => String(b.fecha ?? "").localeCompare(String(a.fecha ?? "")));

        return successResponse(res, {
          vaca,
          historialReproductivo: reproductivoByVaca,
          historialLeche: lecheByVaca,
          historialSanitario: sanitarioByVaca,
        });
      });
    },
  }),
);

resourceRouter.use(
  "/prod-leche",
  buildCrudRouter({
    service: prodLecheService,
    createSchema: prodLecheCreateSchema,
    updateSchema: prodLecheUpdateSchema,
    validateCreate: (uid, payload) => validatePayloadVacaRef(uid, payload, true),
    validateUpdate: (uid, payload) => validatePayloadVacaRef(uid, payload, false),
    registerExtraRoutes: (router) => {
      router.get("/historial", async (req, res) => {
        const uid = req.user?.uid;
        if (!uid) {
          return errorResponse(res, 401, "UNAUTHORIZED", "Usuario no autenticado.");
        }

        const vacaId = String(req.query.vacaId ?? "").trim();
        const from = String(req.query.from ?? "").trim();
        const to = String(req.query.to ?? "").trim();

        const records = await prodLecheService.list(uid);
        const filtered = records
          .filter((record) => {
            const recordVacaId = String(record.vacaId ?? "");
            const fecha = String(record.fecha ?? "").slice(0, 10);

            if (vacaId && recordVacaId !== vacaId) {
              return false;
            }

            if (from && fecha < from) {
              return false;
            }

            if (to && fecha > to) {
              return false;
            }

            return true;
          })
          .sort((a, b) => String(b.fecha ?? "").localeCompare(String(a.fecha ?? "")));

        return successResponse(res, filtered);
      });

      router.get("/promedios", async (req, res) => {
        const uid = req.user?.uid;
        if (!uid) {
          return errorResponse(res, 401, "UNAUTHORIZED", "Usuario no autenticado.");
        }

        const daysRaw = Number(req.query.days ?? 30);
        const days = [7, 30, 90].includes(daysRaw) ? daysRaw : 30;
        const vacaId = String(req.query.vacaId ?? "").trim();

        const now = new Date();
        const start = new Date(now);
        start.setUTCDate(start.getUTCDate() - (days - 1));
        const startIso = start.toISOString().slice(0, 10);

        const records = await prodLecheService.list(uid);
        const filtered = records.filter((record) => {
          const fecha = String(record.fecha ?? "").slice(0, 10);
          const recordVacaId = String(record.vacaId ?? "");
          if (fecha < startIso) {
            return false;
          }
          if (vacaId && recordVacaId !== vacaId) {
            return false;
          }
          return true;
        });

        const map = new Map<string, { liters: number; days: Set<string> }>();
        filtered.forEach((record) => {
          const id = String(record.vacaId ?? "").trim();
          if (!id) {
            return;
          }

          const stats = map.get(id) ?? { liters: 0, days: new Set<string>() };
          stats.liters += Number(record.total ?? 0);
          stats.days.add(String(record.fecha ?? "").slice(0, 10));
          map.set(id, stats);
        });

        const result = Array.from(map.entries())
          .map(([id, stats]) => ({
            vacaId: id,
            totalLitros: Number(stats.liters.toFixed(2)),
            diasConRegistro: stats.days.size,
            promedioDiario: Number((stats.liters / days).toFixed(2)),
            promedioPorDiaConRegistro: Number(
              (stats.liters / Math.max(1, stats.days.size)).toFixed(2),
            ),
            periodoDias: days,
          }))
          .sort((a, b) => b.promedioDiario - a.promedioDiario);

        return successResponse(res, result);
      });
    },
  }),
);

resourceRouter.use(
  "/eventos-reproductivos",
  buildCrudRouter({
    service: eventosReproductivosService,
    createSchema: eventoReproductivoCreateSchema,
    updateSchema: eventoReproductivoUpdateSchema,
    validateCreate: (uid, payload) => validatePayloadVacaRef(uid, payload, true),
    validateUpdate: (uid, payload) => validatePayloadVacaRef(uid, payload, false),
    transformCreate: normalizeReproductivePayload,
    transformUpdate: normalizeReproductivePayload,
    registerExtraRoutes: (router) => {
      router.get("/historial/:vacaId", async (req, res) => {
        const uid = req.user?.uid;
        if (!uid) {
          return errorResponse(res, 401, "UNAUTHORIZED", "Usuario no autenticado.");
        }

        const vacaId = String(req.params.vacaId ?? "").trim();
        if (!vacaId) {
          return errorResponse(res, 400, "INVALID_PAYLOAD", "vacaId invalido.");
        }

        const vacaError = await validateOwnedVacaRef(uid, vacaId);
        if (vacaError) {
          return errorResponse(res, 404, "NOT_FOUND", vacaError);
        }

        const events = await eventosReproductivosService.list(uid);
        const history = events
          .filter((event) => String(event.vacaId ?? "") === vacaId)
          .sort((a, b) => String(b.fecha ?? "").localeCompare(String(a.fecha ?? "")));

        return successResponse(res, history);
      });
    },
  }),
);

resourceRouter.use(
  "/eventos-veterinarios",
  buildCrudRouter({
    service: eventosVeterinariosService,
    createSchema: eventoVeterinarioCreateSchema,
    updateSchema: eventoVeterinarioUpdateSchema,
    validateCreate: (uid, payload) => validatePayloadVacaRef(uid, payload, true),
    validateUpdate: (uid, payload) => validatePayloadVacaRef(uid, payload, false),
    registerExtraRoutes: (router) => {
      router.get("/historial/:vacaId", async (req, res) => {
        const uid = req.user?.uid;
        if (!uid) {
          return errorResponse(res, 401, "UNAUTHORIZED", "Usuario no autenticado.");
        }

        const vacaId = String(req.params.vacaId ?? "").trim();
        if (!vacaId) {
          return errorResponse(res, 400, "INVALID_PAYLOAD", "vacaId invalido.");
        }

        const vacaError = await validateOwnedVacaRef(uid, vacaId);
        if (vacaError) {
          return errorResponse(res, 404, "NOT_FOUND", vacaError);
        }

        const events = await eventosVeterinariosService.list(uid);
        const history = events
          .filter((event) => String(event.vacaId ?? "") === vacaId)
          .sort((a, b) => String(b.fecha ?? "").localeCompare(String(a.fecha ?? "")));

        return successResponse(res, history);
      });
    },
  }),
);

resourceRouter.use(
  "/historial-crecimiento",
  buildCrudRouter({
    service: historialCrecimientoService,
    createSchema: historialCrecimientoCreateSchema,
    updateSchema: historialCrecimientoUpdateSchema,
    validateCreate: (uid, payload) => validatePayloadVacaRef(uid, payload, true),
    validateUpdate: (uid, payload) => validatePayloadVacaRef(uid, payload, false),
  }),
);