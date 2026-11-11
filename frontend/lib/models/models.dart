class UserModel {
  final String id;
  final String phone;
  final String fullName;
  final String userType;
  final double walletBalance;
  final String? pixKey;
  final String? pixKeyType;

  UserModel({
    required this.id,
    required this.phone,
    required this.fullName,
    required this.userType,
    this.walletBalance = 0.0,
    this.pixKey,
    this.pixKeyType,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? 'Usuário Uppi',
      userType: json['user_type']?.toString() ?? 'rider',
      walletBalance: (json['wallet_balance'] as num?)?.toDouble() ?? 0.0,
      pixKey: json['pix_key']?.toString(),
      pixKeyType: json['pix_key_type']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'full_name': fullName,
        'user_type': userType,
        'wallet_balance': walletBalance,
        'pix_key': pixKey,
        'pix_key_type': pixKeyType,
      };
}

class TariffOption {
  final String category;
  final String name;
  final double price;
  final String formattedPrice;
  final String etaText;
  final String description;

  TariffOption({
    required this.category,
    required this.name,
    required this.price,
    required this.formattedPrice,
    required this.etaText,
    required this.description,
  });

  factory TariffOption.fromJson(Map<String, dynamic> json) {
    return TariffOption(
      category: json['category'] ?? 'pop',
      name: json['name'] ?? 'Uppi Pop',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      formattedPrice: json['formatted_price'] ?? r'R$ 0,00',
      etaText: json['eta_text'] ?? '5 min',
      description: json['description'] ?? '',
    );
  }
}

class RideModel {
  final String id;
  final String orderNumber;
  final String riderId;
  final String? driverId;
  final String category;
  final String originAddress;
  final String destinationAddress;
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final double estimatedFare;
  final double? finalFare;
  final String? pixCopyPaste;
  final String? pixQrUrl;
  final String? driverName;
  final String? vehicleModel;
  final String? vehiclePlate;

  RideModel({
    required this.id,
    required this.orderNumber,
    required this.riderId,
    this.driverId,
    required this.category,
    required this.originAddress,
    required this.destinationAddress,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.estimatedFare,
    this.finalFare,
    this.pixCopyPaste,
    this.pixQrUrl,
    this.driverName,
    this.vehicleModel,
    this.vehiclePlate,
  });

  factory RideModel.fromJson(Map<String, dynamic> json) {
    return RideModel(
      id: json['id']?.toString() ?? '',
      orderNumber: json['order_number']?.toString() ?? '',
      riderId: json['rider_id']?.toString() ?? '',
      driverId: json['driver_id']?.toString(),
      category: json['category']?.toString() ?? 'pop',
      originAddress: json['origin_address']?.toString() ?? 'Origem',
      destinationAddress: json['destination_address']?.toString() ?? 'Destino',
      status: json['status']?.toString() ?? 'searching',
      paymentMethod: json['payment_method']?.toString() ?? 'pix',
      paymentStatus: json['payment_status']?.toString() ?? 'pending',
      estimatedFare: (json['estimated_fare'] as num?)?.toDouble() ?? 0.0,
      finalFare: (json['final_fare'] as num?)?.toDouble(),
      pixCopyPaste: json['pix_copy_paste']?.toString(),
      pixQrUrl: json['pix_qr_url']?.toString(),
      driverName: json['driver']?['name']?.toString() ?? json['driver_name']?.toString(),
      vehicleModel: json['driver']?['vehicle_model']?.toString() ?? json['vehicle_model']?.toString(),
      vehiclePlate: json['driver']?['vehicle_plate']?.toString() ?? json['vehicle_plate']?.toString(),
    );
  }
}
