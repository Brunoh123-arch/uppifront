import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/uppi_api_service.dart';
import '../../models/models.dart';
import 'driver_trip_screen.dart';
import 'driver_wallet_screen.dart';
import '../auth_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  final UserModel driver;

  const DriverHomeScreen({super.key, required this.driver});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  late UserModel _currentDriver;
  bool _isOnline = false;
  Timer? _gpsTimer;
  Timer? _rideRadarTimer;

  final double _lat = -23.5505;
  final double _lon = -46.6333;

  @override
  void initState() {
    super.initState();
    _currentDriver = widget.driver;
  }

  @override
  void dispose() {
    _gpsTimer?.cancel();
    _rideRadarTimer?.cancel();
    super.dispose();
  }

  void _toggleOnline(bool value) async {
    setState(() => _isOnline = value);

    if (value) {
      // 1. Atualizar GPS imediatamente e periodicamente
      await _sendGpsUpdate();
      _gpsTimer = Timer.periodic(const Duration(seconds: 5), (_) => _sendGpsUpdate());
      _startRideRadar();
    } else {
      _gpsTimer?.cancel();
      _rideRadarTimer?.cancel();
    }
  }

  Future<void> _sendGpsUpdate() async {
    try {
      await UppiApiService.instance.updateDriverLocation(
        driverId: _currentDriver.id,
        lat: _lat,
        lon: _lon,
        bearing: 90.0,
        speed: 25.0,
      );
    } catch (_) {}
  }

  void _startRideRadar() {
    _rideRadarTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      // O radar verifica se há corridas recentes para atender
    });
  }

  Future<void> _handleAcceptRide(RideModel ride) async {
    try {
      await UppiApiService.instance.driverAction(
        action: 'accept_ride',
        driverId: _currentDriver.id,
        rideId: ride.id,
      );

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DriverTripScreen(
            ride: ride,
            driver: _currentDriver,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível aceitar: $e'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
    }
  }

  // Modal para simulação de chamada de corrida no radar
  void _simulateIncomingRide() {
    final mockRide = RideModel(
      id: 'mock-ride-${DateTime.now().millisecondsSinceEpoch}',
      orderNumber: 'UPPI-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      riderId: 'mock-rider-id',
      category: 'pop',
      originAddress: 'Av. Paulista, 1000 - Bela Vista',
      destinationAddress: 'Aeroporto de Congonhas - SP',
      status: 'assigned',
      paymentMethod: 'pix',
      paymentStatus: 'paid',
      estimatedFare: 32.48,
    );

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'NOVA CORRIDA',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  mockRide.orderNumber,
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'R\$ ${(mockRide.estimatedFare * 0.85).toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: AppTheme.pixGreen,
              ),
            ),
            const Text(
              'Seus ganhos líquidos (85% repasse via Pix)',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.trip_origin, color: AppTheme.primary, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          mockRide.originAddress,
                          style: const TextStyle(fontSize: 13, color: AppTheme.textLight),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: AppTheme.accentRed, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          mockRide.destinationAddress,
                          style: const TextStyle(fontSize: 13, color: AppTheme.textLight),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppTheme.accentRed),
                    ),
                    child: const Text('Recusar', style: TextStyle(color: AppTheme.accentRed)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _handleAcceptRide(mockRide);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Aceitar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CENTRAL DO MOTORISTA'),
        leading: IconButton(
          icon: const Icon(Icons.logout, color: AppTheme.textMuted),
          tooltip: 'Trocar Perfil',
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const AuthScreen()),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet, color: AppTheme.pixGreen),
            tooltip: 'Carteira Pix',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DriverWalletScreen(driver: _currentDriver),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner de Status Online/Offline
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            color: _isOnline
                ? AppTheme.pixGreen.withValues(alpha: 0.15)
                : AppTheme.surfaceElevated,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isOnline ? AppTheme.pixGreen : AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isOnline ? 'VOCÊ ESTÁ ONLINE' : 'VOCÊ ESTÁ OFFLINE',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _isOnline ? AppTheme.pixGreen : AppTheme.textMuted,
                          ),
                        ),
                        Text(
                          _isOnline ? 'GPS Ativo • Pronto para receber chamadas' : 'Ative para receber corridas',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
                Switch(
                  value: _isOnline,
                  onChanged: _toggleOnline,
                  activeThumbColor: AppTheme.pixGreen,
                ),
              ],
            ),
          ),

          // Área Central do Radar
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isOnline
                          ? AppTheme.primary.withValues(alpha: 0.15)
                          : AppTheme.surfaceElevated,
                      border: Border.all(
                        color: _isOnline ? AppTheme.primary : const Color(0xFF2D2D3A),
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        _isOnline ? Icons.radar : Icons.power_settings_new,
                        size: 60,
                        color: _isOnline ? AppTheme.primary : AppTheme.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isOnline
                        ? 'Radar Uppi Ativo'
                        : 'Você está Offline',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _isOnline ? AppTheme.primary : AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      _isOnline
                          ? 'Aguardando chamadas de passageiros próximos na região metropolitana de São Paulo.'
                          : 'Toque na chave superior para ficar disponível no mapa.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 28),

                  if (_isOnline)
                    ElevatedButton.icon(
                      onPressed: _simulateIncomingRide,
                      icon: const Icon(Icons.bolt, color: Colors.black),
                      label: const Text('Simular Chamada de Corrida'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.black,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Rodapé com Resumo de Faturamento
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: Color(0xFF2D2D3A))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Saldo na Carteira Uppi', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    Text(
                      'R\$ ${_currentDriver.walletBalance.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => DriverWalletScreen(driver: _currentDriver)),
                    );
                  },
                  icon: const Icon(Icons.pix, color: AppTheme.pixGreen, size: 18),
                  label: const Text('Ver Extrato', style: TextStyle(color: AppTheme.pixGreen)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.pixGreen)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
