class DashboardSummary {
  const DashboardSummary({
    required this.totalCabezas,
    required this.enProduccion,
    required this.gestantes,
    required this.enTratamiento,
    required this.totalLecheHoy,
    required this.totalLecheSemana,
    required this.totalLecheMes,
    required this.tendencia7Dias,
    required this.tendencia30Dias,
    required this.alertsProximoParto,
    required this.alertsRetiroActivo,
    required this.partosProyectados30,
    required this.inventoryReport,
    required this.produccionPorAnimalMes,
  });

  final int totalCabezas;
  final int enProduccion;
  final int gestantes;
  final int enTratamiento;
  final double totalLecheHoy;
  final double totalLecheSemana;
  final double totalLecheMes;
  final List<TrendPoint> tendencia7Dias;
  final List<TrendPoint> tendencia30Dias;
  final List<PartoAlert> alertsProximoParto;
  final List<RetiroAlert> alertsRetiroActivo;
  final List<PartoAlert> partosProyectados30;
  final InventoryReport inventoryReport;
  final List<ProduccionAnimalMes> produccionPorAnimalMes;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      totalCabezas: _toInt(json['totalCabezas']),
      enProduccion: _toInt(json['enProduccion']),
      gestantes: _toInt(json['gestantes']),
      enTratamiento: _toInt(json['enTratamiento']),
      totalLecheHoy: _toDouble(json['totalLecheHoy']),
      totalLecheSemana: _toDouble(json['totalLecheSemana']),
      totalLecheMes: _toDouble(json['totalLecheMes']),
      tendencia7Dias: _toTrend(json['tendencia7Dias']),
      tendencia30Dias: _toTrend(json['tendencia30Dias']),
      alertsProximoParto: _toAlerts(json['alertsProximoParto']),
      alertsRetiroActivo: _toRetiroAlerts(json['alertsRetiroActivo']),
      partosProyectados30: _toAlerts(json['partosProyectados30']),
      inventoryReport: _toInventoryReport(json['inventoryReport']),
      produccionPorAnimalMes: _toProduccionPorAnimal(json['produccionPorAnimalMes']),
    );
  }

  static List<RetiroAlert> _toRetiroAlerts(Object? value) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => RetiroAlert(
            vacaId: item['vacaId']?.toString() ?? '',
            identificador: item['identificador']?.toString() ?? '-',
            fechaFinRetiro: item['fechaFinRetiro']?.toString() ?? '',
            diasRestantes: _toInt(item['diasRestantes']),
            producto: item['producto']?.toString() ?? '-',
          ),
        )
        .toList();
  }

  static InventoryReport _toInventoryReport(Object? value) {
    if (value is! Map<String, dynamic>) {
      return const InventoryReport(
        totalAnimales: 0,
        porEstado: {},
        porRaza: {},
        porSexo: {},
      );
    }

    Map<String, int> toMap(Object? raw) {
      if (raw is! Map<String, dynamic>) {
        return const {};
      }
      final out = <String, int>{};
      raw.forEach((k, v) {
        out[k] = _toInt(v);
      });
      return out;
    }

    return InventoryReport(
      totalAnimales: _toInt(value['totalAnimales']),
      porEstado: toMap(value['porEstado']),
      porRaza: toMap(value['porRaza']),
      porSexo: toMap(value['porSexo']),
    );
  }

  static List<ProduccionAnimalMes> _toProduccionPorAnimal(Object? value) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => ProduccionAnimalMes(
            vacaId: item['vacaId']?.toString() ?? '',
            identificador: item['identificador']?.toString() ?? '-',
            totalLitros: _toDouble(item['totalLitros']),
            promedioDiarioMes: _toDouble(item['promedioDiarioMes']),
            promedioPorDiaConRegistro: _toDouble(item['promedioPorDiaConRegistro']),
          ),
        )
        .toList();
  }

  static List<TrendPoint> _toTrend(Object? value) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => TrendPoint(
            fecha: item['fecha']?.toString() ?? '',
            litros: _toDouble(item['litros']),
          ),
        )
        .toList();
  }

  static List<PartoAlert> _toAlerts(Object? value) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => PartoAlert(
            vacaId: item['vacaId']?.toString() ?? '',
            identificador: item['identificador']?.toString() ?? '-',
            fechaEstimadaParto: item['fechaEstimadaParto']?.toString() ?? '',
            diasRestantes: _toInt(item['diasRestantes']),
          ),
        )
        .toList();
  }

  static int _toInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _toDouble(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class TrendPoint {
  const TrendPoint({required this.fecha, required this.litros});

  final String fecha;
  final double litros;
}

class PartoAlert {
  const PartoAlert({
    required this.vacaId,
    required this.identificador,
    required this.fechaEstimadaParto,
    required this.diasRestantes,
  });

  final String vacaId;
  final String identificador;
  final String fechaEstimadaParto;
  final int diasRestantes;
}

class RetiroAlert {
  const RetiroAlert({
    required this.vacaId,
    required this.identificador,
    required this.fechaFinRetiro,
    required this.diasRestantes,
    required this.producto,
  });

  final String vacaId;
  final String identificador;
  final String fechaFinRetiro;
  final int diasRestantes;
  final String producto;
}

class InventoryReport {
  const InventoryReport({
    required this.totalAnimales,
    required this.porEstado,
    required this.porRaza,
    required this.porSexo,
  });

  final int totalAnimales;
  final Map<String, int> porEstado;
  final Map<String, int> porRaza;
  final Map<String, int> porSexo;
}

class ProduccionAnimalMes {
  const ProduccionAnimalMes({
    required this.vacaId,
    required this.identificador,
    required this.totalLitros,
    required this.promedioDiarioMes,
    required this.promedioPorDiaConRegistro,
  });

  final String vacaId;
  final String identificador;
  final double totalLitros;
  final double promedioDiarioMes;
  final double promedioPorDiaConRegistro;
}
