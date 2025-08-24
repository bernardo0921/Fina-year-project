import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../widgets/ph_meter.dart';
import '../widgets/ph_graph.dart';

// IMPORTANT: Replace this with your Arduino's actual IP address.
const String arduinoIpAddress = '192.168.63.92';
const String setPhUrl = 'http://$arduinoIpAddress/setph';
const String getStatusUrl = 'http://$arduinoIpAddress/status';
const String commandUrl = 'http://$arduinoIpAddress/command';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  double currentPH = 7.2;
  String systemStatus = "Idle";
  List<double> phHistory = [];
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  final TextEditingController _phValueController = TextEditingController();

  bool isLoading = false;
  String? responseMessage;
  Timer? _pollingTimer;

  bool _isManualMode = false; // New variable for manual mode

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startPolling();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
        );

    _slideController.forward();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _pulseController.dispose();
    _slideController.dispose();
    _phValueController.dispose();
    super.dispose();
  }

  // --- Network Functions ---

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchStatus();
    });
    setState(() {
      systemStatus = "Monitoring...";
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    setState(() {
      systemStatus = "Idle";
    });
  }

  Future<void> _fetchStatus() async {
    try {
      final response = await http
          .get(Uri.parse(getStatusUrl))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        setState(() {
          currentPH = data['ph'];
          systemStatus = data['status'];
          phHistory = [
            ...phHistory.sublist(max(0, phHistory.length - 19)),
            currentPH,
          ];
          responseMessage = null;
        });
      }
    } on TimeoutException {
      if (mounted) {
        print('Timeout fetching status');
        setState(() {
          systemStatus = "Offline";
        });
      }
    } catch (e) {
      if (mounted) {
        print('Error fetching status: $e');
        setState(() {
          systemStatus = "Offline";
        });
      }
    }
  }

  Future<void> _sendDataToArduino(String data) async {
    final double? numericPh = double.tryParse(data);
    if (numericPh == null || numericPh < 0 || numericPh > 14) {
      setState(() {
        responseMessage = 'Please enter a valid pH value (0-14).';
      });
      return;
    }

    setState(() {
      isLoading = true;
      responseMessage = null;
    });

    try {
      final response = await http
          .post(
            Uri.parse(setPhUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'ph_value': numericPh}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        setState(() {
          responseMessage = data['message'];
        });
        _fetchStatus(); // Immediately fetch new status after sending command
      } else {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        setState(() {
          responseMessage = 'Error: ${errorData['message']}';
        });
      }
    } on TimeoutException {
      setState(() {
        responseMessage = 'Request timed out. Check Arduino connection.';
      });
    } catch (e) {
      setState(() {
        responseMessage = 'Failed to connect. Is the Arduino on?';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _sendCommandToArduino(String command) async {
    setState(() {
      isLoading = true;
      responseMessage = null;
    });

    try {
      final response = await http
          .post(
            Uri.parse(commandUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'command': command}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        setState(() {
          systemStatus = data['system_status'];
          responseMessage = data['message'];
        });
      } else {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        setState(() {
          responseMessage = 'Error: ${errorData['message']}';
        });
      }
    } on TimeoutException {
      setState(() {
        responseMessage = 'Request timed out. Check Arduino connection.';
      });
    } catch (e) {
      setState(() {
        responseMessage = 'Failed to connect. Is the Arduino on?';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Color _getPHColor(double ph) {
    if (ph < 6.5) return const Color(0xFFE74C3C);
    if (ph > 7.5) return const Color(0xFF3498DB);
    return const Color(0xFF27AE60);
  }

  String _getPHStatus(double ph) {
    if (ph < 6.5) return "Acidic";
    if (ph > 7.5) return "Basic";
    return "Neutral";
  }

  LinearGradient _getBackgroundGradient() {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF8F9FA), Color(0xFFE9ECEF)],
    );
  }

  Widget _buildGlassmorphicCard({
    required Widget child,
    double? height,
    EdgeInsetsGeometry? padding,
  }) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.8),
            Colors.white.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.8),
            blurRadius: 10,
            offset: const Offset(-5, -5),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(20),
        child: child,
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color statusColor = systemStatus.contains('Treating')
        ? const Color(0xFFF39C12)
        : const Color(0xFF27AE60);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor, statusColor.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: systemStatus.contains('Treating')
                    ? _pulseAnimation.value
                    : 1.0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Text(
            systemStatus,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanelCard() {
    return _buildGlassmorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Control Panel',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2C3E50),
                ),
              ),
              Row(
                children: [
                  const Text('Manual', style: TextStyle(fontSize: 12)),
                  Switch(
                    value: _isManualMode,
                    onChanged: (bool value) {
                      setState(() {
                        _isManualMode = value;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!_isManualMode)
            Column(
              children: [
                TextField(
                  controller: _phValueController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Target pH Value',
                    labelStyle: const TextStyle(color: Color(0xFF7F8C8D)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.withOpacity(0.1),
                    prefixIcon: const Icon(
                      Icons.settings,
                      color: Color(0xFF667EEA),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () {
                          final phValue = _phValueController.text;
                          if (phValue.isNotEmpty) {
                            _sendDataToArduino(phValue);
                          }
                        },
                  icon: const Icon(Icons.send),
                  label: const Text('Send'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF27AE60),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isLoading
                            ? null
                            : () => _sendCommandToArduino('add_acid'),
                        icon: const Icon(Icons.ac_unit),
                        label: const Text('Add Acid'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3498DB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isLoading
                            ? null
                            : () => _sendCommandToArduino('add_base'),
                        icon: const Icon(Icons.water_drop),
                        label: const Text('Add Base'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE74C3C),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () => _sendCommandToArduino('stop'),
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop All'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7F8C8D),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          if (responseMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Text(
                responseMessage!,
                style: TextStyle(
                  color: responseMessage!.startsWith('Error')
                      ? Colors.red
                      : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: _getBackgroundGradient()),
        child: SafeArea(
          child: Column(
            children: [
              // App Bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF667EEA).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.water_drop,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Water Treatment',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                          Text(
                            'Real-time Monitoring',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF7F8C8D),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Status Badge
              _buildStatusBadge(),

              Expanded(
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                    child: Column(
                      children: [
                        // pH Reading Section
                        _buildGlassmorphicCard(
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: _getPHColor(
                                        currentPH,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.science,
                                      color: _getPHColor(currentPH),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'pH Level Monitor',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2C3E50),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      _getPHColor(currentPH).withOpacity(0.1),
                                      _getPHColor(currentPH).withOpacity(0.05),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _getPHColor(
                                      currentPH,
                                    ).withOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      currentPH.toStringAsFixed(1),
                                      style: TextStyle(
                                        fontSize: 48,
                                        fontWeight: FontWeight.bold,
                                        color: _getPHColor(currentPH),
                                      ),
                                    ),
                                    Text(
                                      'pH',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: _getPHColor(
                                          currentPH,
                                        ).withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              PHMeter(value: currentPH),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      _getPHColor(currentPH),
                                      _getPHColor(currentPH).withOpacity(0.8),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(25),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _getPHColor(
                                        currentPH,
                                      ).withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  _getPHStatus(currentPH),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // New: Control Panel Card
                        _buildControlPanelCard(),
                        const SizedBox(height: 20),

                        // pH Graph with enhanced styling and debug info
                        _buildGlassmorphicCard(
                          height: 300,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF3498DB,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.trending_up,
                                      color: Color(0xFF3498DB),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'pH Trend Analysis',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2C3E50),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Points: ${phHistory.length}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF7F8C8D),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (phHistory.isNotEmpty)
                                Text(
                                  'Range: ${phHistory.reduce(min).toStringAsFixed(1)} - ${phHistory.reduce(max).toStringAsFixed(1)} pH',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF7F8C8D),
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.withOpacity(0.3),
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: phHistory.isEmpty
                                      ? const Center(
                                          child: Text(
                                            'No data available',
                                            style: TextStyle(
                                              color: Color(0xFF7F8C8D),
                                              fontSize: 16,
                                            ),
                                          ),
                                        )
                                      : PHGraph(data: phHistory),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
