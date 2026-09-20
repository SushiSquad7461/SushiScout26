import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/presentation/widgets/scouting_form_widget.dart';

void main() {
  group('ScoutingWizardBottomSlot', () {
    testWidgets('renders at the fixed slot width regardless of child size', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                ScoutingWizardBottomSlot(child: Text('back')),
                ScoutingWizardBottomSlot(
                  child: FilledButton(onPressed: null, child: Text('submit')),
                ),
              ],
            ),
          ),
        ),
      );

      final sizes = tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .where((box) => box.width == kWizardBottomBarSlotWidth)
          .toList();

      expect(sizes.length, 2);
    });
  });
}
