import 'package:flutter/material.dart';
import '../services/recording_service.dart';
import '../services/audio_service.dart';
import '../services/preferences_service.dart';
import '../theme/app_theme.dart';

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

  Future<void> _toggleRecord() async {
    if (_recording) {
      final path = await RecordingService.stop();
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
    });
    await RecordingService.start();
    setState(() => _recording = true);
  }

  Future<void> _preview() async {
    if (_recordedPath == null) return;
    setState(() => _playing = true);
    await AudioService.playFile(_recordedPath!);
    await Future.delayed(const Duration(seconds: 3));
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
          GestureDetector(
            onTap: _toggleRecord,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _recording ? Colors.red : ZapColors.primary,
              ),
              child: Icon(
                _recording ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
          const SizedBox(height: ZapTheme.space4),
          Text(
            _recording
                ? 'Recording... tap to stop'
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
            ),
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
            ),
          ],
        ]),
      ),
    );
  }
}
