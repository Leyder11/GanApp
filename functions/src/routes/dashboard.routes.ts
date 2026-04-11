import { Router } from "express";
import { requireAuth } from "../middleware/auth";
import { managedCollections } from "../services/resources";
import { errorResponse, successResponse } from "../utils/http";

export const dashboardRouter = Router();

function dateMinusDays(base: Date, days: number): string {
  const d = new Date(base);
  d.setUTCDate(d.getUTCDate() - days);
  return d.toISOString().slice(0, 10);
}

function aggregateTrend(
  records: Array<Record<string, unknown>>,
  days: number,
  todayIso: string,
): Array<Record<string, unknown>> {
  const startIso = dateMinusDays(new Date(`${todayIso}T00:00:00.000Z`), days - 1);
  const buckets = new Map<string, number>();

  records.forEach((record) => {
    const fecha = String(record.fecha ?? "").slice(0, 10);
    if (!fecha || fecha < startIso || fecha > todayIso) {
      return;
    }

    buckets.set(fecha, (buckets.get(fecha) ?? 0) + Number(record.total ?? 0));
  });

  const out: Array<Record<string, unknown>> = [];
  for (let i = days - 1; i >= 0; i -= 1) {
    const date = dateMinusDays(new Date(`${todayIso}T00:00:00.000Z`), i);
    out.push({ fecha: date, litros: Number((buckets.get(date) ?? 0).toFixed(2)) });
  }

  return out;
}

dashboardRouter.use(requireAuth);

dashboardRouter.get("/summary", async (req, res) => {
  const uid = req.user?.uid;
  if (!uid) {
    return errorResponse(res, 401, "UNAUTHORIZED", "Usuario no autenticado.");
  }

  const safeList = async (loader: () => Promise<Array<Record<string, unknown>>>) => {
    try {
      return await loader();
    } catch (error) {
      console.error("Dashboard list error:", error);
      return [];
    }
  };

  try {
    const [vacas, eventosReproductivos, eventosVeterinarios, prodLeche] = await Promise.all([
      safeList(() => managedCollections.vacas.list(uid)),
      safeList(() => managedCollections.eventos_reproductivos.list(uid)),
      safeList(() => managedCollections.eventos_veterinarios.list(uid)),
      safeList(() => managedCollections.prod_leche.list(uid)),
    ]);

    const totalCabezas = vacas.length;

    const enProduccion = vacas.filter((vaca) => vaca.estado === "activa").length;

    const today = new Date();
    const hoyIso = today.toISOString().slice(0, 10);
    const todayStart = new Date(`${hoyIso}T00:00:00.000Z`);
    const alertLimit = new Date(todayStart);
    alertLimit.setUTCDate(alertLimit.getUTCDate() + 15);

    const vacasEnTratamiento = new Set<string>();
    const alertsRetiroActivo: Array<Record<string, unknown>> = [];
    eventosVeterinarios.forEach((evento) => {
      const vacaId = String(evento.vacaId ?? "");
      const fechaFinRetiro = String(evento.fechaFinRetiro ?? "").slice(0, 10);

      if (!vacaId) {
        return;
      }

      if (fechaFinRetiro && fechaFinRetiro >= hoyIso) {
        vacasEnTratamiento.add(vacaId);

        const vaca = vacas.find((item) => String(item.id ?? "") === vacaId);
        const targetDate = new Date(`${fechaFinRetiro}T00:00:00.000Z`);
        const diasRestantes = Number.isNaN(targetDate.getTime())
          ? 0
          : Math.max(0, Math.ceil((targetDate.getTime() - todayStart.getTime()) / millisPerDay));

        alertsRetiroActivo.push({
          vacaId,
          identificador: String(vaca?.identificador ?? vacaId),
          fechaFinRetiro,
          diasRestantes,
          producto: String(evento.producto ?? "-"),
        });
      }
    });

    const vacasPorId = new Map<string, Record<string, unknown>>();
    vacas.forEach((vaca) => {
      vacasPorId.set(String(vaca.id ?? ""), vaca);
    });

    const eventosPorVaca = new Map<string, Array<Record<string, unknown>>>();
    eventosReproductivos.forEach((evento) => {
      const vacaId = String(evento.vacaId ?? "").trim();
      if (!vacaId) {
        return;
      }
      const list = eventosPorVaca.get(vacaId) ?? [];
      list.push(evento);
      eventosPorVaca.set(vacaId, list);
    });

    const vacasGestantes = new Set<string>();
    const alertsProximoParto: Array<Record<string, unknown>> = [];
    const partosProyectados30: Array<Record<string, unknown>> = [];

    const millisPerDay = 1000 * 60 * 60 * 24;

    for (const [vacaId, eventos] of eventosPorVaca.entries()) {
      const ordered = [...eventos].sort((a, b) => String(a.fecha ?? "").localeCompare(String(b.fecha ?? "")));
      let fechaEstimadaParto: string | null = null;

      for (const evento of ordered) {
        const tipoEvento = String(evento.tipoEvento ?? "").toLowerCase();
        const fechaEvento = String(evento.fecha ?? "").slice(0, 10);

        if (tipoEvento === "servicio" || tipoEvento === "inseminacion") {
          const fromEvent = String(evento.fechaEstimadaParto ?? "").slice(0, 10);
          if (fromEvent) {
            fechaEstimadaParto = fromEvent;
          } else if (fechaEvento) {
            const baseDate = new Date(`${fechaEvento}T00:00:00.000Z`);
            if (!Number.isNaN(baseDate.getTime())) {
              baseDate.setUTCDate(baseDate.getUTCDate() + 283);
              fechaEstimadaParto = baseDate.toISOString().slice(0, 10);
            }
          }
        }

        if (tipoEvento === "diagnostico") {
          const resultado = String(evento.resultadoDiagnostico ?? "").toLowerCase();
          if (resultado === "negativo") {
            fechaEstimadaParto = null;
          }
        }

        if (tipoEvento === "aborto" || tipoEvento === "parto") {
          fechaEstimadaParto = null;
        }
      }

      if (!fechaEstimadaParto) {
        continue;
      }

      vacasGestantes.add(vacaId);

      const partoDate = new Date(`${fechaEstimadaParto}T00:00:00.000Z`);
      if (Number.isNaN(partoDate.getTime())) {
        continue;
      }

      if (partoDate >= todayStart && partoDate <= alertLimit) {
        const diasRestantes = Math.max(0, Math.ceil((partoDate.getTime() - todayStart.getTime()) / millisPerDay));
        const vaca = vacasPorId.get(vacaId);
        alertsProximoParto.push({
          vacaId,
          identificador: String(vaca?.identificador ?? vacaId),
          fechaEstimadaParto,
          diasRestantes,
        });
      }

      const limit30 = new Date(todayStart);
      limit30.setUTCDate(limit30.getUTCDate() + 30);
      if (partoDate >= todayStart && partoDate <= limit30) {
        const diasRestantes = Math.max(0, Math.ceil((partoDate.getTime() - todayStart.getTime()) / millisPerDay));
        const vaca = vacasPorId.get(vacaId);
        partosProyectados30.push({
          vacaId,
          identificador: String(vaca?.identificador ?? vacaId),
          fechaEstimadaParto,
          diasRestantes,
        });
      }
    }

    const totalLecheHoy = prodLeche
      .filter((registro) => String(registro.fecha ?? "").slice(0, 10) === hoyIso)
      .reduce((sum, registro) => sum + Number(registro.total ?? 0), 0);

    const startWeekIso = dateMinusDays(todayStart, 6);
    const startMonthIso = dateMinusDays(todayStart, 29);

    const totalLecheSemana = prodLeche
      .filter((registro) => {
        const fecha = String(registro.fecha ?? "").slice(0, 10);
        return fecha >= startWeekIso && fecha <= hoyIso;
      })
      .reduce((sum, registro) => sum + Number(registro.total ?? 0), 0);

    const totalLecheMes = prodLeche
      .filter((registro) => {
        const fecha = String(registro.fecha ?? "").slice(0, 10);
        return fecha >= startMonthIso && fecha <= hoyIso;
      })
      .reduce((sum, registro) => sum + Number(registro.total ?? 0), 0);

    const tendencia7Dias = aggregateTrend(prodLeche, 7, hoyIso);
    const tendencia30Dias = aggregateTrend(prodLeche, 30, hoyIso);

    const porEstado: Record<string, number> = {};
    const porRaza: Record<string, number> = {};
    const porSexo: Record<string, number> = {};
    vacas.forEach((vaca) => {
      const estado = String(vaca.estado ?? "sin-estado").toLowerCase();
      const raza = String(vaca.raza ?? "sin-raza").toLowerCase();
      const sexoRaw = String(vaca.sexo ?? "").toLowerCase();
      const sexo = sexoRaw === "m" ? "macho" : sexoRaw === "f" ? "hembra" : (sexoRaw || "sin-sexo");

      porEstado[estado] = (porEstado[estado] ?? 0) + 1;
      porRaza[raza] = (porRaza[raza] ?? 0) + 1;
      porSexo[sexo] = (porSexo[sexo] ?? 0) + 1;
    });

    const porAnimalMesMap = new Map<string, { litros: number; dias: Set<string>; identificador: string }>();
    prodLeche.forEach((record) => {
      const fecha = String(record.fecha ?? "").slice(0, 10);
      if (fecha < startMonthIso || fecha > hoyIso) {
        return;
      }

      const vacaId = String(record.vacaId ?? "");
      if (!vacaId) {
        return;
      }

      const vaca = vacasPorId.get(vacaId);
      const item = porAnimalMesMap.get(vacaId) ?? {
        litros: 0,
        dias: new Set<string>(),
        identificador: String(vaca?.identificador ?? vacaId),
      };
      item.litros += Number(record.total ?? 0);
      item.dias.add(fecha);
      porAnimalMesMap.set(vacaId, item);
    });

    const produccionPorAnimalMes = Array.from(porAnimalMesMap.entries())
      .map(([vacaId, item]) => ({
        vacaId,
        identificador: item.identificador,
        totalLitros: Number(item.litros.toFixed(2)),
        promedioDiarioMes: Number((item.litros / 30).toFixed(2)),
        promedioPorDiaConRegistro: Number((item.litros / Math.max(1, item.dias.size)).toFixed(2)),
      }))
      .sort((a, b) => b.promedioDiarioMes - a.promedioDiarioMes);

    alertsProximoParto.sort(
      (a, b) => Number(a.diasRestantes ?? 0) - Number(b.diasRestantes ?? 0),
    );
    partosProyectados30.sort(
      (a, b) => Number(a.diasRestantes ?? 0) - Number(b.diasRestantes ?? 0),
    );
    alertsRetiroActivo.sort(
      (a, b) => Number(a.diasRestantes ?? 0) - Number(b.diasRestantes ?? 0),
    );

    return successResponse(res, {
      totalCabezas,
      enProduccion,
      gestantes: vacasGestantes.size,
      enTratamiento: vacasEnTratamiento.size,
      totalLecheHoy,
      totalLecheSemana,
      totalLecheMes,
      tendencia7Dias,
      tendencia30Dias,
      alertsProximoParto,
      alertsRetiroActivo,
      partosProyectados30,
      inventoryReport: {
        totalAnimales: vacas.length,
        porEstado,
        porRaza,
        porSexo,
      },
      produccionPorAnimalMes,
    });
  } catch (error) {
    console.error("Dashboard summary error:", error);
    return errorResponse(res, 500, "DASHBOARD_SUMMARY_FAILED", "No se pudo calcular el resumen.");
  }
});
