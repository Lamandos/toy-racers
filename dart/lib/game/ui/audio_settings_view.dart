import 'package:flutter/widgets.dart';

import '../../audio/audio_settings.dart';
import 'game_controls.dart';

/// In-memory presentation controls matching the reference audio preferences.
final class AudioSettingsView extends StatelessWidget {
  const AudioSettingsView({
    required this.settings,
    required this.onChanged,
    required this.onBack,
    super.key,
  });

  final AudioSettings settings;
  final ValueChanged<AudioSettings> onChanged;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => SelectionBackground(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: GamePanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            gameHeading('AUDIO SETTINGS'),
            const SizedBox(height: 22),
            _VolumeRow(
              key: const ValueKey<String>('master-volume'),
              label: 'MASTER',
              value: settings.masterVolume,
              onChanged: (value) =>
                  onChanged(settings.copyWith(masterVolume: value)),
            ),
            const SizedBox(height: 14),
            _VolumeRow(
              key: const ValueKey<String>('music-volume'),
              label: 'MUSIC',
              value: settings.musicVolume,
              onChanged: (value) =>
                  onChanged(settings.copyWith(musicVolume: value)),
            ),
            const SizedBox(height: 14),
            _VolumeRow(
              key: const ValueKey<String>('sfx-volume'),
              label: 'SFX',
              value: settings.sfxVolume,
              onChanged: (value) =>
                  onChanged(settings.copyWith(sfxVolume: value)),
            ),
            const SizedBox(height: 26),
            GameActionButton(label: 'BACK', secondary: true, onPressed: onBack),
          ],
        ),
      ),
    ),
  );
}

final class _VolumeRow extends StatelessWidget {
  const _VolumeRow({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      SizedBox(width: 86, child: Text(label, style: _labelStyle)),
      _adjustment(
        key: ValueKey<String>('$label-volume-down'),
        label: 'Decrease $label volume',
        symbol: '−',
        nextValue: _decrease,
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _VolumeMeter(value: value),
        ),
      ),
      _adjustment(
        key: ValueKey<String>('$label-volume-up'),
        label: 'Increase $label volume',
        symbol: '+',
        nextValue: _increase,
      ),
      SizedBox(
        width: 52,
        child: Text(
          '${(value * 100).round()}%',
          textAlign: TextAlign.end,
          style: _labelStyle,
        ),
      ),
    ],
  );

  Widget _adjustment({
    required Key key,
    required String label,
    required String symbol,
    required double Function() nextValue,
  }) => GameActionTarget(
    key: key,
    semanticLabel: label,
    onPressed: () => onChanged(nextValue()),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xff2463a2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: SizedBox(
        width: 38,
        height: 36,
        child: Center(child: Text(symbol, style: _buttonStyle)),
      ),
    ),
  );

  double _decrease() => (value - _volumeStep).clamp(0, 1).toDouble();
  double _increase() => (value + _volumeStep).clamp(0, 1).toDouble();
}

final class _VolumeMeter extends StatelessWidget {
  const _VolumeMeter({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xff303846),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: value,
        child: const DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0xff20b8ff),
            borderRadius: BorderRadius.all(Radius.circular(6)),
          ),
          child: SizedBox(height: 14),
        ),
      ),
    ),
  );
}

const double _volumeStep = 0.1;
const TextStyle _labelStyle = TextStyle(
  color: Color(0xfff7f4e8),
  fontWeight: FontWeight.w800,
);
const TextStyle _buttonStyle = TextStyle(
  color: Color(0xfff7f4e8),
  fontSize: 24,
  fontWeight: FontWeight.w800,
);
