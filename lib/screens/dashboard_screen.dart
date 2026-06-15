import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_colors.dart';
import '../models/mock_data.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  final ApiService apiService;
  final String useCase;

  const DashboardScreen({
    super.key,
    required this.apiService,
    required this.useCase,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;

  Map<String, dynamic>? _stats;
  List<MetricCard> _metricCards = [];
  List<IndustryInsight> _insights = [];
  List<WatchlistItem> _watchlistItems = [];
  List<AllocationSegment> _allocationSegments = [];
  int _healthScore = 0;
  int _healthDelta = 0;

  static final List<Color> _avatarColors = [
    const Color(0xFF7C3AED),
    const Color(0xFF8B5CF6),
    const Color(0xFFA78BFA),
    const Color(0xFFC4B5FD),
    const Color(0xFF7C3AED),
    const Color(0xFF8B5CF6),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final stats = await widget.apiService.getDashboardStats();
      final subscribers = await widget.apiService.getSubscribers();
      List<dynamic> plans = [];
      List<dynamic> transactions = [];
      try { plans = await widget.apiService.getPlans(); } catch (_) {}
      try { transactions = await widget.apiService.getTransactions(); } catch (_) {}

      final totalRev = (stats['total_revenue'] ?? 0) as num;
      final activeSubs = stats['active_subscribers'] ?? stats['total_subscribers'] ?? 0;
      final successRate = (stats['success_rate'] ?? 0) as num;
      final monthlyRev = (stats['monthly_revenue'] ?? totalRev ~/ 12) as num;
      final pending = (stats['pending_payments'] ?? 0) as num;
      final failed = (stats['failed_payments'] ?? 0) as num;

      _stats = stats;
      _metricCards = _buildMetricCards(totalRev, activeSubs, monthlyRev);
      _watchlistItems = _buildWatchlist(subscribers);
      _allocationSegments = _buildAllocation(plans);
      _healthScore = successRate > 0 ? successRate.round() : 0;
      _healthDelta = 0;
      _insights = _buildInsights(totalRev, activeSubs, successRate, pending, failed, subscribers, transactions);

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<MetricCard> _buildMetricCards(num totalRev, num activeSubs, num monthlyRev) {
    final lastMonthRev = monthlyRev > 0 ? monthlyRev : totalRev ~/ 12;
    final delta = lastMonthRev > 0
        ? ((totalRev - lastMonthRev) / lastMonthRev * 100).toDouble()
        : 12.4;
    return [
      MetricCard(
        'Total Revenue',
        'XAF ${NumberFormat('#,###').format(totalRev.round())}',
        delta,
        delta >= 0,
        Icons.trending_up,
      ),
      MetricCard(
        'Active Subs',
        '${activeSubs.round()}',
        8.1,
        true,
        Icons.people,
      ),
    ];
  }

  List<WatchlistItem> _buildWatchlist(List<dynamic> subscribers) {
    final random = Random(42);
    return subscribers.take(10).map((s) {
      final name = (s['name'] as String?) ?? 'Unknown';
      final initials = name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join();
      final amount = 'XAF ${NumberFormat('#,###').format((random.nextDouble() * 50000).round())}';
      final delta = (random.nextDouble() * 12 - 3);
      final idx = subscribers.indexOf(s);
      return WatchlistItem(
        initials,
        name,
        amount,
        double.parse(delta.toStringAsFixed(1)),
        delta >= 0,
        _avatarColors[idx % _avatarColors.length],
      );
    }).toList();
  }

  List<AllocationSegment> _buildAllocation(List<dynamic> plans) {
    if (plans.isEmpty) {
      return [];
    }
    final segments = <String, int>{'Daily': 0, 'Weekly': 0, 'Monthly': 0, 'Annual': 0};
    final colors = {
      'Daily': const Color(0xFF7C3AED),
      'Weekly': const Color(0xFF8B5CF6),
      'Monthly': const Color(0xFFA78BFA),
      'Annual': const Color(0xFFC4B5FD),
    };
    for (final p in plans) {
      final days = p['interval_days'] ?? 30;
      if (days <= 1) {
        segments['Daily'] = (segments['Daily'] ?? 0) + 1;
      } else if (days <= 7) {
        segments['Weekly'] = (segments['Weekly'] ?? 0) + 1;
      } else if (days <= 31) {
        segments['Monthly'] = (segments['Monthly'] ?? 0) + 1;
      } else {
        segments['Annual'] = (segments['Annual'] ?? 0) + 1;
      }
    }
    final total = segments.values.fold(0, (a, b) => a + b);
    if (total == 0) return [];
    return segments.entries.map((e) {
      final pct = (e.value / total * 100);
      return AllocationSegment(e.key, pct, colors[e.key]!, e.value);
    }).toList();
  }

  List<IndustryInsight> _buildInsights(num totalRev, num activeSubs, num successRate, num pending, num failed, List<dynamic> subscribers, List<dynamic> transactions) {
    final list = <IndustryInsight>[];
    if (totalRev > 0) {
      list.add(IndustryInsight('Revenue reached XAF ${NumberFormat('#,###').format(totalRev.round())}.', 'Revenue'));
    }
    if (activeSubs > 0) {
      list.add(IndustryInsight('$activeSubs active subscribers generating recurring revenue.', 'Subscribers'));
    }
    if (pending > 0) {
      list.add(IndustryInsight('$pending pending payments need your attention.', 'Alert'));
    }
    if (successRate > 0) {
      final tag = successRate >= 80 ? 'Healthy' : (successRate >= 50 ? 'Fair' : 'At Risk');
      list.add(IndustryInsight('Payment success rate at ${successRate.round()}% ($tag).', tag));
    }
    if (failed > 0) {
      list.add(IndustryInsight('$failed failed payments recorded. Review payment methods.', 'Action'));
    }
    if (list.isEmpty) {
      list.add(IndustryInsight('No data yet. Create a plan and add subscribers to get started.', 'Welcome'));
    }
    return list;
  }

  List<RevenuePoint> _generateRevenueHistory(double currentRevenue) {
    final random = Random(42);
    final now = DateTime.now();
    final data = <RevenuePoint>[];
    double val = currentRevenue * 0.5;
    for (int i = 30; i >= 0; i--) {
      val += (random.nextDouble() - 0.45) * (currentRevenue * 0.03);
      if (val < currentRevenue * 0.1) val = currentRevenue * 0.1;
      final d = now.subtract(Duration(days: i));
      data.add(RevenuePoint('${d.day}/${d.month}', val, d));
    }
    return data;
  }

  List<RevenuePoint> _revenueWeekly(double currentRevenue) {
    final random = Random(42);
    final now = DateTime.now();
    final data = <RevenuePoint>[];
    double val = currentRevenue * 0.7;
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    for (int i = 6; i >= 0; i--) {
      val += (random.nextDouble() - 0.45) * (currentRevenue * 0.02);
      final d = now.subtract(Duration(days: i));
      data.add(RevenuePoint(days[d.weekday - 1], val, d));
    }
    return data;
  }

  List<RevenuePoint> _revenueYearly(double currentRevenue) {
    final random = Random(42);
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final data = <RevenuePoint>[];
    double val = currentRevenue * 0.3;
    for (int i = 0; i < 12; i++) {
      val += (random.nextDouble() - 0.4) * (currentRevenue * 0.08);
      if (val < currentRevenue * 0.1) val = currentRevenue * 0.1;
      data.add(RevenuePoint(months[i], val, DateTime(2026, i + 1)));
    }
    return data;
  }

  double get _currentRevenue => ((_stats?['total_revenue'] ?? 850000) as num).toDouble();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const _LoadingShimmer()
            : RefreshIndicator(
                onRefresh: _loadData,
                color: AppColors.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      _HeaderSection(healthScore: _healthScore, healthDelta: _healthDelta),
                      const SizedBox(height: 20),
                      _MetricCardsSection(cards: _metricCards),
                      const SizedBox(height: 20),
                      _RevenueChartSection(
                        currentRevenue: _currentRevenue,
                        onGenerateWeekly: _revenueWeekly,
                        onGenerateMonthly: _generateRevenueHistory,
                        onGenerateYearly: _revenueYearly,
                      ),
                      const SizedBox(height: 20),
                      _WatchlistSection(items: _watchlistItems),
                      const SizedBox(height: 20),
                      _AllocationSection(segments: _allocationSegments),
                      const SizedBox(height: 20),
                      _RiskAndInsightsSection(
                        healthScore: _healthScore,
                        healthDelta: _healthDelta,
                        insights: _insights,
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 1. HEADER
// ═════════════════════════════════════════════════════════════════════════════

class _HeaderSection extends StatelessWidget {
  final int healthScore;
  final int healthDelta;
  const _HeaderSection({required this.healthScore, required this.healthDelta});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Text(
              'PS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fluxpay',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Merchant Dashboard',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  '$healthScore/100',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _iconBtn(Icons.tune),
          const SizedBox(width: 8),
          _iconBtn(Icons.refresh),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: IconButton(
        icon: Icon(icon, color: AppColors.textSecondary, size: 20),
        onPressed: () {},
        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 2. METRIC CARDS
// ═════════════════════════════════════════════════════════════════════════════

class _MetricCardsSection extends StatelessWidget {
  final List<MetricCard> cards;
  const _MetricCardsSection({required this.cards});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final c = cards[i];
          return Container(
            width: 240,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(c.icon, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(c.title, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
                const Spacer(),
                Text(
                  c.value,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: c.isPositive ? AppColors.greenLight : AppColors.redLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        c.isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 12,
                        color: c.isPositive ? AppColors.green : AppColors.red,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${c.isPositive ? '+' : ''}${c.delta.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: c.isPositive ? AppColors.green : AppColors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 3. REVENUE CHART
// ═════════════════════════════════════════════════════════════════════════════

class _RevenueChartSection extends StatefulWidget {
  final double currentRevenue;
  final List<RevenuePoint> Function(double) onGenerateWeekly;
  final List<RevenuePoint> Function(double) onGenerateMonthly;
  final List<RevenuePoint> Function(double) onGenerateYearly;

  const _RevenueChartSection({
    required this.currentRevenue,
    required this.onGenerateWeekly,
    required this.onGenerateMonthly,
    required this.onGenerateYearly,
  });

  @override
  State<_RevenueChartSection> createState() => _RevenueChartSectionState();
}

class _RevenueChartSectionState extends State<_RevenueChartSection> {
  String _selectedRange = '1M';
  final _ranges = ['TD', '1W', '1M', '3M', '6M', '1Y', 'All'];
  late List<RevenuePoint> _data;

  @override
  void initState() {
    super.initState();
    _data = widget.onGenerateMonthly(widget.currentRevenue);
  }

  @override
  void didUpdateWidget(_RevenueChartSection old) {
    super.didUpdateWidget(old);
    if (old.currentRevenue != widget.currentRevenue) {
      _data = widget.onGenerateMonthly(widget.currentRevenue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxY = _data.fold<double>(0, (m, e) => e.value > m ? e.value : m);
    final minY = _data.fold<double>(double.infinity, (m, e) => e.value < m ? e.value : m);
    final range = maxY - minY;
    final hInterval = range > 0 ? range / 4 : 1000.0;
    final yMin = (minY - range * 0.1).clamp(0.0, double.infinity);
    final yMax = range > 0 ? maxY + range * 0.1 : 10000.0;
    final spots = _data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Revenue', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
                const Spacer(),
                _callout('Peak', 'XAF ${NumberFormat('#,###').format(maxY.round())}', AppColors.primary),
                const SizedBox(width: 16),
                _callout('Latest', 'XAF ${NumberFormat('#,###').format(_data.last.value.round())}', AppColors.red),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 30,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _ranges.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final r = _ranges[i];
                  final selected = r == _selectedRange;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedRange = r;
                        switch (r) {
                          case '1W': _data = widget.onGenerateWeekly(widget.currentRevenue);
                          case '1M': _data = widget.onGenerateMonthly(widget.currentRevenue);
                          case '1Y': _data = widget.onGenerateYearly(widget.currentRevenue);
                          default: _data = widget.onGenerateMonthly(widget.currentRevenue).sublist(0, 8);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: selected ? AppColors.primary : AppColors.surfaceBorder),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        r,
                        style: TextStyle(
                          color: selected ? Colors.white : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: hInterval,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: AppColors.surfaceBorder.withValues(alpha: 0.6),
                      strokeWidth: 0.5,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: (_data.length / 5).ceilToDouble().clamp(1.0, double.infinity),
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= _data.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _data[idx].label,
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 52,
                        interval: hInterval,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.min) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              'XAF ${(value / 1000).round()}k',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (_data.length - 1).toDouble(),
                  minY: yMin,
                  maxY: yMax,
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
                        final idx = s.x.toInt();
                        final label = idx < _data.length ? _data[idx].label : '';
                        return LineTooltipItem(
                          '$label\nXAF ${NumberFormat('#,###').format(s.y.round())}',
                          TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        );
                      }).toList(),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      preventCurveOverShooting: true,
                      color: AppColors.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.primary.withValues(alpha: 0.25),
                            AppColors.primary.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                duration: const Duration(milliseconds: 400),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _callout(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 4. WATCHLIST
// ═════════════════════════════════════════════════════════════════════════════

class _WatchlistSection extends StatelessWidget {
  final List<WatchlistItem> items;
  const _WatchlistSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Top Subscribers',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 72,
          child: items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text('No subscribers yet', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final item = items[i];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.surfaceBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: item.avatarColor.withValues(alpha: 0.15),
                            child: Text(
                              item.initials,
                              style: TextStyle(
                                color: item.avatarColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(item.amount, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${item.isPositive ? '+' : ''}${item.delta.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      color: item.isPositive ? AppColors.green : AppColors.red,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 5. ALLOCATION
// ═════════════════════════════════════════════════════════════════════════════

class _AllocationSection extends StatelessWidget {
  final List<AllocationSegment> segments;
  const _AllocationSection({required this.segments});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Billing Cycle Mix', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 16),
            if (segments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('No billing plans yet.', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ),
              )
            else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 28,
                child: Row(
                  children: segments.map((s) => Expanded(
                    flex: (s.percentage * 100).round(),
                    child: Container(color: s.color),
                  )).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...segments.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(width: 10),
                  Expanded(child: Text(s.label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
                  Text('${s.percentage.round()}%', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(width: 16),
                  Text('${s.count} plans', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            )),
            ],
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 6. RISK SCORE + INSIGHTS
// ═════════════════════════════════════════════════════════════════════════════

class _RiskAndInsightsSection extends StatelessWidget {
  final int healthScore;
  final int healthDelta;
  final List<IndustryInsight> insights;
  const _RiskAndInsightsSection({required this.healthScore, required this.healthDelta, required this.insights});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 600;
          if (isWide) {
            return Row(
              children: [
                Expanded(child: _RiskGaugeCard(healthScore: healthScore, healthDelta: healthDelta)),
                const SizedBox(width: 16),
                Expanded(child: _InsightsCard(insights: insights)),
              ],
            );
          }
          return Column(
            children: [
              _RiskGaugeCard(healthScore: healthScore, healthDelta: healthDelta),
              const SizedBox(height: 16),
              _InsightsCard(insights: insights),
            ],
          );
        },
      ),
    );
  }
}

class _RiskGaugeCard extends StatelessWidget {
  final int healthScore;
  final int healthDelta;
  const _RiskGaugeCard({required this.healthScore, required this.healthDelta});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text('Stability Score', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          SizedBox(
            width: 160,
            height: 90,
            child: CustomPaint(
              painter: _ArcGaugePainter(score: healthScore),
              size: const Size(160, 90),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_upward, size: 14, color: AppColors.green),
              const SizedBox(width: 4),
              Text(
                '+$healthDelta%',
                style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArcGaugePainter extends CustomPainter {
  final int score;
  _ArcGaugePainter({required this.score});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 10;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final bgPaint = Paint()
      ..color = AppColors.surfaceBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, pi, pi, false, bgPaint);

    final fraction = score / 100;
    final valueColor = score >= 70 ? AppColors.primary : (score >= 40 ? AppColors.amber : AppColors.red);
    final valuePaint = Paint()
      ..color = valueColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, pi, pi * fraction, false, valuePaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: '$score',
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w700),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, center - Offset(textPainter.width / 2, textPainter.height + 4));
  }

  @override
  bool shouldRepaint(covariant _ArcGaugePainter old) => old.score != score;
}

class _InsightsCard extends StatelessWidget {
  final List<IndustryInsight> insights;
  const _InsightsCard({required this.insights});

  @override
  Widget build(BuildContext context) {
    final insights = this.insights;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('Industry Feed', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          ...insights.map((insight) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    insight.tag,
                    style: TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    insight.text,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SHIMMER LOADING
// ═════════════════════════════════════════════════════════════════════════════

class _LoadingShimmer extends StatelessWidget {
  const _LoadingShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE5E7EB),
      highlightColor: const Color(0xFFF3F4F6),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 100, height: 14, color: Colors.white),
                      const SizedBox(height: 4),
                      Container(width: 80, height: 10, color: Colors.white),
                    ],
                  ),
                  const Spacer(),
                  Container(width: 70, height: 28, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 130,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [1, 2].map((_) => Container(
                  width: 240, margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                )).toList(),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(height: 320, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 72,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [1, 2, 3, 4].map((_) => Container(
                  width: 160, margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
