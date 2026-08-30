import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:apk_cample166/config/app_config.dart';

void main() {
  group('AppConfig Tests', () {
    test('baseUrl returns the correct URL from env', () {
      // Setup: Load mock env
      dotenv.testLoad(fileInput: '''API_BASE_URL=https://test.ngrok.dev/api''');

      // Act
      final url = AppConfig.baseUrl;

      // Assert
      expect(url, 'https://test.ngrok.dev/api');
    });

    test('baseUrl throws an Exception if API_BASE_URL is empty', () {
      // Setup: Load empty env
      dotenv.testLoad(fileInput: '''API_BASE_URL=''');

      // Act & Assert
      expect(() => AppConfig.baseUrl, throwsException);
    });

    test('baseUrl throws an Exception if API_BASE_URL is not set', () {
      // Setup: Load empty env
      dotenv.testLoad(fileInput: '''''');

      // Act & Assert
      expect(() => AppConfig.baseUrl, throwsException);
    });
  });
}
