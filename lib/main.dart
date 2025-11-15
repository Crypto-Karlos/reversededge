import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() => runApp(ReversalEdgeApp());

class ReversalEdgeApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ReversalEdge',
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Color(0xFF121212)),
      home: DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _candles = <Map<String, dynamic>>[];
  final _signals = <String>[];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCandles();
    _startPolling();
  }

  void _startPolling() {
    Future.doWhile(() async {
      await Future.delayed(Duration(minutes: 1));
      await _fetchCandles();
      return true;
    });
  }

  Future<void> _fetchCandles() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.coingecko.com/api/v3/coins/bitcoin/market_chart?vs_currency=usd&days=1&interval=minute'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prices = data['prices'] as List;
        final newCandles = <Map<String, dynamic>>[];

        for (int i = 0; i < prices.length - 1; i++) {
          final time = DateTime.fromMillisecondsSinceEpoch(prices[i][0]);
          final open = prices[i][1];
          final close = prices[i + 1][1];
          final high = [open, close].reduce((a, b) => a > b ? a : b);
          final low = [open, close].reduce((a, b) => a < b ? a : b);

          newCandles.add({'time': time, 'open': open, 'high': high, 'low': low, 'close': close});
        }

        setState(() {
          _candles.clear();
          _candles.addAll(newCandles.length > 100 ? newCandles.sublist(newCandles.length - 100) : newCandles);
          _isLoading = false;
          _checkForReversal();
        });
      }
    } catch (e) {
      print("API Error: $e");
    }
  }

  void _checkForReversal() {
    if (_candles.length < 50) return;

    final recent = _candles.sublist(_candles.length - 50);
    final lows = recent.map((c) => c['low'] as double).toList();

    int low1 = lows.indexOf(lows.reduce((a, b) => a < b ? a : b));
    int low2 = lows.lastIndexOf(lows.reduce((a, b) => a < b ? a : b));
    if (low2 - low1 > 10 && (lows[low1] - lows[low2]).abs() / lows[low1] < 0.03) {
      final signal = 'BULLISH REVERSAL: Double Bottom on BTC/USDT! Target: +8%';
      if (!_signals.contains(signal)) {
        setState(() => _signals.add(signal));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI Alert: $signal'), backgroundColor: Colors.teal),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ReversalEdge', style: TextStyle(color: Color(0xFF00D1FF))),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text('BTC/USDT • Live 1m', style: TextStyle(fontSize: 18, color: Colors.white)),
            SizedBox(height: 16),
            Container(
              height: 250,
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: Color(0xFF00D1FF)))
                  : _candles.isEmpty
                      ? Center(child: Text('No data', style: TextStyle(color: Colors.grey)))
                      : LineChart(
                          LineChartData(
                            gridData: FlGridData(show: true, drawVerticalLine: false),
                            titlesData: FlTitlesData(show: false),
                            borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey)),
                            lineBarsData: [
                              LineChartBarData(
                                spots: _candles
                                    .asMap()
                                    .entries
                                    .map((e) => FlSpot(e.key.toDouble(), e.value['close']))
                                    .toList(),
                                isCurved: true,
                                color: Color(0xFF00D1FF),
                                barWidth: 2,
                              ),
                            ],
                          ),
                        ),
            ),
            SizedBox(height: 20),
            Text('Active Signals:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
            Expanded(
              child: _signals.isEmpty
                  ? Center(child: Text('Scanning for reversals...', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _signals.length,
                      itemBuilder: (ctx, i) => Card(
                        color: Color(0xFF1C1C1E),
                        margin: EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: Icon(Icons.trending_up, color: Colors.teal),
                          title: Text(_signals[i], style: TextStyle(color: Colors.white)),
                          trailing: Icon(Icons.notifications, color: Colors.teal),
                        ),
                      ),
                    ),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _showAIStub(),
              icon: Icon(Icons.smart_toy, color: Colors.white),
              label: Text('Ask AI', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAIStub() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Color(0xFF121212),
        title: Text('ReversalEdge AI', style: TextStyle(color: Colors.teal)),
        content: Text('AI: "Strong bullish reversal. Enter long now."'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Close', style: TextStyle(color: Colors.teal))),
        ],
      ),
    );
  }
}