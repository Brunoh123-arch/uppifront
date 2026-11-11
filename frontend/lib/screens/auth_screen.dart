import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/services/uppi_api_service.dart';
import 'passenger/passenger_home_screen.dart';
import 'driver/driver_home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _phoneController = TextEditingController(text: '+5511999990001');
  final _nameController = TextEditingController(text: 'Mariana Silva');
  final _codeController = TextEditingController(text: '1234');
  String _selectedRole = 'rider'; // 'rider' ou 'driver'
  bool _isLoading = false;
  String? _errorMessage;

  void _onRoleChanged(String role) {
    setState(() {
      _selectedRole = role;
      if (role == 'driver') {
        _phoneController.text = '+5511999990002';
        _nameController.text = 'Carlos Oliveira (Motorista)';
      } else {
        _phoneController.text = '+5511999990001';
        _nameController.text = 'Mariana Silva (Passageira)';
      }
    });
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await UppiApiService.instance.loginWithPhone(
        phone: _phoneController.text.trim(),
        code: _codeController.text.trim(),
        fullName: _nameController.text.trim(),
      );

      if (!mounted) return;

      if (_selectedRole == 'driver') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => DriverHomeScreen(driver: user)),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => PassengerHomeScreen(user: user)),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              // Logo Uppi
              Center(
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'U',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'UPPI',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: AppTheme.textLight,
                  ),
                ),
              ),
              const Center(
                child: Text(
                  'Mobilidade Urbana Brasileira',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 36),

              // Seletor de Perfil (Passageiro vs Motorista)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _onRoleChanged('rider'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedRole == 'rider'
                                ? AppTheme.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Passageiro',
                            style: TextStyle(
                              color: _selectedRole == 'rider'
                                  ? Colors.black
                                  : AppTheme.textMuted,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _onRoleChanged('driver'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedRole == 'driver'
                                ? AppTheme.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Motorista',
                            style: TextStyle(
                              color: _selectedRole == 'driver'
                                  ? Colors.black
                                  : AppTheme.textMuted,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Campo de Nome Completo
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome Completo',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),

              // Campo de Telefone com +55
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Celular (+55 com DDD)',
                  prefixIcon: Icon(Icons.phone_android),
                ),
              ),
              const SizedBox(height: 16),

              // Código de Teste
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Código SMS',
                  prefixIcon: const Icon(Icons.security),
                  suffixText: 'Bypass: 1234',
                  suffixStyle: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Dica Brasil / Pix
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.pixGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.pixGreen.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.bolt, color: AppTheme.pixGreen, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pagamento instantâneo via Pix integrado e repasse de 85% para motoristas.',
                        style: TextStyle(
                          color: AppTheme.pixGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppTheme.accentRed, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Botão Entrar
              ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      )
                    : Text(
                        _selectedRole == 'driver'
                            ? 'Acessar Central do Motorista'
                            : 'Entrar como Passageiro',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
