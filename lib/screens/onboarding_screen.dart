import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class OnboardingScreen extends StatefulWidget {
  final ApiService apiService;
  final VoidCallback onOnboardingSuccess;

  const OnboardingScreen({
    super.key,
    required this.apiService,
    required this.onOnboardingSuccess,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentStep = 0;
  String _businessType = 'solo';
  String _useCase = 'subscriptions';
  bool _isLoadingStatus = true;
  bool _isSaving = false;
  Map<String, dynamic>? _botStatus;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _checkBotStatus();
    // Poll the status of the WhatsApp bot every 3 seconds to check connection state
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_currentStep == 2) {
        _checkBotStatus();
      }
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkBotStatus() async {
    try {
      final status = await widget.apiService.getWhatsAppStatus();
      if (status['connected'] == true) {
        if (mounted) {
          setState(() {
            _botStatus = {'connected': true, 'qr_data_url': null, 'user': status['user']};
            _isLoadingStatus = false;
          });
        }
        return;
      }
      final qrStatus = await widget.apiService.getWhatsAppQR();
      if (mounted) {
        setState(() {
          _botStatus = qrStatus;
          _isLoadingStatus = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _botStatus = {'connected': false, 'qr_data_url': null, 'user': null};
          _isLoadingStatus = false;
        });
      }
    }
  }

  Future<void> _disconnectWhatsApp() async {
    setState(() {
      _isLoadingStatus = true;
    });
    try {
      await widget.apiService.disconnectWhatsApp();
      await _checkBotStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to disconnect: $e')),
        );
        setState(() {
          _isLoadingStatus = false;
        });
      }
    }
  }

  Future<void> _completeSetup() async {
    setState(() => _isSaving = true);
    await widget.apiService.savePreferences(_businessType, _useCase);
    widget.onOnboardingSuccess();
  }

  ImageProvider? _getQrImage(String? base64Url) {
    if (base64Url == null) return null;
    try {
      final commaIndex = base64Url.indexOf(',');
      final cleanBase64 = commaIndex != -1 ? base64Url.substring(commaIndex + 1) : base64Url;
      return MemoryImage(base64Decode(cleanBase64.trim()));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConnected = _botStatus?['connected'] == true;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Account Configuration', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Step Progress Indicator
                Row(
                  children: List.generate(3, (index) {
                    final isActive = index <= _currentStep;
                    return Expanded(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: isActive ? theme.colorScheme.primary : Colors.grey[300],
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: isActive ? Colors.white : Colors.grey[600],
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (index < 2)
                            Expanded(
                              child: Container(
                                height: 3,
                                color: index < _currentStep ? theme.colorScheme.primary : Colors.grey[300],
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 32),

                // Card content
                Card(
                  elevation: 2,
                  shadowColor: Colors.black12,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // STEP 1: Business Type
                        if (_currentStep == 0) ...[
                          const Text(
                            'Select Business Type',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tell us about your organization structure.',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          _buildChoiceCard(
                            title: 'Solo Business',
                            desc: 'I run my operations independently or with a small team.',
                            icon: Icons.person,
                            selected: _businessType == 'solo',
                            color: Colors.orange[50]!,
                            iconColor: Colors.orange,
                            onTap: () => setState(() => _businessType = 'solo'),
                          ),
                          const SizedBox(height: 16),
                          _buildChoiceCard(
                            title: 'Enterprise / Corporate',
                            desc: 'Multi-member team requiring advanced sub-accounts.',
                            icon: Icons.business_center,
                            selected: _businessType == 'enterprise',
                            color: Colors.purple[50]!,
                            iconColor: Colors.purple,
                            onTap: () => setState(() => _businessType = 'enterprise'),
                          ),
                        ],

                        // STEP 2: Use Case
                        if (_currentStep == 1) ...[
                          const Text(
                            'Select Service Application',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'How will you leverage Fluxpay for customer payments?',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          _buildChoiceCard(
                            title: 'Recurring Subscriptions',
                            desc: 'Charge customers automatically at interval due dates.',
                            icon: Icons.repeat,
                            selected: _useCase == 'subscriptions',
                            color: Colors.blue[50]!,
                            iconColor: Colors.blue,
                            onTap: () => setState(() => _useCase = 'subscriptions'),
                          ),
                          const SizedBox(height: 16),
                          _buildChoiceCard(
                            title: 'Point of Sale (Retail)',
                            desc: 'Handle retail one-time invoice checkouts instantly.',
                            icon: Icons.shopping_basket,
                            selected: _useCase == 'sales',
                            color: Colors.green[50]!,
                            iconColor: Colors.green,
                            onTap: () => setState(() => _useCase = 'sales'),
                          ),
                        ],

                        // STEP 3: WhatsApp Binding
                        if (_currentStep == 2) ...[
                          const Text(
                            'Connect WhatsApp Notification Bot',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Instantly deliver transaction receipts via mobile.',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          if (_isLoadingStatus)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else if (isConnected) ...[
                            Icon(Icons.check_circle, color: Colors.green[600], size: 64),
                            const SizedBox(height: 16),
                            const Text(
                              'WhatsApp Bot Online!',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Connected number: ${_botStatus?['user'] ?? 'Linked Account'}',
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            OutlinedButton.icon(
                              onPressed: _disconnectWhatsApp,
                              icon: const Icon(Icons.link_off, color: Colors.red),
                              label: const Text('Disconnect WhatsApp', style: TextStyle(color: Colors.red)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.redAccent),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ] else if (_botStatus?['qr_data_url'] != null) ...[
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[200]!),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Image(
                                  image: _getQrImage(_botStatus?['qr_data_url'])!,
                                  width: 200,
                                  height: 200,
                                  errorBuilder: (c, o, s) => const Icon(Icons.qr_code, size: 200),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Link Devices Scanner',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Open WhatsApp ➔ Settings ➔ Linked Devices ➔ Link a Device, then point your camera to scan this QR code.',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ] else ...[
                            const Column(
                              children: [
                                CircularProgressIndicator(color: Colors.green),
                                SizedBox(height: 16),
                                Text('Waiting for QR code generation from WhatsApp gateway...', textAlign: TextAlign.center),
                              ],
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Navigation Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentStep > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() => _currentStep--),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Back'),
                        ),
                      )
                    else
                      const Spacer(),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSaving
                            ? null
                            : () {
                                if (_currentStep < 2) {
                                  setState(() => _currentStep++);
                                } else {
                                  _completeSetup();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(_currentStep < 2 ? 'Continue' : 'Complete Setup'),
                      ),
                    ),
                  ],
                ),

                if (_currentStep == 2) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _isSaving ? null : _completeSetup,
                    child: const Text('Skip WhatsApp Link for Now', style: TextStyle(color: Colors.grey)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceCard({
    required String title,
    required String desc,
    required IconData icon,
    required bool selected,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.4) : Colors.white,
          border: Border.all(
            color: selected ? theme.colorScheme.primary : Colors.grey[200]!,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color,
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(desc, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
