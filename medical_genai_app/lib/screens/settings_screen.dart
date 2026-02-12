import 'package:flutter/material.dart';
import '../models.dart';
import '../services/api_service.dart';
import '../config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _api = ApiService();
  HealthStatus? _health;
  SystemMetrics? _metrics;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([_api.getHealth(), _api.getMetrics()]);
      setState(() {
        _health = results[0] as HealthStatus;
        _metrics = results[1] as SystemMetrics;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.settings, color: cs.primary, size: 22),
            const SizedBox(width: 8),
            const Text(
              'Settings & Info',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Connection Status
                  _buildSection('Connection', [
                    _tile(Icons.link, 'API Endpoint', ApiConfig.baseUrl),
                    _tile(
                      _health != null ? Icons.check_circle : Icons.cancel,
                      'Status',
                      _health?.isHealthy == true
                          ? 'Connected & Healthy'
                          : 'Disconnected',
                      color: _health?.isHealthy == true
                          ? Colors.green
                          : Colors.red,
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // Model Details
                  if (_metrics != null) ...[
                    _buildSection('Model', [
                      _tile(
                        Icons.psychology,
                        'Base Model',
                        _metrics!.model.baseModel,
                      ),
                      _tile(
                        Icons.tune,
                        'LoRA Adapter',
                        _metrics!.model.adapterPath ?? 'None',
                      ),
                      _tile(
                        Icons.memory,
                        'Status',
                        _metrics!.model.modelLoaded
                            ? 'Loaded in GPU memory'
                            : 'Standby (lazy load)',
                      ),
                      _tile(
                        Icons.search,
                        'FAISS Index',
                        '${_metrics!.model.indexSize} vectors indexed',
                      ),
                    ]),
                    const SizedBox(height: 16),

                    // Server Details
                    _buildSection('Server', [
                      _tile(
                        Icons.timer,
                        'Uptime',
                        _metrics!.server.uptimeHuman,
                      ),
                      _tile(
                        Icons.developer_board,
                        'CPU',
                        '${_metrics!.system.cpuCount} cores',
                      ),
                      _tile(
                        Icons.memory,
                        'RAM',
                        '${_metrics!.system.ramTotalGb.toStringAsFixed(0)} GB total',
                      ),
                      _tile(
                        Icons.storage,
                        'Disk',
                        '${_metrics!.system.diskUsedGb.toStringAsFixed(0)} / ${_metrics!.system.diskTotalGb.toStringAsFixed(0)} GB',
                      ),
                      _tile(
                        Icons.settings_applications,
                        'PID',
                        '${_metrics!.process.pid}',
                      ),
                      _tile(
                        Icons.account_tree,
                        'Threads',
                        '${_metrics!.process.threads}',
                      ),
                    ]),
                    const SizedBox(height: 16),

                    // GPU Details
                    if (_metrics!.gpus.isNotEmpty)
                      _buildSection('GPUs', [
                        for (final gpu in _metrics!.gpus) ...[
                          _tile(
                            Icons.developer_board,
                            'GPU ${gpu.index}',
                            gpu.name,
                          ),
                          _tile(
                            Icons.memory,
                            'VRAM',
                            '${gpu.memoryUsedMb.toStringAsFixed(0)} / ${gpu.memoryTotalMb.toStringAsFixed(0)} MB',
                          ),
                          _tile(
                            Icons.thermostat,
                            'Temperature',
                            '${gpu.temperature.toStringAsFixed(0)}°C',
                          ),
                          _tile(
                            Icons.bolt,
                            'Power',
                            '${gpu.powerDraw.toStringAsFixed(1)} W',
                          ),
                          if (gpu != _metrics!.gpus.last) const Divider(),
                        ],
                      ]),
                    const SizedBox(height: 16),
                  ],

                  // About
                  _buildSection('About', [
                    _tile(Icons.info_outline, 'Version', '1.0.0'),
                    _tile(
                      Icons.code,
                      'Stack',
                      'Mistral-7B + QLoRA + FAISS + FastAPI',
                    ),
                    _tile(
                      Icons.school,
                      'Purpose',
                      'Educational & Research Only',
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // Refresh Button
                  FilledButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh All Data'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String title, String subtitle, {Color? color}) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 18, color: color ?? Colors.grey),
      title: Text(
        title,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}
