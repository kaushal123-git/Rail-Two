import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Base URL for backend authentication server
  static const String baseUrl = 'http://127.0.0.1:8000/api/v1/auth';

  /// Check server connectivity
  static Future<bool> isServerAvailable() async {
    try {
      final response = await http
          .get(Uri.parse('http://127.0.0.1:8000/api/v1/health'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Request OTP from backend API
  static Future<Map<String, dynamic>> sendOtp({
    required String phone,
    String name = 'Rail Commuter',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/send-otp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'phone': phone, 'name': name}),
          )
          .timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'otp': data['otp'], 'message': data['message']};
      } else {
        return {'success': false, 'message': data['detail'] ?? 'Failed to send OTP'};
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error connecting to backend: ${e.toString()}',
      };
    }
  }

  /// Verify OTP code with backend API
  static Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/verify-otp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'phone': phone, 'otp': otp}),
          )
          .timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['detail'] ?? 'Invalid OTP code'};
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error connecting to backend: ${e.toString()}',
      };
    }
  }

  /// Register user & set mPIN on backend API
  static Future<Map<String, dynamic>> registerUser({
    required String phone,
    required String name,
    required String mpin,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'phone': phone,
              'name': name,
              'mpin': mpin,
            }),
          )
          .timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'token': data['token'],
          'user': data['user'],
          'message': data['message'],
        };
      } else {
        return {'success': false, 'message': data['detail'] ?? 'Registration failed'};
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error connecting to backend: ${e.toString()}',
      };
    }
  }

  /// Login with mPIN on backend API
  static Future<Map<String, dynamic>> loginMpin({
    required String phone,
    required String mpin,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/login-mpin'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'phone': phone,
              'mpin': mpin,
            }),
          )
          .timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'token': data['token'],
          'user': data['user'],
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'statusCode': response.statusCode,
          'message': data['detail'] ?? 'Invalid mPIN',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error connecting to backend: ${e.toString()}',
      };
    }
  }

  /// Fetch user profile using JWT token
  static Future<Map<String, dynamic>> getUserProfile(String token) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/me'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'user': data['user']};
      } else {
        return {'success': false, 'message': data['detail'] ?? 'Unauthorized'};
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error connecting to backend: ${e.toString()}',
      };
    }
  }

  /// Reset mPIN on backend API
  static Future<Map<String, dynamic>> resetMpin({
    required String phone,
    required String newMpin,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/reset-mpin'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'phone': phone,
              'new_mpin': newMpin,
            }),
          )
          .timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['detail'] ?? 'Reset mPIN failed'};
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error connecting to backend: ${e.toString()}',
      };
    }
  }

  // Payment Base URL
  static const String paymentBaseUrl = 'http://127.0.0.1:8000/api/v1/payment';

  /// Create payment order (Razorpay or UPI QR)
  static Future<Map<String, dynamic>> createPaymentOrder({
    required String phone,
    required double amount,
    required String paymentMethod,
    String purpose = 'TICKET_BOOKING',
    String description = 'Rail One Payment',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$paymentBaseUrl/create-order'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'phone': phone,
              'amount': amount,
              'payment_method': paymentMethod,
              'purpose': purpose,
              'description': description,
            }),
          )
          .timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['detail'] ?? 'Failed to create payment order'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error creating order: ${e.toString()}'};
    }
  }

  /// Verify Razorpay / UPI payment completion
  static Future<Map<String, dynamic>> verifyPayment({
    required String transactionId,
    required String phone,
    String? razorpayOrderId,
    String? razorpayPaymentId,
    String? razorpaySignature,
    String? upiUtr,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$paymentBaseUrl/verify-payment'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'transaction_id': transactionId,
              'phone': phone,
              'razorpay_order_id': razorpayOrderId,
              'razorpay_payment_id': razorpayPaymentId,
              'razorpay_signature': razorpaySignature,
              'upi_utr': upiUtr,
            }),
          )
          .timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['detail'] ?? 'Payment verification failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error verifying payment: ${e.toString()}'};
    }
  }

  /// Pay ticket fare directly via R-Wallet balance
  static Future<Map<String, dynamic>> payViaWallet({
    required String phone,
    required double amount,
    required String mpin,
    String description = 'Rail Ticket Purchase via R-Wallet',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$paymentBaseUrl/pay-via-wallet'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'phone': phone,
              'amount': amount,
              'mpin': mpin,
              'description': description,
            }),
          )
          .timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['detail'] ?? 'Wallet payment failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error processing wallet payment: ${e.toString()}'};
    }
  }

  /// Fetch user R-Wallet balance
  static Future<double?> getWalletBalance(String phone) async {
    try {
      final response = await http
          .get(Uri.parse('$paymentBaseUrl/wallet-balance?phone=$phone'))
          .timeout(const Duration(seconds: 4));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return (data['rwallet_balance'] as num).toDouble();
      }
    } catch (_) {}
    return null;
  }
}

