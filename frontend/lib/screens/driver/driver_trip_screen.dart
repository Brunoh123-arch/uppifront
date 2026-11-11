import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/uppi_api_service.dart';
import '../../models/models.dart';

class DriverTripScreen extends StatefulWidget {
  final RideModel ride;
  final UserModel driver;

  const DriverTripScreen({
    super.key,
    required this.ride,
    required this.driver,
  });

  @override
  State<DriverTripScreen> createState() => _DriverTripScreenState();
}

class _DriverTripScreenState extends State<DriverTripScreen> {
  late String _currentStatus;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.ride.status;
  }

  Future<void> _advanceTrip() async {
    setState(() => _isLoading = true);

    try {
      if (_currentStatus == 'assigned') {
        final res = await UppiApiService.instance.driverAction(
          action: 'arrived',
          driverId: widget.driver.id,
          rideId: widget.ride.id,
        );
        if (mounted) {
          setState(() => _currentStatus = 'arrived');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Chegada confirmada!'),
              backgroundColor: AppTheme.primary,
            ),
          );
        }
      } else if (_currentStatus == 'arrived') {
        final res = await UppiApiService.instance.driverAction(
          action: 'start_trip',
          driverId: widget.driver.id,
          rideId: widget.ride.id,
        );
        if (mounted) {
          setState(() => _currentStatus = 'in_progress');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Viagem iniciada!'),
              backgroundColor: Colors.blueAccent,
            ),
          );
        }
      } else if (_currentStatus == 'in_progress') {
        final res = await UppiApiService.instance.driverAction(
          action: 'complete_trip',
          driverId: widget.driver.id,
          rideId: widget.ride.id,
          finalFare: widget.ride.estimatedFare,
        );

        if (!mounted) return;

        final double totalFare = (res['total_fare'] as num?)?.toDouble() ?? widget.ride.estimatedFare;
        final double driverEarnings = (res['driver_earnings'] as num?)?.toDouble() ?? (totalFare * 0.85);
        final double platformFee = (res['platform_fee'] as num?)?.toDouble() ?? (totalFare * 0.15);
        final double newBalance = (res['driver_new_wallet_balance'] as num?)?.toDouble() ?? 0.0;

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: const [
                Icon(Icons.check_circle, color: AppTheme.pixGreen, size: 28),
                SizedBox(width: 10),
                Text('Corrida Concluída!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryRow('Valor Total da Corrida:', 'R\$ ${totalFare.toStringAsFixed(2)}'),
                const SizedBox(height: 8),
                _buildSummaryRow('Taxa Uppi (15%):', '- R\$ ${platformFee.toStringAsFixed(2)}', color: AppTheme.accentRed),
                const Divider(color: Color(0xFF2D2D3A), height: 24),
                _buildSummaryRow('Seus Ganhos Líquidos (85%):', 'R\$ ${driverEarnings.toStringAsFixed(2)}', color: AppTheme.pixGreen, isBold: true),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Novo Saldo da Carteira:', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                      Text(
                        'R\$ ${newBalance.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textLight),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // fecha modal
                  Navigator.of(context).pop(); // volta para DriverHomeScreen
                },
                child: const Text('Concluir e Voltar'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildSummaryRow(String label, String value, {Color? color, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            color: color ?? AppTheme.textLight,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: isBold ? 16 : 14,
          ),
        ),
      ],
    );
  }

  String get _buttonText {
    switch (_currentStatus) {
      case 'assigned':
        return 'Cheguei ao Local de Embarque';
      case 'arrived':
        return 'Iniciar Viagem com Passageiro';
      case 'in_progress':
        return 'Finalizar Viagem e Receber 85%';
      default:
        return 'Avançar';
    }
  }

  Color get _buttonColor {
    switch (_currentStatus) {
      case 'assigned':
        return AppTheme.primary;
      case 'arrived':
        return Colors.blueAccent;
      case 'in_progress':
        return AppTheme.pixGreen;
      default:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Em Corrida: ${widget.ride.orderNumber}'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Mapa / Rota Visual
          Expanded(
            child: Container(
              color: const Color(0xFF16161E),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: _buttonColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: _buttonColor, width: 2),
                      ),
                      child: Center(
                        child: Icon(
                          _currentStatus == 'in_progress' ? Icons.navigation : Icons.directions_car,
                          size: 48,
                          color: _buttonColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _currentStatus == 'assigned'
                          ? 'A caminho do Passageiro'
                          : _currentStatus == 'arrived'
                              ? 'Aguardando Embarque'
                              : 'Em Deslocamento para o Destino',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _buttonColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Painel Inferior de Controle
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
                // Detalhes da Rota
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.trip_origin, color: AppTheme.primary, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.ride.originAddress,
                              style: const TextStyle(fontSize: 13, color: AppTheme.textLight),
                              overflow: TextOverflow.ellipsis,
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
                              widget.ride.destinationAddress,
                              style: const TextStyle(fontSize: 13, color: AppTheme.textLight),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Repasse Financeiro
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Seu Repasse Estimado (85%):', style: TextStyle(color: AppTheme.textMuted)),
                    Text(
                      'R\$ ${(widget.ride.estimatedFare * 0.85).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.pixGreen),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Botão de Avanço do Ciclo
                ElevatedButton(
                  onPressed: _isLoading ? null : _advanceTrip,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _buttonColor,
                    foregroundColor: _buttonColor == AppTheme.primary ? Colors.black : Colors.white,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.black)),
                        )
                      : Text(_buttonText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
