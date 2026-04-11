import { COLLECTIONS } from "../types/entities";
import { OwnedResourceService } from "./owned-resource.service";

export const vacasService = new OwnedResourceService(COLLECTIONS.vacas);
export const prodLecheService = new OwnedResourceService(COLLECTIONS.prodLeche);
export const eventosReproductivosService = new OwnedResourceService(COLLECTIONS.eventosReproductivos);
export const eventosVeterinariosService = new OwnedResourceService(COLLECTIONS.eventosVeterinarios);
export const historialCrecimientoService = new OwnedResourceService(COLLECTIONS.historialCrecimiento);

export const managedCollections = {
  vacas: vacasService,
  prod_leche: prodLecheService,
  eventos_reproductivos: eventosReproductivosService,
  eventos_veterinarios: eventosVeterinariosService,
  historial_crecimiento: historialCrecimientoService,
};