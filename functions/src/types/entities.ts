export interface TimestampedEntity {
  ownerUid: string;
  createdAt?: string;
  updatedAt?: string;
  deletedAt?: string | null;
  isDeleted?: boolean;
}

export interface Usuario extends TimestampedEntity {
  uid: string;
  nombre: string;
  email: string;
  nombreFinca?: string;
  currentFarmId?: string;
  tipoUsuarioId: string;
  fechaRegistro?: string;
  ultimaConexion?: string;
}

export interface Finca extends TimestampedEntity {
  nombre: string;
}

export interface Vaca extends TimestampedEntity {
  identificador: string;
  fechaNacimiento: string;
  raza: string;
  sexo: "macho" | "hembra";
  origen: string;
  estado: "activa" | "vendida" | "fallecida" | "seca";
  observaciones?: string;
}

export interface ProdLeche extends TimestampedEntity {
  vacaId: string;
  fecha: string;
  litrosManana: number;
  litrosTarde: number;
  total: number;
}

export interface EventoReproductivo extends TimestampedEntity {
  vacaId: string;
  fecha: string;
  tipoEvento: "celo" | "servicio" | "inseminacion" | "diagnostico" | "parto" | "aborto";
  tipoServicio?: "natural" | "ia";
  toroUtilizado?: string;
  resultadoDiagnostico?: "positivo" | "negativo" | "pendiente";
  fechaEstimadaParto?: string;
  criaId?: string;
  observaciones?: string;
}

export interface EventoVeterinario extends TimestampedEntity {
  vacaId: string;
  fecha: string;
  categoria?: "vacunacion" | "desparasitacion" | "tratamiento" | "observacion";
  tipoVacuna?: string;
  lote?: string;
  responsable?: string;
  producto: string;
  dosis: string;
  diagnostico?: string;
  medicamento?: string;
  duracionTratamientoDias?: number;
  diasRetiro: number;
  fechaFinRetiro?: string;
  veterinario?: string;
  observaciones?: string;
  tipoEventoId: string;
}

export interface HistorialCrecimiento extends TimestampedEntity {
  vacaId: string;
  fecha: string;
  peso: number;
  altura?: number;
  observaciones?: string;
}

export const COLLECTIONS = {
  users: "users",
  farms: "farms",
  vacas: "vacas",
  prodLeche: "prod_leche",
  eventosReproductivos: "eventos_reproductivos",
  eventosVeterinarios: "eventos_veterinarios",
  historialCrecimiento: "historial_crecimiento",
} as const;