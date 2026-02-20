import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Web support removal', () {
    test('web directory does not exist', () {
      final webDir = Directory('frontend/web');
      expect(webDir.existsSync(), isFalse);
    });

    test('start_hot_reload.bat does not exist', () {
      final file = File('start_hot_reload.bat');
      expect(file.existsSync(), isFalse);
    });

    test('web.dart database connection does not exist', () {
      final file = File('frontend/lib/data/local/database/connection/web.dart');
      expect(file.existsSync(), isFalse);
    });

    test('firebase_options.dart does not contain kIsWeb', () async {
      final file = File('frontend/lib/firebase_options.dart');
      final content = await file.readAsString();
      expect(content.contains('kIsWeb'), isFalse);
    });

    test('firebase_options.dart does not contain web constant', () async {
      final file = File('frontend/lib/firebase_options.dart');
      final content = await file.readAsString();
      expect(content.contains('static const FirebaseOptions web'), isFalse);
    });

    test('app_database.dart does not import web.dart', () async {
      final file = File('frontend/lib/data/local/database/app_database.dart');
      final content = await file.readAsString();
      expect(content.contains('connection/web.dart'), isFalse);
    });
  });
}
