import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/uppi_api_service.dart';
import '../../models/models.dart';

class RideTrackingScreen extends StatefulWidget {
  final RideModel initialRide;
  final UserModel user;

  const RideTrackingScreen({
    super.key,
    required this.initialRide,
    required this.user,
  });

  @override
  State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen> {
  late RideModel _ride;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _ride = widget.initialRide;
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final updated = await UppiApiService.instance.getRideState(_ride.id);
        if (mounted) {
          setState(() => _ride = updated);
          if (updated.status == 'completed') {
            _pollingTimer?.cancel();
          }
        }
      } catch (_) {}
    });
  }

  String get _statusTitle {
    switch (_ride.status) {
      case 'searching':
        return 'Procurando motoristas Uppi...';
      case 'assigned':
        return 'Motorista a caminho!';
      case 'arrived':
        return 'Motorista chegou ao local!';
      case 'in_progress':
        return 'Viagem em andamento';
      case 'completed':
        return 'Viagem Concluída!';
      case 'cancelled':
        return 'Corrida cancelada';
      default:
        return 'Processando...';
    }
  }

  String get _statusSubtitle {
    switch (_ride.status) {
      case 'searching':
        return 'Notificando motoristas parceiros próximos em São Paulo';
      case 'assigned':
        return 'O motorista parceiro está se deslocando até seu endereço';
      case 'arrived':
        return 'Seu motorista está aguardando no ponto de embarque';
      case 'in_progress':
        return 'A caminho de ${_ride.destinationAddress}';
      case 'completed':
        return 'Obrigado por utilizar a Uppi. Tenha um ótimo dia!';
      case 'cancelled':
        return 'Esta corrida foi cancelada.';
      default:
        return '';
    }
  }

  Color get _statusColor {
    switch (_ride.status) {
      case 'searching':
        return AppTheme.primary;
      case 'assigned':
      case 'arrived':
        return Colors.orangeAccent;
      case 'in_progress':
        return Colors.blueAccent;
      case 'completed':
        return AppTheme.pixGreen;
      default:
        return AppTheme.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pedido ${_ride.orderNumber}'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.emergency, color: AppTheme.accentRed),
            tooltip: 'Emergência (190 / 192)',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Central de Emergência Uppi: Polícia 190 | SAMU 192'),
                  backgroundColor: AppTheme.accentRed,
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Simulação Visual do Mapa / Radar
          Expanded(
            child: Stack(
              children: [
                Container(
                  color: const Color(0xFF16161E),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _statusColor.withValues(alpha: 0.1),
                            border: Border.all(color: _statusColor, width: 2),
                          ),
                          child: Center(
                            child: Icon(
                              _ride.status == 'completed'
                                  ? Icons.check_circle
                                  : Icons.directions_car,
                              size: 54,
                              color: _statusColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _statusTitle,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _statusColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            _statusSubtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Card Superior de Origem/Destino
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF2D2D3A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.trip_origin, color: AppTheme.primary, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _ride.originAddress,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, color: AppTheme.textLight),
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.only(left: 7),
                          child: SizedBox(
                            height: 12,
                            child: VerticalDivider(color: AppTheme.textMuted, thickness: 1),
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: AppTheme.accentRed, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _ride.destinationAddress,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, color: AppTheme.textLight),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Painel Inferior com Dados do Motorista / Veículo
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: Color(0xFF2D2D3A))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_ride.driverName != null) ...[
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: AppTheme.primary,
                        child: const Icon(Icons.person, color: Colors.black, size: 30),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _ride.driverName!,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textLight,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_ride.vehicleModel ?? "Carro Uppi"} • Placa ${_ride.vehiclePlate ?? "Mercosul"}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.star, color: AppTheme.primary, size: 16),
                            SizedBox(width: 4),
                            Text(
                              '4.9',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF2D2D3A), height: 28),
                ],

                // Resumo Financeiro
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Valor da Corrida',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        ),
                        Text(
                          'R\$ ${_ride.estimatedFare.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textLight,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.pixGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.pix, color: AppTheme.pixGreen, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Pix Pago',
                            style: TextStyle(
                              color: AppTheme.pixGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (_ride.status == 'completed')
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: const Text('Voltar para Início'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
