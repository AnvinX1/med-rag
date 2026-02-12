import 'dart:convert';

class ChatMessage {
  final String id;
  final String sessionId;
  final String role;
  final String content;
  final List<String> sources;
  final double? processingTime;
  DateTime timestamp;
  bool hasAnimated;

  ChatMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    this.sources = const [],
    this.processingTime,
    DateTime? timestamp,
    this.hasAnimated = false,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sessionId': sessionId,
      'role': role,
      'content': content,
      'sources': jsonEncode(sources),
      'processingTime': processingTime,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'],
      sessionId: map['sessionId'] ?? 'default',
      role: map['role'],
      content: map['content'],
      sources: List<String>.from(jsonDecode(map['sources'] ?? '[]')),
      processingTime: map['processingTime'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      hasAnimated: true, // Always true when loading from history
    );
  }
}

class ChatSession {
  final String id;
  final String title;
  final DateTime timestamp;

  ChatSession({
    required this.id,
    required this.title,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory ChatSession.fromMap(Map<String, dynamic> map) {
    return ChatSession(
      id: map['id'],
      title: map['title'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
    );
  }
}

class AskResponse {
  final String answer;
  final List<String> sources;
  final int numChunks;
  final double processingTime;
  final String disclaimer;

  AskResponse({
    required this.answer,
    required this.sources,
    required this.numChunks,
    required this.processingTime,
    required this.disclaimer,
  });

  factory AskResponse.fromJson(Map<String, dynamic> json) {
    return AskResponse(
      answer: json['answer'] ?? '',
      sources: List<String>.from(json['sources'] ?? []),
      numChunks: json['num_chunks_retrieved'] ?? 0,
      processingTime: (json['processing_time_seconds'] ?? 0).toDouble(),
      disclaimer: json['disclaimer'] ?? '',
    );
  }
}

class HealthStatus {
  final String status;
  final int indexSize;
  final bool modelLoaded;

  HealthStatus({
    required this.status,
    required this.indexSize,
    required this.modelLoaded,
  });

  factory HealthStatus.fromJson(Map<String, dynamic> json) {
    return HealthStatus(
      status: json['status'] ?? 'unknown',
      indexSize: json['index_size'] ?? 0,
      modelLoaded: json['model_loaded'] ?? false,
    );
  }

  bool get isHealthy => status == 'healthy';
}

class GpuInfo {
  final int index;
  final String name;
  final double memoryUsedMb;
  final double memoryTotalMb;
  final double memoryPercent;
  final double utilization;
  final double temperature;
  final double powerDraw;

  GpuInfo({
    required this.index,
    required this.name,
    required this.memoryUsedMb,
    required this.memoryTotalMb,
    required this.memoryPercent,
    required this.utilization,
    required this.temperature,
    required this.powerDraw,
  });

  factory GpuInfo.fromJson(Map<String, dynamic> json) {
    return GpuInfo(
      index: json['index'] ?? 0,
      name: json['name'] ?? 'Unknown',
      memoryUsedMb: (json['memory_used_mb'] ?? 0).toDouble(),
      memoryTotalMb: (json['memory_total_mb'] ?? 0).toDouble(),
      memoryPercent: (json['memory_percent'] ?? 0).toDouble(),
      utilization: (json['utilization_percent'] ?? 0).toDouble(),
      temperature: (json['temperature_c'] ?? 0).toDouble(),
      powerDraw: (json['power_draw_w'] ?? 0).toDouble(),
    );
  }
}

class SystemMetrics {
  final ServerInfo server;
  final SystemInfo system;
  final ProcessInfo process;
  final List<GpuInfo> gpus;
  final ModelInfo model;
  final RequestStats requests;
  final List<RequestLog> recentRequests;

  SystemMetrics({
    required this.server,
    required this.system,
    required this.process,
    required this.gpus,
    required this.model,
    required this.requests,
    required this.recentRequests,
  });

  factory SystemMetrics.fromJson(Map<String, dynamic> json) {
    return SystemMetrics(
      server: ServerInfo.fromJson(json['server'] ?? {}),
      system: SystemInfo.fromJson(json['system'] ?? {}),
      process: ProcessInfo.fromJson(json['process'] ?? {}),
      gpus: (json['gpus'] as List? ?? [])
          .map((g) => GpuInfo.fromJson(g))
          .toList(),
      model: ModelInfo.fromJson(json['model'] ?? {}),
      requests: RequestStats.fromJson(json['requests'] ?? {}),
      recentRequests: (json['recent_requests'] as List? ?? [])
          .map((r) => RequestLog.fromJson(r))
          .toList(),
    );
  }
}

class ServerInfo {
  final double uptimeSeconds;
  final String uptimeHuman;
  final String timestamp;

  ServerInfo({
    required this.uptimeSeconds,
    required this.uptimeHuman,
    required this.timestamp,
  });

  factory ServerInfo.fromJson(Map<String, dynamic> json) {
    return ServerInfo(
      uptimeSeconds: (json['uptime_seconds'] ?? 0).toDouble(),
      uptimeHuman: json['uptime_human'] ?? '0:00:00',
      timestamp: json['timestamp'] ?? '',
    );
  }
}

class SystemInfo {
  final double cpuPercent;
  final int cpuCount;
  final double ramUsedGb;
  final double ramTotalGb;
  final double ramPercent;
  final double diskUsedGb;
  final double diskTotalGb;
  final double diskPercent;

  SystemInfo({
    required this.cpuPercent,
    required this.cpuCount,
    required this.ramUsedGb,
    required this.ramTotalGb,
    required this.ramPercent,
    required this.diskUsedGb,
    required this.diskTotalGb,
    required this.diskPercent,
  });

  factory SystemInfo.fromJson(Map<String, dynamic> json) {
    return SystemInfo(
      cpuPercent: (json['cpu_percent'] ?? 0).toDouble(),
      cpuCount: json['cpu_count'] ?? 0,
      ramUsedGb: (json['ram_used_gb'] ?? 0).toDouble(),
      ramTotalGb: (json['ram_total_gb'] ?? 0).toDouble(),
      ramPercent: (json['ram_percent'] ?? 0).toDouble(),
      diskUsedGb: (json['disk_used_gb'] ?? 0).toDouble(),
      diskTotalGb: (json['disk_total_gb'] ?? 0).toDouble(),
      diskPercent: (json['disk_percent'] ?? 0).toDouble(),
    );
  }
}

class ProcessInfo {
  final int pid;
  final double memoryRssMb;
  final double memoryVmsMb;
  final int threads;

  ProcessInfo({
    required this.pid,
    required this.memoryRssMb,
    required this.memoryVmsMb,
    required this.threads,
  });

  factory ProcessInfo.fromJson(Map<String, dynamic> json) {
    return ProcessInfo(
      pid: json['pid'] ?? 0,
      memoryRssMb: (json['memory_rss_mb'] ?? 0).toDouble(),
      memoryVmsMb: (json['memory_vms_mb'] ?? 0).toDouble(),
      threads: json['threads'] ?? 0,
    );
  }
}

class ModelInfo {
  final String baseModel;
  final String? adapterPath;
  final bool modelLoaded;
  final bool indexBuilt;
  final int indexSize;

  ModelInfo({
    required this.baseModel,
    this.adapterPath,
    required this.modelLoaded,
    required this.indexBuilt,
    required this.indexSize,
  });

  factory ModelInfo.fromJson(Map<String, dynamic> json) {
    return ModelInfo(
      baseModel: json['base_model'] ?? 'Unknown',
      adapterPath: json['adapter_path'],
      modelLoaded: json['model_loaded'] ?? false,
      indexBuilt: json['index_built'] ?? false,
      indexSize: json['index_size'] ?? 0,
    );
  }
}

class RequestStats {
  final int totalQueries;
  final int totalErrors;
  final double errorRate;
  final double avgLatency;
  final double totalLatency;

  RequestStats({
    required this.totalQueries,
    required this.totalErrors,
    required this.errorRate,
    required this.avgLatency,
    required this.totalLatency,
  });

  factory RequestStats.fromJson(Map<String, dynamic> json) {
    return RequestStats(
      totalQueries: json['total_queries'] ?? 0,
      totalErrors: json['total_errors'] ?? 0,
      errorRate: (json['error_rate'] ?? 0).toDouble(),
      avgLatency: (json['avg_latency_seconds'] ?? 0).toDouble(),
      totalLatency: (json['total_latency_seconds'] ?? 0).toDouble(),
    );
  }
}

class RequestLog {
  final String timestamp;
  final String question;
  final double latency;
  final String status;
  final int? chunks;
  final String? error;

  RequestLog({
    required this.timestamp,
    required this.question,
    required this.latency,
    required this.status,
    this.chunks,
    this.error,
  });

  factory RequestLog.fromJson(Map<String, dynamic> json) {
    return RequestLog(
      timestamp: json['timestamp'] ?? '',
      question: json['question'] ?? '',
      latency: (json['latency'] ?? 0).toDouble(),
      status: json['status'] ?? 'unknown',
      chunks: json['chunks'],
      error: json['error'],
    );
  }
}
