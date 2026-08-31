import 'package:flutter/widgets.dart';
import 'package:toy_racers/simulation.dart';

import '../rendering/presentation_catalog.dart';
import 'game_controls.dart';
import 'track_selection_view.dart';

/// Lets players choose a bundled car sprite before creating a race session.
final class CarSelectionView extends StatelessWidget {
  const CarSelectionView({
    required this.selected,
    required this.onSelected,
    required this.onStart,
    required this.onBack,
    super.key,
  });

  final CarModel selected;
  final ValueChanged<CarModel> onSelected;
  final VoidCallback onStart;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => SelectionBackground(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = ((constraints.maxWidth - 76) / CarModel.values.length)
            .clamp(112, 184)
            .toDouble();
        return GamePanel(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              gameHeading('SELECT CAR'),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: CarModel.values
                    .map((model) => _carCard(model, cardWidth))
                    .toList(growable: false),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: GameActionButton(
                      label: 'BACK',
                      secondary: true,
                      onPressed: onBack,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GameActionButton(
                      key: const ValueKey<String>('start-race'),
                      label: 'START RACE',
                      onPressed: onStart,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );

  Widget _carCard(CarModel model, double width) {
    final isSelected = model == selected;
    return Semantics(
      button: true,
      selected: isSelected,
      label: model.displayName,
      child: GestureDetector(
        key: ValueKey<String>('car-${model.scenarioId}'),
        onTap: () => onSelected(model),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xff174b78)
                : const Color(0xff172331),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? const Color(0xff8ed4ff)
                  : const Color(0xff43566b),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: SizedBox(
            width: width,
            height: width * 1.48,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: Image.asset(model.spriteAsset, fit: BoxFit.contain),
                  ),
                  Text(
                    model.displayName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xfff7f4e8),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _performance('ACCEL', model.performance.acceleration),
                  _performance('SPEED', model.performance.maxSpeed),
                  _performance('HANDLE', model.performance.handling),
                  const SizedBox(height: 6),
                  Text(
                    isSelected ? 'SELECTED' : 'SELECT',
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xff8ed4ff)
                          : const Color(0xffc5d5e2),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _performance(String label, double multiplier) {
    final filled = (1 + ((multiplier - 0.8) / 0.3 * 4).round()).clamp(1, 5);
    return SizedBox(
      height: 12,
      child: FittedBox(
        alignment: Alignment.centerLeft,
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 46,
              child: Text(
                label,
                style: const TextStyle(color: Color(0xffc5d5e2), fontSize: 9),
              ),
            ),
            ...List<Widget>.generate(
              5,
              (index) => Padding(
                padding: const EdgeInsets.only(left: 3),
                child: ColoredBox(
                  color: index < filled
                      ? const Color(0xfff5ad2e)
                      : const Color(0xff3c4856),
                  child: const SizedBox(width: 13, height: 8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
