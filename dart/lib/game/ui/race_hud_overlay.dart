import 'package:flutter/widgets.dart';
import 'package:toy_racers/simulation.dart';

import 'game_controls.dart';
import 'race_ui_controller.dart';

/// Screen-space race instruments; the simulation remains the sole data owner.
final class RaceHudOverlay extends StatelessWidget {
  RaceHudOverlay({
    RaceUiController? controller,
    RaceUiController? game,
    this.showDesktopControls = false,
    super.key,
  }) : assert(controller != null || game != null),
       controller = controller ?? game!;

  final RaceUiController controller;
  final bool showDesktopControls;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller.presentationFrame,
    builder: (context, child) {
      return SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final state = controller.uiState;
            return constraints.maxWidth < _compactHudBreakpoint
                ? _compactHud(state)
                : _regularHud(state);
          },
        ),
      );
    },
  );

  Widget _regularHud(RaceUiState state) => Stack(
    children: <Widget>[
      Positioned(left: 18, top: 18, child: _positionPanel(state)),
      Positioned(
        top: 18,
        left: 0,
        right: 0,
        child: Center(child: _timingPanel(state)),
      ),
      Positioned(top: 18, right: 18, child: _pauseButton()),
      if (showDesktopControls)
        const Positioned(
          bottom: 12,
          left: 0,
          right: 0,
          child: Center(child: _DesktopControlsHint()),
        ),
    ],
  );

  Widget _compactHud(RaceUiState state) => Stack(
    children: <Widget>[
      Positioned(
        top: 8,
        left: 8,
        right: 8,
        child: Row(
          children: <Widget>[
            Expanded(
              child: _HudPanel(
                child: Text(
                  'POSITION ${state.position}/${state.competitorCount}  ·  '
                  'LAP ${state.displayedLap}/${state.requiredLaps}',
                  overflow: TextOverflow.ellipsis,
                  style: _valueStyle,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _pauseButton(),
          ],
        ),
      ),
      Positioned(
        top: 70,
        left: 8,
        right: 8,
        child: Center(child: _timingPanel(state)),
      ),
      if (showDesktopControls)
        const Positioned(
          bottom: 8,
          left: 0,
          right: 0,
          child: Center(child: _DesktopControlsHint(compact: true)),
        ),
    ],
  );

  Widget _positionPanel(RaceUiState state) => _HudPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('POSITION', style: _captionStyle),
        Text(
          '${state.position}/${state.competitorCount}',
          style: const TextStyle(
            color: Color(0xff8ed4ff),
            fontSize: 36,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'LAP ${state.displayedLap}/${state.requiredLaps}',
          style: _valueStyle,
        ),
      ],
    ),
  );

  Widget _timingPanel(RaceUiState state) => _HudPanel(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('TIME  ${_formatTime(state.totalRaceTime)}', style: _valueStyle),
        const SizedBox(height: 4),
        Text(
          'BEST  ${state.bestLapTime == null ? '--:--.---' : _formatTime(state.bestLapTime!)}',
          style: _captionStyle,
        ),
      ],
    ),
  );

  Widget _pauseButton() => GameActionButton(
    key: const ValueKey<String>('pause-race'),
    label: 'Ⅱ',
    secondary: true,
    onPressed: controller.togglePause,
  );

  String _formatTime(double seconds) {
    final milliseconds = (seconds.clamp(0, double.infinity) * 1000).floor();
    final minutes = milliseconds ~/ 60000;
    final secondsPart = milliseconds ~/ 1000 % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secondsPart.toString().padLeft(2, '0')}.${(milliseconds % 1000).toString().padLeft(3, '0')}';
  }
}

final class RaceCountdownOverlay extends StatelessWidget {
  RaceCountdownOverlay({
    RaceUiController? controller,
    RaceUiController? game,
    super.key,
  }) : assert(controller != null || game != null),
       controller = controller ?? game!;

  final RaceUiController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller.presentationFrame,
    builder: (context, child) {
      final state = controller.uiState;
      if (state.phase != RacePhase.countdown) {
        return const SizedBox.shrink();
      }
      final activeLight = state.countdownRemainingSeconds.floor().clamp(0, 2);
      return SafeArea(
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xae000000),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 30),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List<Widget>.generate(
                  3,
                  (index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: index == activeLight
                            ? const Color(0xfff2472f)
                            : const Color(0xff41454f),
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox(width: 44, height: 44),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

final class RacePauseOverlay extends StatelessWidget {
  RacePauseOverlay({
    RaceUiController? controller,
    RaceUiController? game,
    required this.onQuitToMenu,
    super.key,
  }) : assert(controller != null || game != null),
       controller = controller ?? game!;

  final RaceUiController controller;
  final VoidCallback onQuitToMenu;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xb8000008),
    child: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight > 36
                  ? constraints.maxHeight - 36
                  : 0,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 410),
                child: GamePanel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      gameHeading('PAUSED'),
                      const SizedBox(height: 18),
                      GameActionButton(
                        label: 'RESUME',
                        onPressed: controller.togglePause,
                      ),
                      const SizedBox(height: 10),
                      GameActionButton(
                        label: 'RESTART',
                        onPressed: controller.restartRace,
                      ),
                      const SizedBox(height: 10),
                      GameActionButton(
                        label: 'QUIT TO MENU',
                        secondary: true,
                        onPressed: onQuitToMenu,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

final class _HudPanel extends StatelessWidget {
  const _HudPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xe810141d),
      border: Border.all(color: const Color(0xff20b8ff)),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Padding(padding: const EdgeInsets.all(10), child: child),
  );
}

const TextStyle _captionStyle = TextStyle(
  color: Color(0xffc5d5e2),
  fontSize: 12,
  fontWeight: FontWeight.w700,
);

const TextStyle _valueStyle = TextStyle(
  color: Color(0xfff7f4e8),
  fontSize: 18,
  fontWeight: FontWeight.w800,
);

final class _DesktopControlsHint extends StatelessWidget {
  const _DesktopControlsHint({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xcc10141d),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      child: Text(
        compact
            ? 'WASD / ARROWS  ·  ESC PAUSE'
            : 'WASD / ARROWS  ·  ESC PAUSE  ·  R RESTART',
        style: TextStyle(
          color: const Color(0xffc5d5e2),
          fontSize: compact ? 10 : 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

const double _compactHudBreakpoint = 700;
