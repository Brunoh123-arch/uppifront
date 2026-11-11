import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../../models/models.dart';

class UppiApiService {
  static final UppiApiService instance = UppiApiService._internal();
  UppiApiService._internal();

  // 1. Autenticação por Celular (+55 e código 1234)
  Future<UserModel> loginWithPhone({
    required String phone,
    required String code,
    required String fullName,
  }) async {
    final res = await http.post(
      ApiConfig.functionUri('auth-phone'),
      headers: ApiConfig.defaultHeaders,
      body: jsonEncode({
        'action': 'verify_code',
        'phone': phone,
        'code': code,
        'full_name': fullName,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Erro ao autenticar: ${res.body}');
    }

    final data = jsonDecode(res.body);
    return UserModel.fromJson(data['user']);
  }

  // 2. Orçamento de Tarifas (Pop, Comfort, Moto, Entrega)
  Future<List<TariffOption>> getEstimates({
    required double originLat,
    required double originLon,
    required double destLat,
    required double destLon,
  }) async {
    final res = await http.post(
      ApiConfig.functionUri('routestats'),
      headers: ApiConfig.defaultHeaders,
      body: jsonEncode({
        'origin': {'lat': originLat, 'lon': originLon},
        'destination': {'lat': destLat, 'lon': destLon},
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Erro ao calcular rota: ${res.body}');
    }

    final data = jsonDecode(res.body);
    final List options = data['options'] ?? [];
    return options.map((item) => TariffOption.fromJson(item)).toList();
  }

  // 3. Solicitação de Corrida com Pix Automático
  Future<RideModel> requestRide({
    required String riderId,
    required String category,
    required String originAddress,
    required double originLat,
    required double originLon,
    required String destAddress,
    required double destLat,
    required double destLon,
    required double estimatedFare,
    String paymentMethod = 'pix',
  }) async {
    final res = await http.post(
      ApiConfig.functionUri('ordercommit'),
      headers: ApiConfig.defaultHeaders,
      body: jsonEncode({
        'rider_id': riderId,
        'category': category,
        'origin': {'address': originAddress, 'lat': originLat, 'lon': originLon},
        'destination': {'address': destAddress, 'lat': destLat, 'lon': destLon},
        'payment_method': paymentMethod,
        'estimated_fare': estimatedFare,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Erro ao solicitar corrida: ${res.body}');
    }

    final data = jsonDecode(res.body);
    final rideData = data['ride'] ?? {};
    final pixData = data['pix'] ?? {};

    return RideModel(
      id: data['order_id'] ?? rideData['id'] ?? '',
      orderNumber: data['order_number'] ?? rideData['order_number'] ?? '',
      riderId: riderId,
      category: category,
      originAddress: originAddress,
      destinationAddress: destAddress,
      status: rideData['status'] ?? 'searching',
      paymentMethod: paymentMethod,
      paymentStatus: rideData['payment_status'] ?? 'pending',
      estimatedFare: estimatedFare,
      pixCopyPaste: pixData['pix_copy_paste'],
      pixQrUrl: pixData['qr_code_url'],
    );
  }

  // 4. Polling do Estado da Corrida (Orderstate)
  Future<RideModel> getRideState(String rideId) async {
    final res = await http.post(
      ApiConfig.functionUri('orderstate'),
      headers: ApiConfig.defaultHeaders,
      body: jsonEncode({'ride_id': rideId}),
    );

    if (res.statusCode != 200) {
      throw Exception('Erro ao obter status da corrida: ${res.body}');
    }

    final data = jsonDecode(res.body);
    return RideModel.fromJson(data['ride'] ?? {});
  }

  // 5. Motorista: Atualizar GPS Online
  Future<bool> updateDriverLocation({
    required String driverId,
    required double lat,
    required double lon,
    double bearing = 0.0,
    double speed = 0.0,
  }) async {
    final res = await http.post(
      ApiConfig.functionUri('driver-action'),
      headers: ApiConfig.defaultHeaders,
      body: jsonEncode({
        'action': 'update_location',
        'driver_id': driverId,
        'lat': lat,
        'lon': lon,
        'bearing': bearing,
        'speed': speed,
      }),
    );
    return res.statusCode == 200;
  }

  // 6. Motorista: Ações do Ciclo de Corrida (accept, arrived, start, complete)
  Future<Map<String, dynamic>> driverAction({
    required String action,
    required String driverId,
    required String rideId,
    double? finalFare,
  }) async {
    final Map<String, dynamic> payload = {
      'action': action,
      'driver_id': driverId,
      'ride_id': rideId,
    };
    if (finalFare != null) {
      payload['final_fare'] = finalFare;
    }

    final res = await http.post(
      ApiConfig.functionUri('driver-action'),
      headers: ApiConfig.defaultHeaders,
      body: jsonEncode(payload),
    );

    if (res.statusCode != 200) {
      throw Exception('Erro ao executar ação do motorista: ${res.body}');
    }

    return jsonDecode(res.body);
  }

  // 7. Simular Liquidação do Pix (Webhook Bancário)
  Future<bool> simulatePixConfirmation({
    required String rideId,
    required double amount,
  }) async {
    final res = await http.post(
      ApiConfig.functionUri('pix-webhook'),
      headers: ApiConfig.defaultHeaders,
      body: jsonEncode({
        'ride_id': rideId,
        'status': 'PAID',
        'amount': amount,
        'txid': 'PIX-APP-${DateTime.now().millisecondsSinceEpoch}',
      }),
    );
    return res.statusCode == 200;
  }
}
