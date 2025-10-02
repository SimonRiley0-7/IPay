class OrderModel {
  final String id;
  final String displayId;
  final String numericalID;
  final double amount;
  final OrderStatus status;
  final DateTime createdAt;
  final String merchantName;
  final int itemCount;

  OrderModel({
    required this.id,
    required this.displayId,
    required this.numericalID,
    required this.amount,
    required this.status,
    required this.createdAt,
    required this.merchantName,
    required this.itemCount,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['_id'] ?? json['id'] ?? '',
      displayId: json['orderNumber'] ?? '#${json['_id']?.toString().substring(0, 6).toUpperCase()}',
      numericalID: json['numericalID'] ?? json['_id']?.toString().substring(0, 6) ?? '000000',
      amount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      status: _mapOrderStatus(json['status']),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      merchantName: 'iPay Store',
      itemCount: (json['products'] as List?)?.length ?? 0,
    );
  }

  static OrderStatus _mapOrderStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return OrderStatus.paid;
      case 'pending':
        return OrderStatus.pending;
      case 'failed':
        return OrderStatus.failed;
      case 'cancelled':
        return OrderStatus.cancelled;
      case 'processing':
        return OrderStatus.processing;
      default:
        return OrderStatus.pending;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayId': displayId,
      'numericalID': numericalID,
      'amount': amount,
      'status': status.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'merchantName': merchantName,
      'itemCount': itemCount,
    };
  }
}

enum OrderStatus {
  pending,
  processing,
  paid,
  failed,
  cancelled,
}

