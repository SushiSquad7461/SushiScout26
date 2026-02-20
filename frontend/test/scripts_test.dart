import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Flutter scripts', () {
    final scriptsDir = Directory('scripts/flutter');

    test('scripts directory exists', () {
      expect(scriptsDir.existsSync(), isTrue);
    });

    test('Windows build script exists', () {
      final file = File('${scriptsDir.path}/build_windows.bat');
      expect(file.existsSync(), isTrue);
    });

    test('Windows run script exists', () {
      final file = File('${scriptsDir.path}/run_windows.bat');
      expect(file.existsSync(), isTrue);
    });

    test('Android build script exists', () {
      final file = File('${scriptsDir.path}/build_android.bat');
      expect(file.existsSync(), isTrue);
    });

    test('Android run script exists', () {
      final file = File('${scriptsDir.path}/run_android.bat');
      expect(file.existsSync(), isTrue);
    });

    test('Linux build script exists', () {
      final file = File('${scriptsDir.path}/build_linux.bat');
      expect(file.existsSync(), isTrue);
    });

    test('Linux run script exists', () {
      final file = File('${scriptsDir.path}/run_linux.bat');
      expect(file.existsSync(), isTrue);
    });

    test('macOS build script exists', () {
      final file = File('${scriptsDir.path}/build_macos.sh');
      expect(file.existsSync(), isTrue);
    });

    test('macOS run script exists', () {
      final file = File('${scriptsDir.path}/run_macos.sh');
      expect(file.existsSync(), isTrue);
    });

    test('iOS build script exists', () {
      final file = File('${scriptsDir.path}/build_ios.sh');
      expect(file.existsSync(), isTrue);
    });

    test('iOS run script exists', () {
      final file = File('${scriptsDir.path}/run_ios.sh');
      expect(file.existsSync(), isTrue);
    });

    test('build scripts contain flutter build command', () async {
      final buildScripts = [
        'build_windows.bat',
        'build_android.bat',
        'build_linux.bat',
        'build_macos.sh',
        'build_ios.sh',
      ];

      for (final scriptName in buildScripts) {
        final file = File('${scriptsDir.path}/$scriptName');
        final content = await file.readAsString();
        expect(content, contains('flutter build'));
      }
    });

    test('run scripts contain flutter run command', () async {
      final runScripts = [
        'run_windows.bat',
        'run_android.bat',
        'run_linux.bat',
        'run_macos.sh',
        'run_ios.sh',
      ];

      for (final scriptName in runScripts) {
        final file = File('${scriptsDir.path}/$scriptName');
        final content = await file.readAsString();
        expect(content, contains('flutter run'));
      }
    });
  });
}
