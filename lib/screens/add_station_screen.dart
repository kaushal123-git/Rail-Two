import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/station.dart';
import '../services/s2_service.dart';

class AddStationScreen extends StatefulWidget {
  final Position? currentUserPosition;

  const AddStationScreen({super.key, required this.currentUserPosition});

  @override
  State<AddStationScreen> createState() => _AddStationScreenState();
}

class _AddStationScreenState extends State<AddStationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  String _previewS2Token = '';
  String _previewS2CellId = '';

  @override
  void initState() {
    super.initState();
    _latController.addListener(_updateS2Preview);
    _lngController.addListener(_updateS2Preview);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  void _updateS2Preview() {
    final latVal = double.tryParse(_latController.text);
    final lngVal = double.tryParse(_lngController.text);

    if (latVal != null && lngVal != null && 
        latVal >= -90 && latVal <= 90 && 
        lngVal >= -180 && lngVal <= 180) {
      final token = S2Service.getCellToken(latVal, lngVal);
      final cellId = S2Service.getCellIdString(latVal, lngVal);
      setState(() {
        _previewS2Token = token;
        _previewS2CellId = cellId;
      });
    } else {
      setState(() {
        _previewS2Token = '';
        _previewS2CellId = '';
      });
    }
  }

  void _autofillCurrentLocation() {
    if (widget.currentUserPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current GPS coordinates not available. Check your location status.')),
      );
      return;
    }

    setState(() {
      _latController.text = widget.currentUserPosition!.latitude.toStringAsFixed(6);
      _lngController.text = widget.currentUserPosition!.longitude.toStringAsFixed(6);
    });
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) return;

    final lat = double.parse(_latController.text);
    final lng = double.parse(_lngController.text);
    
    // Create unique ID from name
    final id = 'custom_${_nameController.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}_${DateTime.now().millisecondsSinceEpoch}';

    final station = RailwayStation(
      id: id,
      name: _nameController.text.trim(),
      latitude: lat,
      longitude: lng,
    );

    Navigator.pop(context, station);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ADD NEW STATION'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Text(
                  'REGISTER STATION DETAILS',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: theme.colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 20),

                // Station Name
                TextFormField(
                  controller: _nameController,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the station name';
                    }
                    return null;
                  },
                  decoration: _buildInputDecoration(
                    hint: 'e.g. Pune Central Junction',
                    label: 'Station Name',
                    icon: Icons.title,
                    theme: theme,
                  ),
                ),
                const SizedBox(height: 20),

                // Coordinates Row
                Row(
                  children: [
                    // Latitude
                    Expanded(
                      child: TextFormField(
                        controller: _latController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter Latitude';
                          }
                          final num = double.tryParse(value);
                          if (num == null || num < -90 || num > 90) {
                            return 'Must be -90 to 90';
                          }
                          return null;
                        },
                        decoration: _buildInputDecoration(
                          hint: '28.6418',
                          label: 'Latitude',
                          icon: Icons.explore_outlined,
                          theme: theme,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Longitude
                    Expanded(
                      child: TextFormField(
                        controller: _lngController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter Longitude';
                          }
                          final num = double.tryParse(value);
                          if (num == null || num < -180 || num > 180) {
                            return 'Must be -180 to 180';
                          }
                          return null;
                        },
                        decoration: _buildInputDecoration(
                          hint: '77.2192',
                          label: 'Longitude',
                          icon: Icons.explore_outlined,
                          theme: theme,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Autofill location button
                OutlinedButton.icon(
                  icon: const Icon(Icons.gps_fixed),
                  label: const Text('Autofill Current Coordinates'),
                  onPressed: _autofillCurrentLocation,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: theme.colorScheme.secondary.withValues(alpha: 0.5)),
                    foregroundColor: theme.colorScheme.secondary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 30),

                // Real-time S2 preview panel
                if (_previewS2Token.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.colorScheme.secondary.withValues(alpha: 0.3), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'S2 GEOMETRY PREVIEW',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.tealAccent,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('S2 Cell Token:', style: TextStyle(color: Colors.white70)),
                            Text(
                              _previewS2Token,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                color: Colors.tealAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('S2 Cell ID:', style: TextStyle(color: Colors.white38, fontSize: 11)),
                            Text(
                              _previewS2CellId,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],

                // Submit Button
                ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shadowColor: theme.colorScheme.primary.withValues(alpha: 0.4),
                    elevation: 8,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'SAVE STATION TO JSON',
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required String label,
    required IconData icon,
    required ThemeData theme,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.white54),
      filled: true,
      fillColor: theme.cardTheme.color,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: const TextStyle(color: Colors.white24),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: theme.colorScheme.secondary.withValues(alpha: 0.5), width: 1),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5), width: 1),
      ),
    );
  }
}
