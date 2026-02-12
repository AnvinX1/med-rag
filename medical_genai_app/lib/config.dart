class ApiConfig {
  static const String baseUrl =
      'https://unburrowed-delora-shirtless.ngrok-free.dev';

  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'ngrok-skip-browser-warning': 'true',
  };
}
