import 'dart:async';

enum PaymentMethod {
  upi,
  card,
  netBanking,
  locoWallet,
}

class PaymentResult {
  final bool success;
  final String transactionId;
  final String message;

  PaymentResult({
    required this.success,
    required this.transactionId,
    required this.message,
  });
}

class PaymentService {
  static Future<PaymentResult> processPayment({
    required int amount,
    required PaymentMethod method,
    String? upiId,
  }) async {
    // Simulate instantaneous, secure payment gateway transaction
    await Future.delayed(const Duration(milliseconds: 900));

    final txId = 'TXN_LOCO_${DateTime.now().millisecondsSinceEpoch.toString().substring(4)}';
    return PaymentResult(
      success: true,
      transactionId: txId,
      message: '₹$amount received successfully via ${method.name.toUpperCase()}.',
    );
  }
}
