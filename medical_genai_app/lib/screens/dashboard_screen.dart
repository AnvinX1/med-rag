import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models.dart';
import '../services/api_service.dart';
import '../widgets/metric_card.dart';
import '../widgets/gpu_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = ApiService();
  SystemMetrics? _metrics;
  bool _loading = true;
  String? _error;
  Timer? _timer;
  final List<double> _cpuHistory = [];
  final List<double> _gpuMemHistory = [];

  @override
  void initState() {
    super.initState();
    _fetchMetrics();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchMetrics());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchMetrics() async {
    try {
      final metrics = await _api.getMetrics();
      setState(() {
        _metrics = metrics;
        _loading = false;
        _error = null;
        _cpuHistory.add(metrics.system.cpuPercent);
        if (_cpuHistory.length > 30) _cpuHistory.removeAt(0);
        if (metrics.gpus.isNotEmpty) {
          _gpuMemHistory.add(metrics.gpus[0].memoryPercent);
          if (_gpuMemHistory.length > 30) _gpuMemHistory.removeAt(0);
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.dashboard, color: cs.primary, size: 22),
            const SizedBox(width: 8),
            const Text(
              'System Monitor',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _fetchMetrics,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _metrics == null
          ? _buildError()
          : _buildDashboard(cs),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(
            'Cannot reach server',
            style: TextStyle(color: Colors.grey[400]),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _fetchMetrics,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(ColorScheme cs) {
    final m = _metrics!;

    return RefreshIndicator(
      onRefresh: _fetchMetrics,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Server Status Row
          _buildStatusHeader(m, cs),
          const SizedBox(height: 12),

          // Quick Stats
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  icon: Icons.speed,
                  label: 'CPU',
                  value: '${m.system.cpuPercent}%',
                  color: _getColor(m.system.cpuPercent),
                  progress: m.system.cpuPercent / 100,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricCard(
                  icon: Icons.memory,
                  label: 'RAM',
                  value: '${m.system.ramUsedGb.toStringAsFixed(1)} GB',
                  subtitle: '/ ${m.system.ramTotalGb.toStringAsFixed(0)} GB',
                  color: _getColor(m.system.ramPercent),
                  progress: m.system.ramPercent / 100,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  icon: Icons.storage,
                  label: 'Disk',
                  value: '${m.system.diskUsedGb.toStringAsFixed(0)} GB',
                  subtitle: '/ ${m.system.diskTotalGb.toStringAsFixed(0)} GB',
                  color: _getColor(m.system.diskPercent),
                  progress: m.system.diskPercent / 100,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricCard(
                  icon: Icons.query_stats,
                  label: 'Queries',
                  value: '${m.requests.totalQueries}',
                  subtitle: 'Avg ${m.requests.avgLatency.toStringAsFixed(1)}s',
                  color: cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // GPU Cards
          if (m.gpus.isNotEmpty) ...[
            _sectionTitle('GPU Monitoring'),
            const SizedBox(height: 8),
            ...m.gpus.map(
              (gpu) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GpuCard(gpu: gpu),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // CPU History Chart
          if (_cpuHistory.length > 2) ...[
            _sectionTitle('CPU Usage History'),
            const SizedBox(height: 8),
            _buildLineChart(_cpuHistory, cs.primary),
            const SizedBox(height: 16),
          ],

          // GPU Memory Chart
          if (_gpuMemHistory.length > 2) ...[
            _sectionTitle('GPU Memory History'),
            const SizedBox(height: 8),
            _buildLineChart(_gpuMemHistory, Colors.orange),
            const SizedBox(height: 16),
          ],

          // Model Info
          _sectionTitle('Model Information'),
          const SizedBox(height: 8),
          _buildModelCard(m, cs),
          const SizedBox(height: 16),

          // Request Stats
          _sectionTitle('Request Statistics'),
          const SizedBox(height: 8),
          _buildRequestStats(m, cs),
          const SizedBox(height: 16),

          // Recent Requests
          if (m.recentRequests.isNotEmpty) ...[
            _sectionTitle('Recent Requests'),
            const SizedBox(height: 8),
            ...m.recentRequests.reversed
                .take(10)
                .map((r) => _buildRequestTile(r, cs)),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatusHeader(SystemMetrics m, ColorScheme cs) {
    return Card(
      color: cs.primary.withAlpha(20),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green,
                boxShadow: [
                  BoxShadow(color: Colors.green.withAlpha(150), blurRadius: 6),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Server Online',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Text(
                    'Uptime: ${m.server.uptimeHuman}  •  PID: ${m.process.pid}  •  ${m.process.threads} threads',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withAlpha(150),
                    ),
                  ),
                ],
              ),
            ),
            Chip(
              label: Text(
                m.model.modelLoaded ? 'Model Loaded' : 'Standby',
                style: const TextStyle(fontSize: 10),
              ),
              avatar: Icon(
                m.model.modelLoaded
                    ? Icons.check_circle
                    : Icons.hourglass_empty,
                size: 14,
                color: m.model.modelLoaded ? Colors.green : Colors.orange,
              ),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildLineChart(List<double> data, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 140,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 25,
                getDrawingHorizontalLine: (v) =>
                    FlLine(color: Colors.grey.withAlpha(30), strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: 25,
                    getTitlesWidget: (v, _) => Text(
                      '${v.toInt()}%',
                      style: const TextStyle(fontSize: 9, color: Colors.grey),
                    ),
                  ),
                ),
                bottomTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              minY: 0,
              maxY: 100,
              lineBarsData: [
                LineChartBarData(
                  spots: data
                      .asMap()
                      .entries
                      .map((e) => FlSpot(e.key.toDouble(), e.value))
                      .toList(),
                  isCurved: true,
                  color: color,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: color.withAlpha(30),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModelCard(SystemMetrics m, ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _infoRow('Base Model', m.model.baseModel, Icons.psychology),
            const Divider(height: 16),
            _infoRow('Adapter', m.model.adapterPath ?? 'None', Icons.tune),
            const Divider(height: 16),
            _infoRow('Index', '${m.model.indexSize} vectors', Icons.search),
            const Divider(height: 16),
            _infoRow(
              'Status',
              m.model.modelLoaded ? 'Loaded in GPU' : 'Standby (lazy load)',
              Icons.power_settings_new,
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 10),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildRequestStats(SystemMetrics m, ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _statColumn('Total', '${m.requests.totalQueries}', cs.primary),
            _divider(),
            _statColumn('Errors', '${m.requests.totalErrors}', Colors.red),
            _divider(),
            _statColumn(
              'Err Rate',
              '${m.requests.errorRate}%',
              m.requests.errorRate > 10 ? Colors.red : Colors.green,
            ),
            _divider(),
            _statColumn(
              'Avg Latency',
              '${m.requests.avgLatency.toStringAsFixed(1)}s',
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statColumn(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 36, color: Colors.grey.withAlpha(40));
  }

  Widget _buildRequestTile(RequestLog r, ColorScheme cs) {
    final isError = r.status == 'error';
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        leading: Icon(
          isError ? Icons.error_outline : Icons.check_circle_outline,
          color: isError ? Colors.red : Colors.green,
          size: 18,
        ),
        title: Text(
          r.question,
          style: const TextStyle(fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${r.latency}s  •  ${r.timestamp.split('T').last.split('.').first}',
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
        trailing: r.chunks != null
            ? Chip(
                label: Text(
                  '${r.chunks} chunks',
                  style: const TextStyle(fontSize: 9),
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              )
            : null,
      ),
    );
  }

  Color _getColor(double percent) {
    if (percent > 80) return Colors.red;
    if (percent > 60) return Colors.orange;
    return Colors.green;
  }
}
