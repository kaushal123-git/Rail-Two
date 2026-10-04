class RevenueRecoveryEstimate {
  final double annualPassengers;
  final double baselineEvasionRatePercent;
  final double avgTicketFareRs;
  final double systemEfficiencyPercent;
  final double falsePositiveRatePercent;

  RevenueRecoveryEstimate({
    required this.annualPassengers,
    required this.baselineEvasionRatePercent,
    required this.avgTicketFareRs,
    required this.systemEfficiencyPercent,
    required this.falsePositiveRatePercent,
  });

  /// Total Annual Fare Evasion Loss before system implementation (in Rupees)
  double get totalBaselineEvasionLoss =>
      annualPassengers * (baselineEvasionRatePercent / 100.0) * avgTicketFareRs;

  /// Total Annual Revenue Recovered after implementing GPS + Geofence + ML Fraud Prevention (in Rupees)
  double get estimatedAnnualRevenueRecovered =>
      totalBaselineEvasionLoss *
      (systemEfficiencyPercent / 100.0) *
      (1.0 - (falsePositiveRatePercent / 100.0));

  /// Residual Unrecovered Loss (in Rupees)
  double get residualLoss => totalBaselineEvasionLoss - estimatedAnnualRevenueRecovered;

  /// Effective Reduction in Ticketless Travel Rate (%)
  double get effectiveEvasionReductionPercent =>
      baselineEvasionRatePercent * (systemEfficiencyPercent / 100.0);

  /// Return on Investment (ROI) Ratio assuming fixed deployment cost
  double calculateRoi(double systemDeploymentCostRs) {
    if (systemDeploymentCostRs <= 0) return 0.0;
    return ((estimatedAnnualRevenueRecovered - systemDeploymentCostRs) / systemDeploymentCostRs) * 100.0;
  }
}

class RevenueRecoveryService {
  /// Default Suburban Railway Network Parameters (Mumbai Suburban Network Model)
  static RevenueRecoveryEstimate calculateDefaultRecoveryModel() {
    return RevenueRecoveryEstimate(
      annualPassengers: 2800000000.0, // 2.8 Billion annual commuters
      baselineEvasionRatePercent: 4.5, // 4.5% ticketless travel baseline
      avgTicketFareRs: 15.0, // Avg suburban fare
      systemEfficiencyPercent: 88.5, // 88.5% fraud prevention efficiency
      falsePositiveRatePercent: 1.2, // 1.2% false positive rate
    );
  }

  static RevenueRecoveryEstimate calculateCustomModel({
    required double annualPassengers,
    required double baselineEvasionRatePercent,
    required double avgTicketFareRs,
    required double systemEfficiencyPercent,
    required double falsePositiveRatePercent,
  }) {
    return RevenueRecoveryEstimate(
      annualPassengers: annualPassengers,
      baselineEvasionRatePercent: baselineEvasionRatePercent,
      avgTicketFareRs: avgTicketFareRs,
      systemEfficiencyPercent: systemEfficiencyPercent,
      falsePositiveRatePercent: falsePositiveRatePercent,
    );
  }
}
