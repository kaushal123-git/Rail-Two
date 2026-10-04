import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../core/theme/loco_theme.dart';
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
  String _selectedLine = 'Western';

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
      if (_previewS2Token.isNotEmpty || _previewS2CellId.isNotEmpty) {
        setState(() {
          _previewS2Token = '';
          _previewS2CellId = '';
        });
      }
    }
  }

  void _fillCurrentLocation() {
    if (widget.currentUserPosition != null) {
      _latController.text = widget.currentUserPosition!.latitude.toStringAsFixed(6);
      _lngController.text = widget.currentUserPosition!.longitude.toStringAsFixed(6);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current GPS position unavailable. Please check location permissions.')),
      );
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text.trim();
      final lat = double.parse(_latController.text.trim());
      final lng = double.parse(_lngController.text.trim());

      final id = name.toLowerCase().replaceAll(RegExp(r'\s+'), '-');
      final newStation = RailwayStation(
        id: id,
        name: name,
        latitude: lat,
        longitude: lng,
        line: _selectedLine,
      );

      Navigator.pop(context, newStation);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Add Custom Station', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create Spatial Station Node',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: LocoColors.textPrimary),
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter station name and GPS coordinates. Google S2 geometry cell tokens will be computed in real-time.',
                style: TextStyle(fontSize: 13, color: LocoColors.textSecondary),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Station Name',
                  hintText: 'e.g. Bandra Terminus',
                  prefixIcon: Icon(Icons.train_outlined, color: LocoColors.orange),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 16),

              // Railway Line selector
              DropdownButtonFormField<String>(
                value: _selectedLine,
                decoration: const InputDecoration(
                  labelText: 'Railway Line',
                  prefixIcon: Icon(Icons.alt_route, color: LocoColors.orange),
                ),
                items: const [
                  DropdownMenuItem(value: 'Western', child: Text('Western Railway')),
                  DropdownMenuItem(value: 'Central', child: Text('Central Railway')),
                  DropdownMenuItem(value: 'Harbour', child: Text('Harbour Railway')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedLine = val);
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _latController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(
                  labelText: 'Latitude',
                  hintText: 'e.g. 19.054817',
                  prefixIcon: Icon(Icons.location_on_outlined, color: LocoColors.orange),
                ),
                validator: (val) {
                  final v = double.tryParse(val ?? '');
                  if (v == null || v < -90 || v > 90) return 'Valid latitude required (-90 to 90)';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _lngController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(
                  labelText: 'Longitude',
                  hintText: 'e.g. 72.840666',
                  prefixIcon: Icon(Icons.location_on_outlined, color: LocoColors.orange),
                ),
                validator: (val) {
                  final v = double.tryParse(val ?? '');
                  if (v == null || v < -180 || v > 180) return 'Valid longitude required (-180 to 180)';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              OutlinedButton.icon(
                onPressed: _fillCurrentLocation,
                icon: const Icon(Icons.my_location, size: 18, color: LocoColors.orange),
                label: const Text('Use Current GPS Location'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),

              const SizedBox(height: 24),

              // S2 Preview Card
              if (_previewS2Token.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: LocoColors.orangeLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: LocoColors.orange.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.hub_outlined, color: LocoColors.orange, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'LIVE S2 GEOMETRY CELL PREVIEW',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: LocoColors.orange,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('S2 Cell Token:', style: TextStyle(fontSize: 13, color: LocoColors.textSecondary)),
                          Text(
                            _previewS2Token,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: LocoColors.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('S2 64-bit ID:', style: TextStyle(fontSize: 12, color: LocoColors.textMuted)),
                          Text(
                            _previewS2CellId,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: LocoColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LocoColors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('SAVE STATION TO LOCO', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
