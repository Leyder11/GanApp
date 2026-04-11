import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class CowGpsPage extends StatefulWidget {
  const CowGpsPage({
    super.key,
    required this.cowId,
    required this.cowLabel,
  });

  final String cowId;
  final String cowLabel;

  @override
  State<CowGpsPage> createState() => _CowGpsPageState();
}

class _CowGpsPageState extends State<CowGpsPage> {
  final MapController _mapController = MapController();
  bool _loading = true;
  bool _isTracking = false;
  bool _followMap = true;
  String? _error;
  LatLng? _phonePosition;
  LatLng? _cowPosition;
  DateTime? _lastUpdate;
  StreamSubscription<Position>? _positionSub;

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  Future<void> _startTracking() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Activa el GPS del celular para ver el mapa.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('No hay permisos de ubicacion.');
      }

      await _positionSub?.cancel();

      final stream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 4,
        ),
      );

      _positionSub = stream.listen(
        (position) {
          final phone = LatLng(position.latitude, position.longitude);
          final cow = _simulateCowPosition(base: phone, seed: widget.cowId);

          if (!mounted) {
            return;
          }

          setState(() {
            _phonePosition = phone;
            _cowPosition = cow;
            _error = null;
            _lastUpdate = DateTime.now();
          });

          if (!_loading && _followMap) {
            _mapController.move(
              LatLng(
                (phone.latitude + cow.latitude) / 2,
                (phone.longitude + cow.longitude) / 2,
              ),
              _initialZoom(phone, cow),
            );
          }
        },
        onError: (Object _) {
          if (!mounted) {
            return;
          }
          setState(() {
            _error = 'No se pudo actualizar la ubicacion en tiempo real.';
          });
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isTracking = true;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _pauseTracking() async {
    await _positionSub?.cancel();
    if (!mounted) {
      return;
    }
    setState(() {
      _positionSub = null;
      _isTracking = false;
    });
  }

  LatLng _simulateCowPosition({required LatLng base, required String seed}) {
    final hash = seed.codeUnits.fold<int>(0, (acc, c) => (acc * 31 + c) & 0x7fffffff);

    final latDirection = (hash % 2 == 0) ? 1.0 : -1.0;
    final lngDirection = ((hash ~/ 2) % 2 == 0) ? 1.0 : -1.0;

    // Between ~120m and ~900m away from phone position.
    final latOffset = (0.001 + ((hash % 80) / 10000)) * latDirection;
    final lngOffset = (0.001 + (((hash ~/ 7) % 80) / 10000)) * lngDirection;

    final simulatedLat = (base.latitude + latOffset).clamp(-85.0, 85.0);

    final maxLng = 180.0;
    final minLng = -180.0;
    var simulatedLng = base.longitude + lngOffset;
    if (simulatedLng > maxLng) {
      simulatedLng = maxLng;
    }
    if (simulatedLng < minLng) {
      simulatedLng = minLng;
    }

    return LatLng(simulatedLat, simulatedLng);
  }

  String _distanceLabel() {
    if (_phonePosition == null || _cowPosition == null) {
      return '-';
    }

    final distance = Geolocator.distanceBetween(
      _phonePosition!.latitude,
      _phonePosition!.longitude,
      _cowPosition!.latitude,
      _cowPosition!.longitude,
    );

    if (distance >= 1000) {
      return '${(distance / 1000).toStringAsFixed(2)} km';
    }

    return '${distance.round()} m';
  }

  @override
  Widget build(BuildContext context) {
    final phone = _phonePosition;
    final cow = _cowPosition;

    return Scaffold(
      appBar: AppBar(
        title: Text('GPS ${widget.cowLabel}'),
        actions: [
          TextButton.icon(
            onPressed: _isTracking ? _pauseTracking : _startTracking,
            icon: Icon(
              _isTracking ? Icons.pause_circle_outline : Icons.play_circle_outline,
            ),
            label: Text(_isTracking ? 'Pausar' : 'Reanudar'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _startTracking,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          : phone == null || cow == null
          ? const Center(child: Text('No se pudo obtener ubicacion.'))
          : Column(
              children: [
                Expanded(
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(
                        (phone.latitude + cow.latitude) / 2,
                        (phone.longitude + cow.longitude) / 2,
                      ),
                      initialZoom: _initialZoom(phone, cow),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.flutter_application_1',
                      ),
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [phone, cow],
                            color: Colors.blueAccent.withValues(alpha: 0.7),
                            strokeWidth: 4,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: phone,
                            width: 120,
                            height: 70,
                            child: const _MapPin(
                              icon: Icons.person_pin_circle,
                              color: Colors.blue,
                              label: 'Tu posicion',
                            ),
                          ),
                          Marker(
                            point: cow,
                            width: 120,
                            height: 70,
                            child: _MapPin(
                              icon: Icons.pets,
                              color: Colors.green,
                              label: widget.cowLabel,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Distancia estimada: ${_distanceLabel()}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_lastUpdate != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Ultima actualizacion: '
                          '${_lastUpdate!.hour.toString().padLeft(2, '0')}:'
                          '${_lastUpdate!.minute.toString().padLeft(2, '0')}:'
                          '${_lastUpdate!.second.toString().padLeft(2, '0')}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 6),
                      const Text(
                        'La posicion de la vaca esta simulada cerca de tu GPS para demo.',
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Seguir mapa automaticamente'),
                        subtitle: const Text(
                          'Si lo desactivas, puedes mover/zoom sin recentrado automatico.',
                        ),
                        value: _followMap,
                        onChanged: (value) {
                          setState(() {
                            _followMap = value;
                          });

                          if (!value || _phonePosition == null || _cowPosition == null) {
                            return;
                          }

                          _mapController.move(
                            LatLng(
                              (_phonePosition!.latitude + _cowPosition!.latitude) / 2,
                              (_phonePosition!.longitude + _cowPosition!.longitude) / 2,
                            ),
                            _initialZoom(_phonePosition!, _cowPosition!),
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isTracking
                            ? 'Seguimiento en tiempo real activo.'
                            : 'Seguimiento pausado.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isTracking ? _pauseTracking : _startTracking,
        icon: Icon(_isTracking ? Icons.pause : Icons.my_location),
        label: Text(_isTracking ? 'Pausar GPS' : 'Activar GPS'),
      ),
    );
  }

  double _initialZoom(LatLng a, LatLng b) {
    final dLat = (a.latitude - b.latitude).abs();
    final dLng = (a.longitude - b.longitude).abs();
    final maxDelta = math.max(dLat, dLng);

    if (maxDelta < 0.002) {
      return 16.5;
    }
    if (maxDelta < 0.005) {
      return 15.5;
    }
    if (maxDelta < 0.01) {
      return 14.5;
    }
    return 13.5;
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 34),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 5,
              ),
            ],
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
