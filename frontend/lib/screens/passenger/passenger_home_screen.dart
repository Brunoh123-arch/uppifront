import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/uppi_api_service.dart';
import '../../models/models.dart';
import 'pix_payment_modal.dart';
import 'ride_tracking_screen.dart';
import '../auth_screen.dart';

class PassengerHomeScreen extends StatefulWidget {
  final UserModel user;

  const PassengerHomeScreen({super.key, required this.user});

  @override
  State<PassengerHomeScreen> createState() => _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends State<PassengerHomeScreen> {
  final _originController = TextEditingController(text: 'Av. Paulista, 1000 - Bela Vista');
  final _destController = TextEditingController(text: 'Aeroporto de Congonhas - SP');

  final double _originLat = -23.5615;
  final double _originLon = -46.6559;
  final double _destLat = -23.6273;
  final double _destLon = -46.6565;

  List<TariffOption> _tariffs = [];
  String _selectedCategory = 'pop';
  bool _isLoadingEstimates = true;
  bool _isRequestingRide = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchTariffs();
  }

  Future<void> _fetchTariffs() async {
    setState(() {
      _isLoadingEstimates = true;
      _error = null;
    });

    try {
      final estimates = await UppiApiService.instance.getEstimates(
        originLat: _originLat,
        originLon: _originLon,
        destLat: _destLat,
        destLon: _destLon,
      );
      if (mounted) {
        setState(() {
          _tariffs = estimates;
          _isLoadingEstimates = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao carregar orçamentos: $e';
          _isLoadingEstimates = false;
        });
      }
    }
  }

  Future<void> _handleRequestRide() async {
    setState(() => _isRequestingRide = true);

    try {
      final selectedTariff = _tariffs.firstWhere(
        (t) => t.category == _selectedCategory,
        orElse: () => _tariffs.first,
      );

      final ride = await UppiApiService.instance.requestRide(
        riderId: widget.user.id,
        category: _selectedCategory,
        originAddress: _originController.text,
        originLat: _originLat,
        originLon: _originLon,
        destAddress: _destController.text,
        destLat: _destLat,
        destLon: _destLon,
        estimatedFare: selectedTariff.price,
      );

      if (!mounted) return;

      // Abre Modal do Pix
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => PixPaymentModal(
          ride: ride,
          onPaymentConfirmed: () {
            Navigator.of(context).pop(); // fecha modal pix
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RideTrackingScreen(
                  initialRide: ride,
                  user: widget.user,
                ),
              ),
            );
          },
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falha ao pedir corrida: $e'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isRequestingRide = false);
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'pop':
        return Icons.directions_car;
      case 'comfort':
        return Icons.airline_seat_recline_extra;
      case 'moto':
        return Icons.two_wheeler;
      case 'entrega':
        return Icons.inventory_2_outlined;
      default:
        return Icons.directions_car;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UPPI BRASIL'),
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
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                widget.user.fullName.split(' ').first,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header com Endereços de Origem e Destino
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _originController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.my_location, color: AppTheme.primary),
                    labelText: 'Ponto de Partida',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _destController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.location_on, color: AppTheme.accentRed),
                    labelText: 'Para onde vamos?',
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),

          // Seletor de Categorias
          Expanded(
            child: _isLoadingEstimates
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  )
                : _error != null
                    ? Center(
                        child: Text(_error!, style: const TextStyle(color: AppTheme.accentRed)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _tariffs.length,
                        itemBuilder: (context, index) {
                          final tariff = _tariffs[index];
                          final isSelected = tariff.category == _selectedCategory;

                          return GestureDetector(
                            onTap: () => setState(() => _selectedCategory = tariff.category),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primary.withValues(alpha: 0.12)
                                    : AppTheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primary
                                      : const Color(0xFF2D2D3A),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppTheme.primary
                                          : AppTheme.surfaceElevated,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      _getCategoryIcon(tariff.category),
                                      color: isSelected ? Colors.black : AppTheme.textLight,
                                      size: 26,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tariff.name,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textLight,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${tariff.etaText} • ${tariff.description}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    tariff.formattedPrice,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? AppTheme.primary : AppTheme.textLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Rodapé com Botão Pedir e Método Pix
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.pix, color: AppTheme.pixGreen, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Pagamento via Pix Direto',
                          style: TextStyle(
                            color: AppTheme.pixGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      'Sem maquininha',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isRequestingRide ? null : _handleRequestRide,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: _isRequestingRide
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        )
                      : const Text('Confirmar e Pagar com Pix'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
