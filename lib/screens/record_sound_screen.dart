import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import '../services/recording_service.dart';
import '../services/audio_service.dart';
import '../services/preferences_service.dart';
import '../theme/app_theme.dart';
import '../widgets/sound_widgets.dart';

const int _kWaveformBars = 36;
const double _kMinDb = -45.0;
const int _kMaxSeconds = 10;

class RecordSoundScreen extends StatefulWidget {
  final bool isPlugIn;
  const RecordSoundScreen({super.key, required this.isPlugIn});

  @override
  State<RecordSoundScreen> createState() => _RecordSoundScreenState();
}

class _RecordSoundScreenState extends State<RecordSoundScreen> {
  bool _recording = false;
  bool _playing = false;
  String? _recordedPath;
  String? _error;

  StreamSubscription<Amplitude>? _amplitudeSub;
  final List<double> _levels = List.filled(_kWaveformBars, 0.0);

  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;

  String get _elapsedLabel => '0:${_elapsedSeconds.toString().padLeft(2, '0')}';

  void _pushLevel(double v) {
    setState(() {
      _levels.removeAt(0);
      _levels.add(v);
    });
  }

  Future<void> _stopRecording() async {
    final path = await RecordingService.stop();
    _amplitudeSub?.cancel();
    _elapsedTimer?.cancel();
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() {
      _recording = false;
      _recordedPath = path;
    });
  }

  Future<void> _toggleRecord() async {
    if (_recording) return _stopRecording();
    if (_playing) await AudioService.stop();
    if (!await RecordingService.hasPermission()) {
      setState(() => _error = 'ZapSound needs microphone access to record. Allow it in your phone\'s app settings.');
      return;
    }
    HapticFeedback.mediumImpact();
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
      if (_elapsedSeconds >= _kMaxSeconds) _stopRecording();
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
      await PrefsService.setPlugInFile('custom');
    } else {
      await PrefsService.setCustomOut(finalPath);
      await PrefsService.setPlugOut('custom');
      await PrefsService.setPlugOutFile('custom');
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  void dispose() {
    if (_recording) RecordingService.stop();
    if (_playing) AudioService.stop();
    _amplitudeSub?.cancel();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final z = context.zap;
    final hasTake = _recordedPath != null && !_recording;
    final status = _recording
        ? 'Recording — tap to stop'
        : hasTake
            ? 'Listen back, then save or record again'
            : 'Tap the button and make your sound';

    return Scaffold(
      appBar: AppBar(title: Text(widget.isPlugIn ? 'Record plug-in sound' : 'Record unplug sound')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(ZapTheme.space5, ZapTheme.space2, ZapTheme.space5, ZapTheme.space5),
          child: Column(children: [
            Text(
              'Short and sharp works best — one to three seconds. Recording stops at $_kMaxSeconds seconds.',
              style: TextStyle(fontSize: ZapTheme.textSm, color: z.inkMuted, height: 1.45),
            ),
            const Spacer(),
            Text(
              _elapsedLabel,
              style: zapDisplay(72, weight: FontWeight.w700, color: _recording ? z.danger : z.ink, height: 1)
                  .copyWith(fontFeatures: ZapTheme.tabular),
            ),
            const SizedBox(height: ZapTheme.space5),
            SizedBox(height: 96, child: _buildWaveform(z)),
            const SizedBox(height: ZapTheme.space5),
            AnimatedSwitcher(
              duration: ZapTheme.fast,
              child: Text(status,
                  key: ValueKey(status),
                  style: TextStyle(fontSize: ZapTheme.textSm, fontWeight: FontWeight.w600, color: z.inkMuted)),
            ),
            if (_error != null) ...[
              const SizedBox(height: ZapTheme.space3),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: z.danger, fontSize: ZapTheme.textSm, height: 1.4)),
            ],
            const Spacer(),

            // Controls: play back · record/stop · (balance)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              SizedBox(
                width: 72,
                child: AnimatedOpacity(
                  duration: ZapTheme.fast,
                  opacity: hasTake ? 1 : 0,
                  child: IgnorePointer(
                    ignoring: !hasTake,
                    child: PlayButton(playing: _playing, onPressed: _preview, size: 52),
                  ),
                ),
              ),
              const SizedBox(width: ZapTheme.space5),
              _RecordButton(recording: _recording, onTap: _toggleRecord),
              const SizedBox(width: ZapTheme.space5),
              const SizedBox(width: 72),
            ]),
            const SizedBox(height: ZapTheme.space6),
            AnimatedSize(
              duration: ZapTheme.medium,
              curve: ZapTheme.emphasized,
              child: hasTake
                  ? ZapPrimaryButton(label: 'Use this sound', icon: Icons.check_rounded, onPressed: _save)
                  : const SizedBox(width: double.infinity, height: 54),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildWaveform(ZapTokens z) {
    // Bars take the color of the moment being recorded for.
    final hue = widget.isPlugIn ? z.charge : z.release;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final level in _levels)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              width: 4,
              height: 6 + level * 90,
              decoration: BoxDecoration(
                color: _recording ? Color.lerp(z.surfaceHigh, hue.strong, 0.35 + level * 0.65) : z.surfaceHigh,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
      ],
    );
  }
}

class _RecordButton extends StatelessWidget {
  final bool recording;
  final VoidCallback onTap;
  const _RecordButton({required this.recording, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final z = context.zap;
    return Semantics(
      button: true,
      label: recording ? 'Stop recording' : 'Start recording',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 84,
          height: 84,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: z.surfaceHigh, width: 4)),
          child: Center(
            child: AnimatedContainer(
              duration: ZapTheme.medium,
              curve: ZapTheme.emphasized,
              width: recording ? 30 : 68,
              height: recording ? 30 : 68,
              decoration: BoxDecoration(
                color: z.danger,
                borderRadius: BorderRadius.circular(recording ? 8 : 34),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
