// ignore_for_file: unused_import, unused_field

import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';
import 'package:energyflow/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:universal_html/html.dart' as html;
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'login_page.dart';
import 'about_page.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

final _supabase = Supabase.instance.client;

class _MainDashboardState extends State<MainDashboard> {
  double? _potencia;
  String? _userDeviceId;
  final List<(FlSpot, DateTime)> _dataPoints = [];
  final int _limitCount = 50;
  double? _currentHourConsumption;
  double? _currentWeekConsumption;
  double? _previousWeekConsumption;


  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    _getData();
    _getEnergyConsumption();
    _getUserDeviceId();
  }

  Future<void> _getUserDeviceId() async {
  try {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Usuario no autenticado');
    }
    
    final response = await _supabase
      .from('devices')
      .select('device_id')
      .eq('user_id', userId)
      .single();
    
    setState(() {
      _userDeviceId = response['device_id'] as String?;
    });

    if (_userDeviceId != null) {
      _getData();
      _getEnergyConsumption();
    }
  } catch (error) {
    if (mounted) {
      context.showSnackBar('Error al obtener el device_id: $error', isError: true);
    }
  }
}

  Future<void> _getData() async {
    try {
      final data = await _supabase
          .from('medidas')
          .select('potencia, created_at')
          .eq('device_id', _userDeviceId.toString())
          .order('created_at', ascending: false)
          .limit(25);

      if (data.isNotEmpty) {
        final dataPoints = data as List<dynamic>;
        setState(() {
          _dataPoints.clear();
          for (int i = dataPoints.length - 1; i >= 0; i--) {
            final potencia = (dataPoints[i]['potencia'] as num).toDouble();
            final createdAt =
                DateTime.parse(dataPoints[i]['created_at'] as String);
            _dataPoints.add(
                (FlSpot(_dataPoints.length.toDouble(), potencia), createdAt));
          }
        });
      }

      final channel = _supabase.channel('public:medidas');

      channel
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'medidas',
            filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'device_id', value: _userDeviceId),
            callback: (payload) {
              final newRecord = payload.newRecord;
              if (newRecord != null && newRecord['potencia'] != null) {
                final potencia = (newRecord['potencia'] as num).toDouble();
                setState(() {
                  _potencia = potencia;
                  _updatePotenciaPoints(potencia);
                });
              }
            },
          )
          .subscribe();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al obtener datos: $error')),
        );
      }
    }
  }

  void _updatePotenciaPoints(double potencia) {
    if (_dataPoints.length >= _limitCount) {
      _dataPoints.removeAt(0);
    }
    final xValue = _dataPoints.isNotEmpty ? _dataPoints.last.$1.x + 1 : 0.0;
    final adjustedTime = DateTime.now().subtract(const Duration(hours: 5));
    _dataPoints.add((FlSpot(xValue, potencia), adjustedTime));
  }

  Future<void> _getEnergyConsumption() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final results = await Future.wait([
        _fetchConsumption('last_hour', 'Consumo de la última hora'),
        _fetchConsumption('current_week', 'Consumo de la semana actual'),
        _fetchConsumption('last_week', 'Consumo de la semana anterior'),
      ]);

      setState(() {
        _currentHourConsumption = _formatConsumption(results[0]);
        _currentWeekConsumption = _formatConsumption(results[1]);
        _previousWeekConsumption = _formatConsumption(results[2]);
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al obtener el consumo energético: $error')),
        );
      }
    }
  }

  Future<double?> _fetchConsumption(String timeCase, String description) async {
    final result = await _supabase.rpc(
      'calculate_energy_consumption',
      params: {
        'p_case': timeCase,
        'p_column_name': 'potencia',
        'p_user_id': _supabase.auth.currentUser!.id,
      },
    );

    return result as double?;
  }

  double? _formatConsumption(double? value, {int decimals = 2}) {
    if (value == null) return null;
    return double.parse(value.toStringAsFixed(decimals));
  }

  Future<void> _signOut() async {
    await _supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      drawer: _buildDrawer(),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: <Widget>[
              Image.asset(
                'assets/images/energyflow.png',
                width: MediaQuery.of(context).size.width * 0.8,
                height: 200,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 10),
              _buildChart(),
              const SizedBox(height: 20),
              _buildInfoCard(_buildConsumptionCardContent()),
              const SizedBox(height: 20),
              _buildInfoCard(_buildComparisonCardContent()),
              const SizedBox(height: 20),
              _buildInfoCard(_buildWeeklyConsumptionCardContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: const Text(
              'Menu',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.analytics),
            title: const Text('Dashboard Principal'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Acerca de la aplicación'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AboutPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            onTap: _signOut,
          ),
        ],
      ),
    );
  }

  Future<void> _refreshData() async {
    await _getData();
    await _getEnergyConsumption();
  }

  Widget _buildChart() {
    if (_dataPoints.isEmpty) return Container();

    final lastReading = _dataPoints.last.$1.y.toStringAsFixed(2);
    final lastReadingTime = DateFormat('HH:mm:ss').format(_dataPoints.last.$2);

    final minY = _dataPoints.map((e) => e.$1.y).reduce(math.min);
    final maxY = _dataPoints.map((e) => e.$1.y).reduce(math.max);
    final yRange = maxY - minY;

    // Calculamos el rango extendido para X
    final xRange = _dataPoints.length - 1;
    final extendedXMin = -xRange * 0.05; // 5% extra al inicio
    final extendedXMax = xRange * 1.05; // 5% extra al final

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Consumo Energético en Tiempo Real',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Última lectura: $lastReading W a las $lastReadingTime',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0, bottom: 8.0),
                child: LineChart(
                  LineChartData(
                    minY: math.max(
                        0,
                        minY -
                            (yRange * 0.2)), // Aseguramos que no sea negativo
                    maxY: maxY + (yRange * 0.2),
                    minX: extendedXMin,
                    maxX: extendedXMax,
                    lineTouchData: _buildLineTouchData(),
                    gridData: _buildGridData(),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: Colors.grey[300]!, width: 1),
                    ),
                    lineBarsData: [_buildLineChartBarData()],
                    titlesData: _buildTitlesData(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  LineTouchData _buildLineTouchData() {
    return LineTouchData(
      handleBuiltInTouches: true,
      touchTooltipData: LineTouchTooltipData(
        tooltipRoundedRadius: 8,
        getTooltipItems: (touchedSpots) {
          return touchedSpots.map((LineBarSpot spot) {
            final data = _dataPoints[spot.spotIndex];
            return LineTooltipItem(
              '${data.$1.y.toStringAsFixed(2)} W\n${DateFormat('HH:mm:ss').format(data.$2)}',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            );
          }).toList();
        },
      ),
    );
  }

  FlGridData _buildGridData() {
    return FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: 50,
      getDrawingHorizontalLine: (value) {
        return FlLine(
          color: Colors.grey[300],
          strokeWidth: 1,
          dashArray: [5, 5],
        );
      },
    );
  }

  LineChartBarData _buildLineChartBarData() {
    return LineChartBarData(
      spots: _dataPoints.map((e) => e.$1).toList(),
      isCurved: true,
      color: Colors.blue,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: false,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 3,
            color: Colors.blue,
            strokeWidth: 1,
            strokeColor: Colors.white,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        color: Colors.blue.withOpacity(0.1),
      ),
    );
  }

  FlTitlesData _buildTitlesData() {
    final minY = _dataPoints.map((e) => e.$1.y).reduce(math.min);
    final maxY = _dataPoints.map((e) => e.$1.y).reduce(math.max);
    // ignore: unused_local_variable
    final interval = (maxY - minY) / 4; // Dividimos el rango en 5 partes

    return FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          interval: (_dataPoints.length / 4).floor().toDouble(),
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (index >= 0 && index < _dataPoints.length) {
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  DateFormat('HH:mm').format(_dataPoints[index].$2),
                  style: const TextStyle(fontSize: 10),
                ),
              );
            }
            return const Text('');
          },
        ),
      ),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          interval: (_dataPoints.length / 3).floor().toDouble(),
          getTitlesWidget: (value, meta) {
            return Text(
              '${value.toInt()} W',
              style: const TextStyle(fontSize: 10),
            );
          },
        ),
      ),
    );
  }

  Widget _buildConsumptionCardContent() {
    return Column(
      children: [
        const Icon(Icons.electric_bolt, size: 48, color: Colors.blue),
        const SizedBox(height: 8),
        const Text(
          'Consumo Energético Actual',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _currentHourConsumption != null
              ? '${_currentHourConsumption!.toStringAsFixed(2)} kWh'
              : 'Cargando...',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const Text('(Última hora)', style: TextStyle(fontSize: 14)),
      ],
    );
  }

  Widget _buildComparisonCardContent() {
    final difference =
        (_currentWeekConsumption ?? 0) - (_previousWeekConsumption ?? 0);
    final percentChange =
        _previousWeekConsumption != null && _previousWeekConsumption! != 0
            ? (difference / _previousWeekConsumption!) * 100
            : 0;

    return Column(
      children: [
        const Icon(Icons.compare_arrows, size: 48, color: Colors.green),
        const SizedBox(height: 8),
        const Text(
          'Comparación con Semana Anterior',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          percentChange.abs() > 0.01
              ? '${percentChange > 0 ? '+' : ''}${percentChange.toStringAsFixed(2)}%'
              : 'Sin cambios',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: percentChange > 0 ? Colors.red : Colors.green,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Consumo actual: ${_currentWeekConsumption?.toStringAsFixed(2) ?? 'N/A'} kWh\n'
          'Consumo anterior: ${_previousWeekConsumption?.toStringAsFixed(2) ?? 'N/A'} kWh',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildWeeklyConsumptionCardContent() {
    return Column(
      children: [
        const Icon(Icons.calendar_today, size: 48, color: Colors.orange),
        const SizedBox(height: 8),
        const Text(
          'Consumo Semanal',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _currentWeekConsumption != null
              ? '${_currentWeekConsumption!.toStringAsFixed(2)} kWh'
              : 'Cargando...',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildInfoCard(Widget child) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: child,
      ),
    );
  }
}
