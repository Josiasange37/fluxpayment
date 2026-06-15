import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SubscribersScreen extends StatefulWidget {
  final ApiService apiService;
  final bool isSales;

  const SubscribersScreen({super.key, required this.apiService, required this.isSales});

  @override
  State<SubscribersScreen> createState() => _SubscribersScreenState();
}

class _SubscribersScreenState extends State<SubscribersScreen> {
  List<dynamic> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = widget.isSales
          ? await widget.apiService.getSalesHistory()
          : await widget.apiService.getSubscribers();
      if (mounted) setState(() { _items = data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.isSales ? 'Sales History' : 'Subscribers', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.isSales ? Icons.receipt : Icons.people_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(widget.isSales ? 'No sales yet' : 'No subscribers yet', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        itemBuilder: (context, i) {
          final item = _items[i];
          final name = item['name'] ?? item['customer_name'] ?? 'Entry ${i + 1}';
          final subtitle = item['email'] ?? item['phone'] ?? '';
          final isActive = item['is_active'] != false;

          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: isActive ? Colors.green[50] : Colors.red[50],
                child: Icon(isActive ? Icons.check_circle : Icons.cancel, color: isActive ? Colors.green : Colors.red),
              ),
              title: Text('$name', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
            ),
          );
        },
      ),
    );
  }
}
