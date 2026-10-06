import 'dart:async';
import 'payment_repository.dart';

// Re-export payment types for UI components
export 'payment_repository.dart' show PaymentMethod, PaymentResult, PaymentRepository;

/// Clean service wrapper delegating to [PaymentRepository].
/// Removed fake delays and simulated TXN_LOCO_* transactions.
class PaymentService {
  static PaymentRepository _repository = DefaultPaymentRepository();

  static void setRepository(PaymentRepository repository) {
    _repository = repository;
  }

  static Future<PaymentResult> processPayment({
    required int amount,
    required PaymentMethod method,
    String? upiId,
    String? ticketId,
  }) {
    return _repository.processPayment(
      amount: amount,
      method: method,
      upiId: upiId,
      ticketId: ticketId,
    );
  }
}
