import { z } from "zod";

const isoDateSchema = z.string().datetime().or(z.string().regex(/^\d{4}-\d{2}-\d{2}$/));

export const registerSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
  nombre: z.string().min(2).max(80),
  nombreFinca: z.string().min(2).max(120).optional(),
  tipoUsuarioId: z.string().min(1),
});

export const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(6),
});

export const forgotPasswordSchema = z.object({
  email: z.string().email(),
});

export const syncActionSchema = z.object({
  collection: z.enum([
    "vacas",
    "prod_leche",
    "eventos_reproductivos",
    "eventos_veterinarios",
    "historial_crecimiento",
  ]),
  operation: z.enum(["create", "update", "delete"]),
  id: z.string().min(1),
  payload: z.record(z.unknown()).optional(),
});

export const syncPushSchema = z.object({
  actions: z.array(syncActionSchema).max(500),
});

export const updateProfileSchema = z.object({
  nombre: z.string().min(2).max(80).optional(),
  nombreFinca: z.string().min(2).max(120).optional(),
  currentFarmId: z.string().min(1).optional(),
  tipoUsuarioId: z.string().min(1).optional(),
});

export const farmCreateSchema = z.object({
  nombre: z.string().min(2).max(120),
});

export const farmUpdateSchema = farmCreateSchema;

export const selectFarmSchema = z.object({
  farmId: z.string().min(1),
});

export const vacaCreateSchema = z.object({
  identificador: z.string().min(1).max(50),
  fechaNacimiento: isoDateSchema,
  raza: z.string().min(2).max(80),
  sexo: z
    .union([z.enum(["macho", "hembra"]), z.enum(["M", "F"])])
    .transform((value) => (value === "M" ? "macho" : value === "F" ? "hembra" : value)),
  origen: z.string().min(2).max(120),
  estado: z.enum(["activa", "vendida", "fallecida", "seca"]),
  observaciones: z.string().max(500).optional(),
});

export const vacaUpdateSchema = vacaCreateSchema.partial();

export const prodLecheCreateSchema = z
  .object({
    vacaId: z.string().min(1),
    fecha: isoDateSchema,
    litrosManana: z.number().min(0),
    litrosTarde: z.number().min(0),
    total: z.number().min(0).optional(),
  })
  .transform((input) => ({
    ...input,
    total: input.total ?? input.litrosManana + input.litrosTarde,
  }));

export const prodLecheUpdateSchema = z
  .object({
    vacaId: z.string().min(1).optional(),
    fecha: isoDateSchema.optional(),
    litrosManana: z.number().min(0).optional(),
    litrosTarde: z.number().min(0).optional(),
    total: z.number().min(0).optional(),
  })
  .transform((input) => {
    if (typeof input.total === "number") {
      return input;
    }

    if (typeof input.litrosManana === "number" && typeof input.litrosTarde === "number") {
      return {
        ...input,
        total: input.litrosManana + input.litrosTarde,
      };
    }

    return input;
  });

export const eventoReproductivoCreateSchema = z.object({
  vacaId: z.string().min(1),
  fecha: isoDateSchema,
  tipoEvento: z.enum(["celo", "servicio", "inseminacion", "diagnostico", "parto", "aborto"]),
  tipoServicio: z.enum(["natural", "ia"]).optional(),
  toroUtilizado: z.string().max(100).optional(),
  resultadoDiagnostico: z.enum(["positivo", "negativo", "pendiente"]).optional(),
  fechaEstimadaParto: isoDateSchema.optional(),
  criaId: z.string().max(100).optional(),
  observaciones: z.string().max(500).optional(),
});

export const eventoReproductivoUpdateSchema = eventoReproductivoCreateSchema.partial();

export const eventoVeterinarioCreateSchema = z.object({
  vacaId: z.string().min(1),
  fecha: isoDateSchema,
  categoria: z.enum(["vacunacion", "desparasitacion", "tratamiento", "observacion"]).optional(),
  tipoVacuna: z.string().max(120).optional(),
  lote: z.string().max(80).optional(),
  responsable: z.string().max(120).optional(),
  producto: z.string().min(2).max(120),
  dosis: z.string().min(1).max(80),
  diagnostico: z.string().max(200).optional(),
  medicamento: z.string().max(120).optional(),
  duracionTratamientoDias: z.number().int().min(0).optional(),
  diasRetiro: z.number().int().min(0),
  fechaFinRetiro: isoDateSchema.optional(),
  veterinario: z.string().max(100).optional(),
  observaciones: z.string().max(500).optional(),
  tipoEventoId: z.string().min(1).default("general"),
});

export const eventoVeterinarioUpdateSchema = eventoVeterinarioCreateSchema.partial();

export const historialCrecimientoCreateSchema = z.object({
  vacaId: z.string().min(1),
  fecha: isoDateSchema,
  peso: z.number().positive(),
  altura: z.number().positive().optional(),
  observaciones: z.string().max(500).optional(),
});

export const historialCrecimientoUpdateSchema = historialCrecimientoCreateSchema.partial();