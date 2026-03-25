import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/presentation/widgets/image_picker_widget.dart';

void main() {
  testWidgets('ImagePickerWidget displays initial images', (tester) async {
    // Arrange
    final images = ['path/to/image1.jpg', 'path/to/image2.jpg'];

    // Act
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImagePickerWidget(
            initialImages: images,
            onImagesChanged: (_) {},
          ),
        ),
      ),
    );

    // Assert
    expect(find.text('Photos'), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    expect(find.byIcon(Icons.photo_library), findsOneWidget);
    
    // We expect 2 images (though Image.file will fail to load in test environment, 
    // the widgets should still be present in the tree)
    expect(find.byType(ClipRRect), findsNWidgets(2));
  });

  testWidgets('ImagePickerWidget shows empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImagePickerWidget(
            initialImages: const [],
            onImagesChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('No photos attached'), findsOneWidget);
  });
}
