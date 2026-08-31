import 'package:flutter/widgets.dart';
import 'package:toy_racers/simulation.dart';

import '../rendering/presentation_catalog.dart';
import 'game_controls.dart';

/// Displays authored track images as the playable track choices.
final class TrackSelectionView extends StatelessWidget {
  const TrackSelectionView({
    this.selectedCar = CarModel.redStripe,
    required this.onSelected,
    required this.onBack,
    super.key,
  });

  final CarModel selectedCar;
  final ValueChanged<TrackId> onSelected;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => SelectionBackground(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final isStacked = constraints.maxWidth < _twoColumnBreakpoint;
        final cardWidth = isStacked
            ? constraints.maxWidth
            : (constraints.maxWidth - _trackCardGap) / 2;
        final cardHeight = (cardWidth * 0.68)
            .clamp(_minimumCardHeight, _maximumCardHeight)
            .toDouble();
        return GamePanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              gameHeading('SELECT TRACK'),
              const SizedBox(height: 6),
              Text(
                'CAR · ${selectedCar.displayName}',
                style: const TextStyle(
                  color: Color(0xffc5d5e2),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: _trackCardGap,
                runSpacing: _trackCardGap,
                children: TrackId.values
                    .map(
                      (track) => SizedBox(
                        width: cardWidth,
                        height: cardHeight,
                        child: _trackCard(track),
                      ),
                    )
                    .toList(growable: false),
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
        );
      },
    ),
  );

  Widget _trackCard(TrackId track) => GameActionTarget(
    key: ValueKey<String>('track-${track.id}'),
    semanticLabel: 'Start ${track.displayName}',
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

const double _twoColumnBreakpoint = 720;
const double _trackCardGap = 20;
const double _minimumCardHeight = 180;
const double _maximumCardHeight = 300;

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
