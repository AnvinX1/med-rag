import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:medical_genai_app/config.dart';
import 'package:medical_genai_app/models.dart';

class ApiService {
  final String baseUrl;

  ApiService({String? baseUrl}) : baseUrl = baseUrl ?? ApiConfig.baseUrl;

  Future<HealthStatus> getHealth() async {
    final res = await http
        .get(Uri.parse('$baseUrl/health'), headers: ApiConfig.defaultHeaders)
        .timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      return HealthStatus.fromJson(jsonDecode(res.body));
    }
    throw Exception('Health check failed: ${res.statusCode}');
  }

  Future<AskResponse> askQuestion(String question, {int topK = 3}) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/ask'),
          headers: ApiConfig.defaultHeaders,
          body: jsonEncode({'question': question, 'top_k': topK}),
        )
        .timeout(const Duration(seconds: 120));

    if (res.statusCode == 200) {
      return AskResponse.fromJson(jsonDecode(res.body));
    }
    throw Exception('Query failed: ${res.statusCode} - ${res.body}');
  }

  Future<SystemMetrics> getMetrics() async {
    final res = await http
        .get(Uri.parse('$baseUrl/metrics'), headers: ApiConfig.defaultHeaders)
        .timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      return SystemMetrics.fromJson(jsonDecode(res.body));
    }
    throw Exception('Metrics failed: ${res.statusCode}');
  }

  Future<List<GpuInfo>> getGpuMetrics() async {
    final res = await http
        .get(
          Uri.parse('$baseUrl/metrics/gpu'),
          headers: ApiConfig.defaultHeaders,
        )
        .timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return (data['gpus'] as List).map((g) => GpuInfo.fromJson(g)).toList();
    }
    throw Exception('GPU metrics failed: ${res.statusCode}');
  }
}
