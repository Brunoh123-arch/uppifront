import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/uppi_api_service.dart';
import '../../models/models.dart';

class PixPaymentModal extends StatefulWidget {
  final RideModel ride;
  final VoidCallback onPaymentConfirmed;

  const PixPaymentModal({
    super.key,
    required this.ride,
    required this.onPaymentConfirmed,
  });

  @override
  State<PixPaymentModal> createState() => _PixPaymentModalState();
}

class _PixPaymentModalState extends State<PixPaymentModal> {
  Timer? _pollingTimer;
  bool _isPaid = false;
  bool _isSimulating = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final state = await UppiApiService.instance.getRideState(widget.ride.id);
        if (state.paymentStatus == 'paid' || state.status != 'searching') {
          timer.cancel();
          if (mounted) {
            setState(() => _isPaid = true);
            await Future.delayed(const Duration(milliseconds: 800));
            widget.onPaymentConfirmed();
          }
        }
      } catch (_) {}
    });
  }

  Future<void> _simulateWebhook() async {
    setState(() => _isSimulating = true);
    try {
      await UppiApiService.instance.simulatePixConfirmation(
        rideId: widget.ride.id,
        amount: widget.ride.estimatedFare,
      );
      if (mounted) {
        setState(() => _isPaid = true);
        await Future.delayed(const Duration(milliseconds: 600));
        widget.onPaymentConfirmed();
      }
    } finally {
      if (mounted) setState(() => _isSimulating = false);
    }
  }

  void _copyPixCode() {
    if (widget.ride.pixCopyPaste != null) {
      Clipboard.setData(ClipboardData(text: widget.ride.pixCopyPaste!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Código Pix Copia e Cola copiado para a área de transferência!'),
          backgroundColor: AppTheme.pixGreen,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pixCode = widget.ride.pixCopyPaste ?? '00020126580014br.gov.bcb.pix0136uppi@uppi.com.br';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.pix, color: AppTheme.pixGreen, size: 28),
              SizedBox(width: 8),
              Text(
                'Pagar com Pix',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Pedido ${widget.ride.orderNumber} • R\$ ${widget.ride.estimatedFare.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 20),

          // QR Code Pix
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: QrImageView(
              data: pixCode,
              version: QrVersions.auto,
              size: 190.0,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Botão Copiar Pix
          OutlinedButton.icon(
            onPressed: _copyPixCode,
            icon: const Icon(Icons.copy, color: AppTheme.pixGreen),
            label: const Text(
              'Copiar Código Pix',
              style: TextStyle(
                color: AppTheme.pixGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.pixGreen),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Status de Aguardo do Pagamento
          if (!_isPaid)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.pixGreen),
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Aguardando confirmação bancária...',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.check_circle, color: AppTheme.pixGreen, size: 20),
                SizedBox(width: 8),
                Text(
                  'Pagamento confirmado com sucesso!',
                  style: TextStyle(
                    color: AppTheme.pixGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),

          // Botão para testes: Simular Webhook bancário
          TextButton.icon(
            onPressed: _isSimulating ? null : _simulateWebhook,
            icon: const Icon(Icons.bolt, color: AppTheme.primary, size: 18),
            label: Text(
              _isSimulating
                  ? 'Processando liquidação...'
                  : 'Simular Webhook do Banco (Aprovar Pix)',
              style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
