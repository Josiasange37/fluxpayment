import 'dart:math';
import 'package:flutter/material.dart';

class RevenuePoint {
  final String label;
  final double value;
  final DateTime date;
  RevenuePoint(this.label, this.value, this.date);
}

class MetricCard {
  final String title;
  final String value;
  final double delta;
  final bool isPositive;
  final IconData icon;
  MetricCard(this.title, this.value, this.delta, this.isPositive, this.icon);
}

class WatchlistItem {
  final String initials;
  final String name;
  final String amount;
  final double delta;
  final bool isPositive;
  final Color avatarColor;
  WatchlistItem(this.initials, this.name, this.amount, this.delta, this.isPositive, this.avatarColor);
}

class AllocationSegment {
  final String label;
  final double percentage;
  final Color color;
  final int count;
  AllocationSegment(this.label, this.percentage, this.color, this.count);
}

class IndustryInsight {
  final String text;
  final String tag;
  IndustryInsight(this.text, this.tag);
}

class MockData {
  static final random = Random(42);

  static List<RevenuePoint> revenueHistory({int days = 30}) {
    final now = DateTime.now();
    final data = <RevenuePoint>[];
    double val = 850000;
    for (int i = days; i >= 0; i--) {
      val += (random.nextDouble() - 0.45) * 50000;
      if (val < 100000) val = 100000;
      final d = now.subtract(Duration(days: i));
      final label = '${d.day}/${d.month}';
      data.add(RevenuePoint(label, val, d));
    }
    return data;
  }

  static List<RevenuePoint> revenueWeekly() {
    final now = DateTime.now();
    final data = <RevenuePoint>[];
    double val = 920000;
    for (int i = 6; i >= 0; i--) {
      val += (random.nextDouble() - 0.45) * 40000;
      final d = now.subtract(Duration(days: i));
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      data.add(RevenuePoint(days[d.weekday - 1], val, d));
    }
    return data;
  }

  static List<RevenuePoint> revenueYearly() {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final data = <RevenuePoint>[];
    double val = 700000;
    for (int i = 0; i < 12; i++) {
      val += (random.nextDouble() - 0.4) * 120000;
      if (val < 200000) val = 200000;
      data.add(RevenuePoint(months[i], val, DateTime(2026, i + 1)));
    }
    return data;
  }

  static List<MetricCard> get metricCards => [
    MetricCard('Total Revenue', 'XAF 1,284,500', 12.4, true, Icons.trending_up),
    MetricCard('Active Subs', '342', 8.1, true, Icons.people),
  ];

  static List<WatchlistItem> get watchlist => [
    WatchlistItem('JD', 'John Doe', 'XAF 25k', 3.2, true, const Color(0xFF7C3AED)),
    WatchlistItem('AM', 'Alice M.', 'XAF 18k', -1.5, false, const Color(0xFF8B5CF6)),
    WatchlistItem('BK', 'Brenda K.', 'XAF 42k', 6.7, true, const Color(0xFFA78BFA)),
    WatchlistItem('CN', 'Christian N.', 'XAF 12k', -2.1, false, const Color(0xFFC4B5FD)),
    WatchlistItem('EO', 'Esther O.', 'XAF 31k', 4.3, true, const Color(0xFF7C3AED)),
    WatchlistItem('FM', 'Felix M.', 'XAF 9k', 0.8, true, const Color(0xFF8B5CF6)),
  ];

  static List<AllocationSegment> get allocation => [
    AllocationSegment('Daily', 15, const Color(0xFF7C3AED), 47),
    AllocationSegment('Weekly', 25, const Color(0xFF8B5CF6), 83),
    AllocationSegment('Monthly', 45, const Color(0xFFA78BFA), 156),
    AllocationSegment('Annual', 15, const Color(0xFFC4B5FD), 29),
  ];

  static List<IndustryInsight> get insights => [
    IndustryInsight('Mobile money transactions in CEMAC grew 34%', 'Trend'),
    IndustryInsight('Peak payment hours: 10–12 AM and 4–6 PM', 'Insight'),
    IndustryInsight('Average sub retention +18% with WhatsApp receipts', 'Tip'),
  ];

  static int healthScore = 72;
  static int healthDelta = 4;
}
