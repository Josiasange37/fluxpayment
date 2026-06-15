import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String apiBase = 'https://pawahub-production.up.railway.app';
  static const String botBase = 'https://zooming-bravery-production-f6f7.up.railway.app';

  String? _token;
  Map<String, dynamic>? _sme;

  String? get token => _token;
  Map<String, dynamic>? get sme => _sme;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    final smeStr = prefs.getString('sme');
    if (smeStr != null) {
      _sme = jsonDecode(smeStr);
    }
  }

  Future<void> _saveAuth(String token, Map<String, dynamic> sme) async {
    final prefs = await SharedPreferences.getInstance();
    _token = token;
    _sme = sme;
    await prefs.setString('token', token);
    await prefs.setString('sme', jsonEncode(sme));
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    _token = null;
    _sme = null;
    await prefs.remove('token');
    await prefs.remove('sme');
  }

  Map<String, String> _headers() {
    final headers = {
      'Content-Type': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  // --- Auth API ---
  Future<bool> login(String email, String password) async {
    final url = Uri.parse('$apiBase/api/auth/login');
    final resp = await http.post(
      url,
      headers: _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      await _saveAuth(data['access_token'], data['sme']);
      return true;
    }
    final err = jsonDecode(resp.body);
    throw Exception(err['detail'] ?? 'Login failed');
  }

  Future<bool> register(String email, String password, String businessName, String phone) async {
    final url = Uri.parse('$apiBase/api/auth/register');
    final resp = await http.post(
      url,
      headers: _headers(),
      body: jsonEncode({
        'email': email,
        'password': password,
        'business_name': businessName,
        'phone': phone,
      }),
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      await _saveAuth(data['access_token'], data['sme']);
      return true;
    }
    final err = jsonDecode(resp.body);
    throw Exception(err['detail'] ?? 'Registration failed');
  }

  // --- Local Preferences (stored in SharedPreferences) ---
  Future<Map<String, dynamic>> getPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'business_type': prefs.getString('business_type') ?? 'solo',
      'use_case': prefs.getString('use_case') ?? 'subscriptions',
      'onboarding_complete': prefs.getBool('onboarding_complete') ?? false,
    };
  }

  Future<void> savePreferences(String businessType, String useCase) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('business_type', businessType);
    await prefs.setString('use_case', useCase);
    await prefs.setBool('onboarding_complete', true);
  }

  // --- Dashboard Stats ---
  Future<Map<String, dynamic>> getDashboardStats() async {
    final url = Uri.parse('$apiBase/api/dashboard/stats');
    final resp = await http.get(url, headers: _headers());
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body);
    }
    throw Exception('Failed to load dashboard statistics');
  }

  Future<Map<String, dynamic>> getPOSStats() async {
    final url = Uri.parse('$apiBase/api/pos/stats');
    final resp = await http.get(url, headers: _headers());
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body);
    }
    throw Exception('Failed to load POS statistics');
  }

  // --- Subscription Plans ---
  Future<List<dynamic>> getPlans() async {
    final url = Uri.parse('$apiBase/api/plans');
    final resp = await http.get(url, headers: _headers());
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body);
    }
    throw Exception('Failed to load plans');
  }

  Future<Map<String, dynamic>> createPlan(String name, String description, int amount, int intervalDays) async {
    final url = Uri.parse('$apiBase/api/plans');
    final resp = await http.post(
      url,
      headers: _headers(),
      body: jsonEncode({
        'name': name,
        'description': description,
        'amount': amount,
        'interval_days': intervalDays,
      }),
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body);
    }
    final err = jsonDecode(resp.body);
    throw Exception(err['detail'] ?? 'Failed to create plan');
  }

  // --- Subscribers ---
  Future<List<dynamic>> getSubscribers() async {
    final url = Uri.parse('$apiBase/api/subscribers');
    final resp = await http.get(url, headers: _headers());
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body);
    }
    throw Exception('Failed to load subscribers');
  }

  Future<Map<String, dynamic>> createSubscriber(String name, String phone, String email, String planId) async {
    final url = Uri.parse('$apiBase/api/subscribers');
    final resp = await http.post(
      url,
      headers: _headers(),
      body: jsonEncode({
        'name': name,
        'phone': phone,
        'email': email,
        'plan_id': planId,
      }),
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body);
    }
    final err = jsonDecode(resp.body);
    throw Exception(err['detail'] ?? 'Failed to add subscriber');
  }

  Future<void> deactivateSubscriber(String subscriberId) async {
    final url = Uri.parse('$apiBase/api/subscribers/$subscriberId');
    final resp = await http.delete(url, headers: _headers());
    if (resp.statusCode != 200) {
      final err = jsonDecode(resp.body);
      throw Exception(err['detail'] ?? 'Deactivation failed');
    }
  }

  // --- Billing & Transactions ---
  Future<void> triggerDailyBilling() async {
    final url = Uri.parse('$apiBase/api/billing/trigger');
    final resp = await http.post(url, headers: _headers());
    if (resp.statusCode != 200) {
      final err = jsonDecode(resp.body);
      throw Exception(err['detail'] ?? 'Failed to run billing sweep');
    }
  }

  Future<Map<String, dynamic>> chargeSubscriber(String subscriberId) async {
    final url = Uri.parse('$apiBase/api/billing/charge/$subscriberId');
    final resp = await http.post(url, headers: _headers());
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body);
    }
    final err = jsonDecode(resp.body);
    throw Exception(err['detail'] ?? 'Manual charge failed');
  }

  Future<List<dynamic>> getTransactions() async {
    final url = Uri.parse('$apiBase/api/billing/transactions');
    final resp = await http.get(url, headers: _headers());
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body);
    }
    throw Exception('Failed to load transactions');
  }

  // --- POS Products ---
  Future<List<dynamic>> getProducts() async {
    final url = Uri.parse('$apiBase/api/products');
    final resp = await http.get(url, headers: _headers());
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body);
    }
    throw Exception('Failed to load products');
  }

  Future<Map<String, dynamic>> createProduct(String name, String description, int price) async {
    final url = Uri.parse('$apiBase/api/products');
    final resp = await http.post(
      url,
      headers: _headers(),
      body: jsonEncode({
        'name': name,
        'description': description,
        'price': price,
      }),
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body);
    }
    final err = jsonDecode(resp.body);
    throw Exception(err['detail'] ?? 'Failed to create product');
  }

  Future<Map<String, dynamic>> updateProduct(String id, String name, String description, int price) async {
    final url = Uri.parse('$apiBase/api/products/$id');
    final resp = await http.put(
      url,
      headers: _headers(),
      body: jsonEncode({
        'name': name,
        'description': description,
        'price': price,
      }),
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body);
    }
    final err = jsonDecode(resp.body);
    throw Exception(err['detail'] ?? 'Failed to update product');
  }

  Future<void> deleteProduct(String id) async {
    final url = Uri.parse('$apiBase/api/products/$id');
    final resp = await http.delete(url, headers: _headers());
    if (resp.statusCode != 200) {
      final err = jsonDecode(resp.body);
      throw Exception(err['detail'] ?? 'Deletion failed');
    }
  }

  // --- POS Sales ---
  Future<Map<String, dynamic>> createSale(List<Map<String, dynamic>> items, String customerName, String customerPhone, String paymentMethod) async {
    final url = Uri.parse('$apiBase/api/pos/sales');
    final resp = await http.post(
      url,
      headers: _headers(),
      body: jsonEncode({
        'items': items,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'payment_method': paymentMethod,
      }),
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body);
    }
    final err = jsonDecode(resp.body);
    throw Exception(err['detail'] ?? 'Failed to record sale');
  }

  Future<Map<String, dynamic>> chargeSale(String saleId) async {
    final url = Uri.parse('$apiBase/api/pos/sales/$saleId/charge');
    final resp = await http.post(url, headers: _headers());
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body);
    }
    final err = jsonDecode(resp.body);
    throw Exception(err['detail'] ?? 'Failed to initiate sale charge');
  }

  Future<Map<String, dynamic>> getSaleReceipt(String saleId) async {
    final url = Uri.parse('$apiBase/api/pos/sales/$saleId/receipt');
    final resp = await http.get(url, headers: _headers());
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body);
    }
    throw Exception('Failed to check receipt status');
  }

  Future<List<dynamic>> getSalesHistory() async {
    final url = Uri.parse('$apiBase/api/pos/sales');
    final resp = await http.get(url, headers: _headers());
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body);
    }
    throw Exception('Failed to load sales history');
  }

  Future<void> sendReceipt(String saleId, String channel) async {
    final url = Uri.parse('$apiBase/api/pos/sales/$saleId/send-receipt?channel=$channel');
    final resp = await http.post(url, headers: _headers());
    if (resp.statusCode != 200) {
      final err = jsonDecode(resp.body);
      throw Exception(err['detail'] ?? 'Failed to send receipt');
    }
  }

  String getReceiptPdfUrl(String saleId) {
    return '$apiBase/api/pos/sales/$saleId/receipt-pdf?token=$_token';
  }

  // --- WhatsApp Bot API ---
  Future<Map<String, dynamic>> getWhatsAppStatus() async {
    final url = Uri.parse('$botBase/status');
    final resp = await http.get(url);
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body);
    }
    throw Exception('WhatsApp status unavailable');
  }

  Future<Map<String, dynamic>> getWhatsAppQR() async {
    final url = Uri.parse('$botBase/qr-json');
    final resp = await http.get(url);
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body);
    }
    throw Exception('Failed to retrieve WhatsApp setup QR');
  }

  Future<bool> disconnectWhatsApp() async {
    final url = Uri.parse('$botBase/disconnect');
    final resp = await http.post(url);
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return data['success'] == true;
    }
    return false;
  }
}
