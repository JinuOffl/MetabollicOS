import 'package:flutter/material.dart';

/// GlucoNav brand colour palette — Apple-inspired teal theme.
class GlucoNavColors {
  GlucoNavColors._();

  static const Color primary        = Color(0xFF0F6E56);
  static const Color secondary      = Color(0xFF1D9E75);
  static const Color background     = Color(0xFFF8FFFE);
  static const Color spikeHigh      = Color(0xFFE24B4A);
  static const Color spikeLow       = Color(0xFF0F6E56);
  static const Color textPrimary    = Color(0xFF1A1A2E);
  static const Color textSecondary  = Color(0xFF6B7280);
  static const Color card           = Colors.white;
  static const Color surfaceVariant = Color(0xFFF0FBF7);

  // Coach-mode accent colours
  static const Color activeAccent      = Color(0xFF0F6E56); // teal
  static const Color balancedAccent    = Color(0xFF2563EB); // calm blue
  static const Color supportiveAccent  = Color(0xFF7C3AED); // soft purple

  /// Returns the accent colour for the given coach mode string.
  static Color forCoachMode(String mode) {
    switch (mode) {
      case 'supportive': return supportiveAccent;
      case 'balanced':   return balancedAccent;
      default:           return activeAccent;
    }
  }

  /// Returns a spike risk colour.
  static Color forSpikeRisk(String risk) {
    switch (risk) {
      case 'high':   return spikeHigh;
      case 'medium': return const Color(0xFFEA8C00); // amber
      default:       return spikeLow;
    }
  }
}
