import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double minPH = 6.5;
  double maxPH = 7.5;
  bool autoMode = true;
  bool alertsEnabled = true;
  
  List<AlertItem> alerts = [
    AlertItem(
      title: 'pH Level Critical',
      message: 'pH dropped below 6.0',
      timestamp: DateTime.now().subtract(Duration(minutes: 5)),
      severity: AlertSeverity.critical,
    ),
    AlertItem(
      title: 'Base Valve Delay',
      message: 'Base valve response time exceeded normal range',
      timestamp: DateTime.now().subtract(Duration(minutes: 15)),
      severity: AlertSeverity.warning,
    ),
    AlertItem(
      title: 'System Normal',
      message: 'All systems operating within normal parameters',
      timestamp: DateTime.now().subtract(Duration(minutes: 30)),
      severity: AlertSeverity.info,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings & Alerts'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // pH Threshold Settings
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'pH Threshold Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    SizedBox(height: 20),
                    
                    // Min pH Setting
                    Text('Minimum pH: ${minPH.toStringAsFixed(1)}'),
                    Slider(
                      value: minPH,
                      min: 5.0,
                      max: 7.0,
                      divisions: 20,
                      onChanged: (value) {
                        setState(() {
                          minPH = value;
                          if (minPH >= maxPH) {
                            maxPH = minPH + 0.5;
                          }
                        });
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Max pH Setting
                    Text('Maximum pH: ${maxPH.toStringAsFixed(1)}'),
                    Slider(
                      value: maxPH,
                      min: 7.0,
                      max: 9.0,
                      divisions: 20,
                      onChanged: (value) {
                        setState(() {
                          maxPH = value;
                          if (maxPH <= minPH) {
                            minPH = maxPH - 0.5;
                          }
                        });
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Target Range Display
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Color(0xFFE8F5E8),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.green),
                          SizedBox(width: 8),
                          Text(
                            'Target Range: ${minPH.toStringAsFixed(1)} - ${maxPH.toStringAsFixed(1)}',
                            style: TextStyle(
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // System Settings
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'System Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    SwitchListTile(
                      title: Text('Auto-Mode'),
                      subtitle: Text('Automatically adjust pH levels'),
                      value: autoMode,
                      onChanged: (value) {
                        setState(() {
                          autoMode = value;
                        });
                      },
                      activeColor: Color(0xFF27AE60),
                    ),
                    
                    SwitchListTile(
                      title: Text('Alerts Enabled'),
                      subtitle: Text('Receive system notifications'),
                      value: alertsEnabled,
                      onChanged: (value) {
                        setState(() {
                          alertsEnabled = value;
                        });
                      },
                      activeColor: Color(0xFF27AE60),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Alerts Section
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Alerts',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        TextButton(
                          onPressed: _clearAllAlerts,
                          child: Text('Clear All'),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    
                    ...alerts.map((alert) => _buildAlertItem(alert)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertItem(AlertItem alert) {
    Color alertColor;
    IconData alertIcon;
    
    switch (alert.severity) {
      case AlertSeverity.critical:
        alertColor = Colors.red;
        alertIcon = Icons.error;
        break;
      case AlertSeverity.warning:
        alertColor = Colors.orange;
        alertIcon = Icons.warning;
        break;
      case AlertSeverity.info:
        alertColor = Colors.blue;
        alertIcon = Icons.info;
        break;
    }
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: alertColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: alertColor.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(alertIcon, color: alertColor, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: alertColor,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  alert.message,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF7F8C8D),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  _formatTimestamp(alert.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFBDC3C7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _clearAllAlerts() {
    setState(() {
      alerts.clear();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('All alerts cleared'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

class AlertItem {
  final String title;
  final String message;
  final DateTime timestamp;
  final AlertSeverity severity;

  AlertItem({
    required this.title,
    required this.message,
    required this.timestamp,
    required this.severity,
  });
}

enum AlertSeverity { critical, warning, info }