import 'package:flutter/widgets.dart';
import 'package:toy_racers/simulation.dart';

import 'game_controls.dart';

/// Displays authored track images as the playable track choices.
final class TrackSelectionView extends StatelessWidget {
  const TrackSelectionView({
    required this.onSelected,
    required this.onBack,
    super.key,
  });

  final ValueChanged<TrackId> onSelected;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => SelectionBackground(
    child: GamePanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          gameHeading('SELECT TRACK'),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: Row(
              children: <Widget>[
                Expanded(child: _trackCard(TrackId.livingRoom)),
                const SizedBox(width: 20),
                Expanded(child: _trackCard(TrackId.bathroom)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: 240,
            child: GameActionButton(
              label: 'BACK',
              secondary: true,
              onPressed: onBack,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _trackCard(TrackId track) => GameActionTarget(
    key: ValueKey<String>('track-${track.id}'),
    semanticLabel: track.displayName,
    onPressed: () => onSelected(track),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xff172331),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xff8ed4ff).withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: <Widget>[
            Expanded(
              child: Image.asset(_previewAsset(track), fit: BoxFit.contain),
            ),
            const SizedBox(height: 10),
            gameHeading(track.displayName, size: 20),
          ],
        ),
      ),
    ),
  );

  String _previewAsset(TrackId track) => switch (track) {
    TrackId.livingRoom => 'assets/tracks/track_01.png',
    TrackId.bathroom => 'assets/tracks/track_02.png',
  };
}

final class SelectionBackground extends StatelessWidget {
  const SelectionBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xff121e2e),
    child: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight > 48
                  ? constraints.maxHeight - 48
                  : 0,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: child,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
