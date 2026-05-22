import 'dart:io';

void main() {
  // Load environment manually since we are in bin
  final envFile = File('.env');
  if (envFile.existsSync()) {
    final lines = envFile.readAsLinesSync();
    for (final line in lines) {
      if (line.trim().isEmpty || line.startsWith('#')) continue;
      final parts = line.split('=');
      if (parts.length >= 2) {
        // Set to environment
        // Unfortunately Platform.environment is immutable in Dart, but we can set it via Env config or we just use it directly!
        // wait, Env uses String.fromEnvironment which is compile time. So we CANNOT use .env dynamically easily without flutter run --dart-define.
      }
    }
  }
}
