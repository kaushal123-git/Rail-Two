import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class PaymentCheckoutModal extends StatefulWidget {
  final double amount;
  final String title;
  final String description;

  const PaymentCheckoutModal({
    super.key,
    required this.amount,
    required this.title,
    required this.description,
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required double amount,
    required String title,
    required String description,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: PaymentCheckoutModal(
          amount: amount,
          title: title,
          description: description,
        ),
      ),
    );
  }

  @override
  State<PaymentCheckoutModal> createState() => _PaymentCheckoutModalState();
}

class _PaymentCheckoutModalState extends State<PaymentCheckoutModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Wallet State
  double _walletBalance = 100.0;
  bool _isLoadingBalance = true;
  String _mpin = '';
  bool _isProcessingWallet = false;
  String _walletError = '';

  // Razorpay State
  bool _isInitializingRazorpay = false;
  String _selectedCardType = 'CREDIT_CARD';
  String _selectedBank = 'HDFC';
  bool _isProcessingRazorpay = false;

  // UPI QR State
  bool _isGeneratingUpi = false;
  String _upiIntentUrl = '';
  String _transactionId = '';
  String _upiUtr = '';
  int _upiCountdown = 300; // 5 minutes
  Timer? _timer;
  bool _isVerifyingUpi = false;

  String _userPhone = '9876543210';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = await AuthService.getSavedUser();
    if (user != null && user.phone.isNotEmpty) {
      _userPhone = user.phone;
    }

    final backendBal = await ApiService.getWalletBalance(_userPhone);
    if (mounted) {
      setState(() {
        _walletBalance = backendBal ?? user?.rwalletBalance ?? 100.0;
        _isLoadingBalance = false;
      });
    }
  }

  void _startUpiTimer() {
    _timer?.cancel();
    _upiCountdown = 300;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_upiCountdown > 0) {
        if (mounted) setState(() => _upiCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  // Handle R-Wallet Payment
  Future<void> _handleWalletPay() async {
    if (_mpin.length != 6) {
      setState(() => _walletError = 'Please enter valid 6-digit mPIN.');
      return;
    }

    setState(() {
      _isProcessingWallet = true;
      _walletError = '';
    });

    final res = await ApiService.payViaWallet(
      phone: _userPhone,
      amount: widget.amount,
      mpin: _mpin,
      description: widget.description,
    );

    if (!mounted) return;
    setState(() => _isProcessingWallet = false);

    if (res['success'] == true) {
      final data = res['data'];
      final newBal = (data['new_rwallet_balance'] as num).toDouble();
      await AuthService.updateWalletBalance(newBal);

      Navigator.pop(context, {
        'success': true,
        'payment_method': 'RWALLET',
        'transaction_id': data['transaction_id'],
        'amount': widget.amount,
      });
    } else {
      setState(() => _walletError = res['message'] ?? 'Wallet payment failed.');
    }
  }

  // Handle Wallet Top Up
  Future<void> _topUpWallet(double topupAmount) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final res = await ApiService.createPaymentOrder(
      phone: _userPhone,
      amount: topupAmount,
      paymentMethod: 'RAZORPAY',
      purpose: 'WALLET_TOPUP',
      description: 'R-Wallet Balance Recharge',
    );

    if (!mounted) return;
    Navigator.pop(context); // Close loader

    if (res['success'] == true) {
      final txData = res['data'];
      final verifyRes = await ApiService.verifyPayment(
        transactionId: txData['transaction_id'],
        phone: _userPhone,
        razorpayOrderId: txData['gateway_order_id'],
        razorpayPaymentId: 'pay_topup_${DateTime.now().millisecondsSinceEpoch}',
        razorpaySignature: 'simulated_topup_signature',
      );

      if (verifyRes['success'] == true) {
        final newBal = (verifyRes['data']['new_rwallet_balance'] as num).toDouble();
        await AuthService.updateWalletBalance(newBal);
        setState(() {
          _walletBalance = newBal;
          _walletError = '';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚡ Wallet Recharged by ₹${topupAmount.toInt()}! New Balance: ₹${newBal.toStringAsFixed(2)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  // Handle Razorpay Payment
  Future<void> _handleRazorpayPay() async {
    setState(() => _isProcessingRazorpay = true);

    final orderRes = await ApiService.createPaymentOrder(
      phone: _userPhone,
      amount: widget.amount,
      paymentMethod: 'RAZORPAY',
      purpose: 'TICKET_BOOKING',
      description: widget.description,
    );

    if (orderRes['success'] != true) {
      if (mounted) {
        setState(() => _isProcessingRazorpay = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(orderRes['message'] ?? 'Failed to initialize Razorpay.')),
        );
      }
      return;
    }

    final orderData = orderRes['data'];
    final String txId = orderData['transaction_id'];
    final String orderId = orderData['gateway_order_id'];

    // Simulate Razorpay Gateway Interface Delay
    await Future.delayed(const Duration(milliseconds: 1200));

    final verifyRes = await ApiService.verifyPayment(
      transactionId: txId,
      phone: _userPhone,
      razorpayOrderId: orderId,
      razorpayPaymentId: 'pay_rzp_${DateTime.now().millisecondsSinceEpoch}',
      razorpaySignature: 'ver_rzp_sig_2026',
    );

    if (!mounted) return;
    setState(() => _isProcessingRazorpay = false);

    if (verifyRes['success'] == true) {
      Navigator.pop(context, {
        'success': true,
        'payment_method': 'RAZORPAY',
        'transaction_id': txId,
        'payment_id': verifyRes['data']['payment_id'],
        'amount': widget.amount,
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(verifyRes['message'] ?? 'Razorpay payment verification failed.')),
      );
    }
  }

  // Generate UPI QR
  Future<void> _generateUpiQr() async {
    setState(() => _isGeneratingUpi = true);

    final res = await ApiService.createPaymentOrder(
      phone: _userPhone,
      amount: widget.amount,
      paymentMethod: 'UPI_QR',
      purpose: 'TICKET_BOOKING',
      description: widget.description,
    );

    if (!mounted) return;
    setState(() => _isGeneratingUpi = false);

    if (res['success'] == true) {
      final data = res['data'];
      setState(() {
        _transactionId = data['transaction_id'];
        _upiIntentUrl = data['upi_intent_url'];
      });
      _startUpiTimer();
    }
  }

  // Verify UPI Payment
  Future<void> _verifyUpiPayment() async {
    if (_transactionId.isEmpty) {
      await _generateUpiQr();
    }

    setState(() => _isVerifyingUpi = true);

    final verifyRes = await ApiService.verifyPayment(
      transactionId: _transactionId,
      phone: _userPhone,
      upiUtr: _upiUtr.isNotEmpty ? _upiUtr : null,
    );

    if (!mounted) return;
    setState(() => _isVerifyingUpi = false);

    if (verifyRes['success'] == true) {
      Navigator.pop(context, {
        'success': true,
        'payment_method': 'UPI_QR',
        'transaction_id': _transactionId,
        'payment_id': verifyRes['data']['payment_id'],
        'amount': widget.amount,
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(verifyRes['message'] ?? 'UPI verification failed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.description,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Text(
                    '₹ ${widget.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0066FF),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Tab Bar
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF0066FF),
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: const Color(0xFF0066FF),
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [
              Tab(icon: Icon(Icons.account_balance_wallet, size: 20), text: 'R-Wallet'),
              Tab(icon: Icon(Icons.credit_card, size: 20), text: 'Razorpay'),
              Tab(icon: Icon(Icons.qr_code_2, size: 20), text: 'UPI QR'),
            ],
          ),

          // Tab Views
          SizedBox(
            height: 340,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildWalletTab(),
                _buildRazorpayTab(),
                _buildUpiTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // TAB 1: R-WALLET
  Widget _buildWalletTab() {
    final bool hasEnoughBalance = _walletBalance >= widget.amount;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wallet Balance Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0066FF), Color(0xFF0044B3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0066FF).withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'R-Wallet Balance',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    _isLoadingBalance
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            '₹ ${_walletBalance.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _topUpWallet(100.0),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('+ Top Up ₹100'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0066FF),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          if (hasEnoughBalance) ...[
            const Text(
              'Enter 6-Digit mPIN to Confirm Payment:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 12),
            PinCodeTextField(
              appContext: context,
              length: 6,
              obscureText: true,
              animationType: AnimationType.fade,
              pinTheme: PinTheme(
                shape: PinCodeFieldShape.box,
                borderRadius: BorderRadius.circular(10),
                fieldHeight: 45,
                fieldWidth: 42,
                activeFillColor: Colors.grey.shade100,
                selectedFillColor: Colors.white,
                inactiveFillColor: Colors.grey.shade50,
                activeColor: const Color(0xFF0066FF),
                selectedColor: const Color(0xFF0066FF),
                inactiveColor: Colors.grey.shade300,
              ),
              animationDuration: const Duration(milliseconds: 200),
              enableActiveFill: true,
              onChanged: (value) => setState(() => _mpin = value),
            ),
            if (_walletError.isNotEmpty)
              Text(
                _walletError,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isProcessingWallet ? null : _handleWalletPay,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0066FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: _isProcessingWallet
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('Pay ₹${widget.amount.toStringAsFixed(2)} via R-Wallet',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ] else ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amber),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Insufficient R-Wallet Balance. Please top up your wallet or select Razorpay/UPI.',
                      style: TextStyle(fontSize: 13, color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _topUpWallet(50.0),
                    child: const Text('+ Re-charge ₹50'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _topUpWallet(200.0),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0066FF)),
                    child: const Text('+ Re-charge ₹200', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // TAB 2: RAZORPAY GATEWAY
  Widget _buildRazorpayTab() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C2340),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Razorpay',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.lock, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                '256-bit SSL Encrypted Secure Gateway',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Select Payment Instrument:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('💳 Credit / Debit Card'),
                  selected: _selectedCardType == 'CREDIT_CARD',
                  onSelected: (val) => setState(() => _selectedCardType = 'CREDIT_CARD'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('🏛️ Net Banking'),
                  selected: _selectedCardType == 'NET_BANKING',
                  onSelected: (val) => setState(() => _selectedCardType = 'NET_BANKING'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('👛 Paytm / Wallets'),
                  selected: _selectedCardType == 'WALLETS',
                  onSelected: (val) => setState(() => _selectedCardType = 'WALLETS'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user, color: Color(0xFF0066FF)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Instant auto-refund guaranteed in case of transaction failure.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isProcessingRazorpay ? null : _handleRazorpayPay,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0C2340),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: _isProcessingRazorpay
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      'Pay ₹${widget.amount.toStringAsFixed(2)} via Razorpay',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // TAB 3: DYNAMIC UPI QR
  Widget _buildUpiTab() {
    if (_transactionId.isEmpty && !_isGeneratingUpi) {
      _generateUpiQr();
    }

    final minutes = (_upiCountdown ~/ 60).toString().padLeft(2, '0');
    final seconds = (_upiCountdown % 60).toString().padLeft(2, '0');

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          if (_isGeneratingUpi)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Generating Dynamic UPI QR...'),
                  ],
                ),
              ),
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.qr_code, color: Color(0xFF0066FF)),
                    SizedBox(width: 8),
                    Text(
                      'Scan with any UPI App',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '⏱️ $minutes:$seconds',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Simulated Dynamic QR Box
            Container(
              width: 140,
              height: 140,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF0066FF), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.qr_code_2, size: 120, color: Colors.grey.shade800),
                  Container(
                    padding: const EdgeInsets.all(4),
                    color: Colors.white,
                    child: const Text('UPI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Color(0xFF0066FF))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'UPI ID: railone@upi',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
            ),

            const SizedBox(height: 12),

            // UTR input for verification
            TextField(
              decoration: InputDecoration(
                hintText: 'Enter 12-digit UTR / Ref No. (Optional)',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              keyboardType: TextInputType.number,
              onChanged: (val) => _upiUtr = val,
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _isVerifyingUpi ? null : _verifyUpiPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0066FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: _isVerifyingUpi
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'I Have Paid • Verify Now',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
