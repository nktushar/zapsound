import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:record/record.dart';
import '../services/recording_service.dart';
import '../services/audio_service.dart';
import '../services/preferences_service.dart';
import '../theme/app_theme.dart';

const int _kWaveformBars = 28;
const double _kMinDb = -45.0;

class RecordSoundScreen extends StatefulWidget {
  final bool isPlugIn;
  const RecordSoundScreen({super.key, required this.isPlugIn});

  @override
  State<RecordSoundScreen> createState() => _RecordSoundScreenState();
}

class _RecordSoundScreenState extends State<RecordSoundScreen> with SingleTickerProviderStateMixin {
  bool _recording = false;
  bool _playing = false;
  String? _recordedPath;
  String? _error;

  late final AnimationController _pulseController;
  StreamSubscription<Amplitude>? _amplitudeSub;
  final List<double> _levels = List.filled(_kWaveformBars, 0.0);

  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  String get _elapsedLabel {
    final m = _elapsedSeconds ~/ 60;
    final s = _elapsedSeconds % 60;
    return '${m.toString().padLeft(1, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _pushLevel(double v) {
    setState(() {
      _levels.removeAt(0);
      _levels.add(v);
    });
  }

  Future<void> _toggleRecord() async {
    if (_recording) {
      final path = await RecordingService.stop();
      _amplitudeSub?.cancel();
      _elapsedTimer?.cancel();
      setState(() {
        _recording = false;
        _recordedPath = path;
      });
      return;
    }
    if (!await RecordingService.hasPermission()) {
      setState(() => _error = 'Microphone permission is required to record.');
      return;
    }
    setState(() {
      _error = null;
      _recordedPath = null;
      _elapsedSeconds = 0;
      _levels.fillRange(0, _levels.length, 0.0);
    });
    await RecordingService.start();
    setState(() => _recording = true);

    _amplitudeSub = RecordingService.amplitudeStream().listen((amp) {
      final normalized = ((amp.current - _kMinDb) / (0 - _kMinDb)).clamp(0.0, 1.0);
      _pushLevel(normalized);
    });
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsedSeconds++);
    });
  }

  Future<void> _preview() async {
    if (_recordedPath == null) return;
    if (_playing) {
      await AudioService.stop();
      return;
    }
    setState(() => _playing = true);
    await AudioService.playFile(_recordedPath!);
    if (mounted) setState(() => _playing = false);
  }

  Future<void> _save() async {
    if (_recordedPath == null) return;
    final name = widget.isPlugIn ? 'custom_in' : 'custom_out';
    final finalPath = await RecordingService.saveAs(_recordedPath!, name);
    if (widget.isPlugIn) {
      await PrefsService.setCustomIn(finalPath);
      await PrefsService.setPlugIn('custom');
    } else {
      await PrefsService.setCustomOut(finalPath);
      await PrefsService.setPlugOut('custom');
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  void dispose() {
    if (_recording) RecordingService.stop();
    _amplitudeSub?.cancel();
    _elapsedTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isPlugIn ? 'Record Plug-in Sound' : 'Record Unplug Sound',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 220,
            height: 220,
            child: Stack(alignment: Alignment.center, children: [
              if (_recording)
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, __) {
                    final scale = 1.0 + _pulseController.value * 0.35;
                    final opacity = 1.0 - _pulseController.value;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red.withValues(alpha: opacity * 0.35),
                        ),
                      ),
                    );
                  },
                ),
              _buildWaveform(),
              GestureDetector(
                onTap: _toggleRecord,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _recording ? Colors.red : ZapColors.primary,
                    boxShadow: [
                      BoxShadow(
                        color: (_recording ? Colors.red : ZapColors.primary).withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    _recording ? Icons.stop_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: ZapTheme.space4),
          Text(
            _recording
                ? 'Recording $_elapsedLabel'
                : (_recordedPath == null ? 'Tap to record' : 'Recorded!'),
            style: const TextStyle(fontSize: ZapTheme.textMd, fontWeight: FontWeight.w600),
          ),
          if (_error != null) ...[
            const SizedBox(height: ZapTheme.space2),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: ZapTheme.textSm)),
          ],
          if (_recordedPath != null && !_recording) ...[
            const SizedBox(height: ZapTheme.space4),
            TextButton.icon(
              onPressed: _preview,
              icon: Icon(_playing ? Icons.stop_rounded : Icons.play_arrow_rounded),
              label: Text(_playing ? 'Playing...' : 'Preview'),
            ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.2, end: 0),
            const SizedBox(height: ZapTheme.space4),
            SizedBox(
              width: 200,
              height: 50,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ZapColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZapTheme.radiusLg)),
                ),
                child: const Text('Save & Use', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ).animate().fadeIn(duration: 250.ms, delay: 80.ms).slideY(begin: 0.2, end: 0),
          ],
        ]),
      ),
    );
  }

  Widget _buildWaveform() {
    if (!_recording) return const SizedBox.shrink();
    return SizedBox(
      width: 200,
      height: 200,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final level in _levels)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: 3,
                height: 16 + level * 84,
                decoration: BoxDecoration(
                  color: ZapColors.primaryLight.withValues(alpha: 0.35 + level * 0.65),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
