import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/gluconav_colors.dart';
import '../../models/sequence_result.dart';
import '../../services/gluconav_api_service.dart';
import 'sequence_overlay_screen.dart';

/// L6.1 / I1.1 — Camera screen.
///
/// - image_picker: camera capture OR gallery pick (gallery-only on web)
/// - Calls real `analyzeImageBytes()` which POSTs to `/api/v1/analyze-meal`
///   and falls back to mock JSON if backend is unreachable.
/// - Shows linear progress + status text during upload
enum CameraScanMode { meal, glucometer }

class CameraScreen extends StatefulWidget {
  final CameraScanMode mode;
  const CameraScreen({super.key, this.mode = CameraScanMode.meal});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final _picker = ImagePicker();
  final _api = GlucoNavApiService();

  Uint8List? _imageBytes;
  bool _loading = false;
  String _statusText = 'Detecting foods…';
  String? _error;

  // ── Pick image ─────────────────────────────────────────────────────────────

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1080,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Could not access camera/gallery: $e');
    }
  }

  // ── Analyse meal — I1.1 real API ──────────────────────────────────────────

  Future<void> _analyse() async {
    if (_imageBytes == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _statusText = 'Uploading image…';
    });

    if (widget.mode == CameraScanMode.glucometer) {
      await _analyseGlucometer();
    } else {
      await _analyseMeal();
    }
  }

  Future<void> _analyseMeal() async {
    try {
      setState(() => _statusText = 'Detecting foods with AI…');
      final result = await _api.analyzeImageBytes(_imageBytes!);

      setState(() => _statusText = 'Building eating sequence…');
      await Future.delayed(const Duration(milliseconds: 200)); // brief pause

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SequenceOverlayScreen(
            imageBytes: _imageBytes!,
            result: result,
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = 'Analysis failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _analyseGlucometer() async {
    try {
      setState(() => _statusText = 'Reading your glucometer…');
      final glucoseValue = await _api.analyzeGlucometerBytes(_imageBytes!);
      if (!mounted) return;
      if (glucoseValue != null) {
        Navigator.pop(context); // go back to wherever camera was opened from
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📊 Glucose logged: ${glucoseValue.round()} mg/dL'),
            backgroundColor: GlucoNavColors.primary,
            duration: const Duration(seconds: 4),
          ),
        );
        // The BLoC will pick it up on its 10s pulse automatically
      } else {
        setState(() => _error = 'Could not read glucometer. Try a clearer photo.');
      }
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GlucoNavColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.mode == CameraScanMode.glucometer ? 'Log Glucometer' : 'Scan My Plate',
          style: const TextStyle(
              color: GlucoNavColors.primary, fontWeight: FontWeight.bold),
        ),
        leading: const BackButton(color: GlucoNavColors.primary),
        actions: [
          IconButton(
            icon: Icon(
              widget.mode == CameraScanMode.glucometer ? Icons.restaurant : Icons.monitor_heart,
              color: GlucoNavColors.primary,
            ),
            tooltip: widget.mode == CameraScanMode.glucometer ? 'Switch to Meal Scan' : 'Switch to Glucometer',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => CameraScreen(
                    mode: widget.mode == CameraScanMode.glucometer
                        ? CameraScanMode.meal
                        : CameraScanMode.glucometer,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Image preview
              Expanded(
                child: _imageBytes != null
                    ? _ImagePreview(bytes: _imageBytes!)
                    : _EmptyPlaceholder(mode: widget.mode),
              ),

              const SizedBox(height: 20),

              // Error
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: GlucoNavColors.spikeHigh, fontSize: 12)),
                ),

              // Loading
              if (_loading) ...[
                const LinearProgressIndicator(
                    color: GlucoNavColors.primary,
                    backgroundColor: GlucoNavColors.surfaceVariant),
                const SizedBox(height: 10),
                Text(_statusText,
                    style: const TextStyle(
                        color: GlucoNavColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 12),
              ],

              // Action buttons
              if (!_loading) ...[
                Row(
                  children: [
                    Expanded(
                      child: _PickButton(
                        icon: Icons.photo_library_outlined,
                        label: 'Gallery',
                        onTap: () => _pick(ImageSource.gallery),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PickButton(
                        icon: Icons.camera_alt_outlined,
                        label: kIsWeb ? 'Gallery' : 'Camera',
                        onTap: () => _pick(
                            kIsWeb ? ImageSource.gallery : ImageSource.camera),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (_imageBytes != null)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _analyse,
                      icon: const Icon(Icons.auto_awesome, color: Colors.white),
                      label: Text(
                        widget.mode == CameraScanMode.glucometer ? 'Read Glucose →' : 'Analyse My Plate →',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GlucoNavColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _ImagePreview extends StatelessWidget {
  final Uint8List bytes;
  const _ImagePreview({required this.bytes});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.memory(bytes, fit: BoxFit.cover, width: double.infinity),
      );
}

class _EmptyPlaceholder extends StatelessWidget {
  final CameraScanMode mode;
  const _EmptyPlaceholder({required this.mode});
  @override
  Widget build(BuildContext context) {
    if (mode == CameraScanMode.glucometer) {
      return Container(
        decoration: BoxDecoration(
          color: GlucoNavColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: GlucoNavColors.primary.withOpacity(0.3)),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.monitor_heart, size: 72, color: GlucoNavColors.primary),
              SizedBox(height: 16),
              Text('📸 Take a clear photo of your glucometer display',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: GlucoNavColors.textSecondary, fontSize: 14)),
              SizedBox(height: 6),
              Text(
                "we'll read the glucose value automatically.",
                textAlign: TextAlign.center,
                style: TextStyle(color: GlucoNavColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
        decoration: BoxDecoration(
          color: GlucoNavColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: GlucoNavColors.primary.withOpacity(0.3)),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.restaurant_menu, size: 72, color: GlucoNavColors.primary),
              SizedBox(height: 16),
              Text('Pick or photograph your meal',
                  style: TextStyle(color: GlucoNavColors.textSecondary, fontSize: 14)),
              SizedBox(height: 6),
              Text(
                'GlucoNav will detect foods and suggest\nthe optimal eating order',
                textAlign: TextAlign.center,
                style: TextStyle(color: GlucoNavColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      );
  }
}

class _PickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PickButton({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: GlucoNavColors.primary, size: 18),
        label: Text(label,
            style: const TextStyle(
                color: GlucoNavColors.primary, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: GlucoNavColors.primary),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
}
