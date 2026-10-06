import 'package:flutter/material.dart';
import '../core/theme/loco_theme.dart';
import '../models/ticket.dart';
import '../services/security_services.dart';

class DigitalTicketInspector extends StatelessWidget {
  final BookedTicket ticket;
  final VoidCallback? onSimulateScan;

  const DigitalTicketInspector({
    super.key,
    required this.ticket,
    this.onSimulateScan,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 24, offset: Offset(0, 8)),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Orange Band
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: LocoColors.orange,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.train, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'LOCO DIGITAL PASS • ${ticket.trainType}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Station Hop Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ticket.fromStationCode,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: LocoColors.textPrimary,
                              ),
                            ),
                            Text(
                              ticket.fromStationName,
                              style: const TextStyle(fontSize: 13, color: LocoColors.textSecondary),
                            ),
                          ],
                        ),
                        const Icon(Icons.arrow_forward, color: LocoColors.orange, size: 26),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              ticket.toStationCode,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: LocoColors.textPrimary,
                              ),
                            ),
                            Text(
                              ticket.toStationName,
                              style: const TextStyle(fontSize: 13, color: LocoColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),

                    // QR Code Area
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: LocoColors.canvas,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: LocoColors.border),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: LocoColors.border),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.qr_code_2,
                                size: 130,
                                color: LocoColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            ticket.id,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.0,
                              color: LocoColors.orange,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'OFFICIAL TTE CRYPTO TOKEN VERIFIED',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: LocoColors.textMuted),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Passenger & Fare Details Table
                    _buildInfoRow('Passenger', ticket.passengerName),
                    _buildInfoRow('ID Proof', '${ticket.passengerIdType} (${ticket.passengerIdNumber})'),
                    _buildInfoRow('Class', '${ticket.classType} CLASS'),
                    _buildInfoRow('Distance', '${ticket.distanceKm.toStringAsFixed(1)} km'),
                    _buildInfoRow('Total Fare', '₹${ticket.fare.toInt()} (PAID • LOCO AUTH)'),
                    _buildInfoRow('Provider', ticket.provider.isNotEmpty ? ticket.provider : 'LOCO_CORE'),
                    if (ticket.validUntil != null)
                      _buildInfoRow(
                        'Valid Until',
                        '${ticket.validUntil!.day}/${ticket.validUntil!.month}/${ticket.validUntil!.year} at ${ticket.validUntil!.hour}:${ticket.validUntil!.minute.toString().padLeft(2, '0')}',
                      ),
                    _buildInfoRow(
                      'Booking Time',
                      '${ticket.bookingDate.day}/${ticket.bookingDate.month}/${ticket.bookingDate.year} at ${ticket.bookingDate.hour}:${ticket.bookingDate.minute.toString().padLeft(2, '0')}',
                    ),

                    const SizedBox(height: 20),

                    // Simulation Scan Button (TTE Ticket Checking Test)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final isValid = FraudDetectionService().validateTicketScan(
                            ticketId: ticket.id,
                            currentStationName: ticket.fromStationName,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: isValid ? LocoColors.success : LocoColors.error,
                              content: Text(
                                isValid
                                    ? '✓ TTE Validation Success: Ticket verified at ${ticket.fromStationName}'
                                    : '⚠️ Suspicious Ticket Activity Triggered! Check Security Dashboard.',
                              ),
                            ),
                          );
                          if (onSimulateScan != null) onSimulateScan!();
                        },
                        icon: const Icon(Icons.qr_code_scanner, size: 18),
                        label: const Text('Simulate TTE Ticket Check'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: LocoColors.textSecondary)),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: LocoColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
