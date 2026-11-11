import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';

class DriverWalletScreen extends StatelessWidget {
  final UserModel driver;

  const DriverWalletScreen({super.key, required this.driver});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carteira do Motorista'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card Principal de Saldo
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E2822), Color(0xFF131A16)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.pixGreen.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'Saldo Disponível',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                      ),
                      Icon(Icons.pix, color: AppTheme.pixGreen, size: 24),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'R\$ ${driver.walletBalance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textLight,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Repasse de 85% de todas as corridas realizadas.',
                    style: TextStyle(color: AppTheme.pixGreen, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Informações da Chave Pix Cadastrada
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2D2D3A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chave Pix Cadastrada para Saque',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.key, color: AppTheme.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          driver.pixKey ?? driver.phone,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textLight,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          driver.pixKeyType?.toUpperCase() ?? 'TELEFONE',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Botão Saque Pix
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Solicitação de saque Pix enviada para processamento!'),
                    backgroundColor: AppTheme.pixGreen,
                  ),
                );
              },
              icon: const Icon(Icons.arrow_downward),
              label: const Text('Solicitar Saque Pix'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.pixGreen,
                foregroundColor: Colors.black,
              ),
            ),
            const SizedBox(height: 28),

            // Histórico de Ganhos Recentes
            const Text(
              'Últimos Repasses',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textLight,
              ),
            ),
            const SizedBox(height: 12),
            _buildPayoutItem(
              title: 'Av. Paulista ➔ Congonhas',
              date: 'Hoje, 11:20',
              grossFare: 32.48,
              netFare: 27.61,
            ),
            _buildPayoutItem(
              title: 'Shopping Morumbi ➔ Faria Lima',
              date: 'Hoje, 09:45',
              grossFare: 24.50,
              netFare: 20.82,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayoutItem({
    required String title,
    required String date,
    required double grossFare,
    required double netFare,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2D2D3A)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textLight,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$date • Bruto: R\$ ${grossFare.toStringAsFixed(2)}',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
            ],
          ),
          Text(
            '+ R\$ ${netFare.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.pixGreen,
            ),
          ),
        ],
      ),
    );
  }
}
