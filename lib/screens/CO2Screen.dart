import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart' as mqtt;
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class CO2Screen extends StatefulWidget {
  @override
  _CO2ScreenState createState() => _CO2ScreenState();
}

class _CO2ScreenState extends State<CO2Screen> {
  late MqttServerClient client;
  String co2Level = '0'; // CO2 Level in ppm
  Color co2Color = Colors.green; // Default color for safe CO2 levels
  bool isConnected = false; // Track connection status
  TextEditingController brokerController = TextEditingController();
  TextEditingController portController = TextEditingController();
  TextEditingController topicController = TextEditingController();
  TextEditingController thresholdController = TextEditingController();
  int alertThreshold = 1000; // Default CO2 threshold for alert
  String status = "Disconnected";

  @override
  void initState() {
    super.initState();
    _initializeDefaultValues();
    _initializeMQTTClient();
  }

  void _initializeDefaultValues() {
    brokerController.text = 'broker.hivemq.com';
    portController.text = '1883';
    topicController.text = 'classe/hayder/co2';
    thresholdController.text = '1000';
  }

  Future<void> _initializeMQTTClient() async {
    client = MqttServerClient(brokerController.text, '');
    client.port = int.parse(portController.text);
    client.keepAlivePeriod = 30;
    client.onDisconnected = _onDisconnected;
    client.logging(on: true);

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(
            'flutter_client_${DateTime.now().millisecondsSinceEpoch}')
        .startClean()
        .keepAliveFor(60);
    client.connectionMessage = connMessage;

    try {
      await client.connect();
    } catch (e) {
      print('Connection error: $e');
      setState(() {
        status = 'Connection failed';
      });
      client.disconnect();
      return;
    }

    if (client.connectionStatus?.state == MqttConnectionState.connected) {
      print('Connected to MQTT broker');
      setState(() {
        status = 'Connected';
        isConnected = true;
      });
      _subscribeToTopic();
    } else {
      print('Failed to connect, status: ${client.connectionStatus}');
      setState(() {
        status = 'Connection failed';
      });
      client.disconnect();
    }
  }

  void _subscribeToTopic() {
    final topic = topicController.text;
    client.subscribe(topic, MqttQos.atLeastOnce);

    client.updates?.listen((List<MqttReceivedMessage<MqttMessage?>>? messages) {
      final recentMessage = messages![0].payload as MqttPublishMessage;
      final co2Data = MqttPublishPayload.bytesToStringAsString(
          recentMessage.payload.message);

      print('Received CO² level: $co2Data ppm');
      setState(() {
        co2Level = co2Data;
        _updateCO2Color(); // Update color based on new value
        _checkAlertCondition();
      });
    });
  }

  void _onDisconnected() {
    print('Disconnected from broker');
    setState(() {
      status = 'Disconnected';
      isConnected = false;
    });
  }

  void _restartMQTTConnection() async {
    client.disconnect();
    await _initializeMQTTClient();
  }

  @override
  void dispose() {
    client.disconnect();
    super.dispose();
  }

  void _updateCO2Color() {
    final int co2 = int.tryParse(co2Level) ?? 0;
    if (co2 < 1000) {
      co2Color = Colors.green; // Safe
    } else if (co2 < 3000) {
      co2Color = Colors.orange; // Caution
    } else {
      co2Color = Colors.red; // Dangerous
    }
  }

  bool _isAlertActive = false; // Flag to prevent frequent alerts

  void _checkAlertCondition() {
    final int co2 = int.tryParse(co2Level) ?? 0;

    if (!_isAlertActive && co2 >= alertThreshold) {
      _isAlertActive = true;
      _showAlert("CO² level has reached $co2 ppm, exceeding the limit!");

      // Reset the alert flag after 10 seconds
      Future.delayed(Duration(seconds: 10), () {
        _isAlertActive = false;
      });
    }
  }

  void _showAlert(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('CO2 Alert'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          title: Row(
            children: [
              Icon(Icons.settings, color: Colors.blue),
              SizedBox(width: 10),
              Text('MQTT Configuration'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(
                  controller: brokerController,
                  label: 'Broker Address',
                  icon: Icons.cloud,
                ),
                SizedBox(height: 10),
                _buildTextField(
                  controller: portController,
                  label: 'Port',
                  icon: Icons.numbers,
                  inputType: TextInputType.number,
                ),
                SizedBox(height: 10),
                _buildTextField(
                  controller: topicController,
                  label: 'Topic',
                  icon: Icons.topic,
                ),
                SizedBox(height: 10),
                _buildTextField(
                  controller: thresholdController,
                  label: 'CO2 Alert Threshold',
                  icon: Icons.warning,
                  inputType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onPressed: () {
                setState(() {
                  alertThreshold = int.parse(thresholdController.text);
                });
                _restartMQTTConnection();
                Navigator.of(context).pop();
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType inputType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: inputType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide(color: Colors.blue),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int co2Value = int.tryParse(co2Level) ?? 0;
    final double progress = co2Value / 10000;

    return Scaffold(
      appBar: AppBar(
        title: Text('AQ Monitor'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Real-time CO² Monitoring',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size(150, 150),
                  painter: ProgressRing(progress: progress, color: co2Color),
                ),
              ],
            ),
            SizedBox(height: 20),
            // Card for CO2 Level
            Card(
              margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              elevation: 5,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'CO² Level:',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '$co2Value ppm',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: co2Color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Card for Status
            Card(
              margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              elevation: 5,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Connection Status:',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isConnected ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProgressRing extends CustomPainter {
  final double progress;
  final Color color;

  ProgressRing({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    Paint backgroundPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 50
      ..style = PaintingStyle.stroke;

    Paint progressPaint = Paint()
      ..color = color
      ..strokeWidth = 50
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    canvas.drawCircle(center, radius, backgroundPaint);

    double sweepAngle = 2 * 3.14159265359 * progress;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        -3.14159265359 / 2, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
