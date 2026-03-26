import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int totalPassengers = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchPassengerData();
  }

  Future<void> fetchPassengerData() async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    final response = await http.get(Uri.parse(
      '$baseUrl/passenger-summary', // ตัวอย่าง endpoint
    ));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data == null || data.isEmpty) {
        setState(() {
          totalPassengers = 0;
          isLoading = false;
        });
        return;
      }
      setState(() {
        totalPassengers = data['total_passengers']; // ปรับตาม JSON ที่ส่งมา
        isLoading = false;
      });
    } else {
      throw Exception('Failed to load passenger data');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('แดชบอร์ดผู้โดยสาร'),
        backgroundColor: const Color.fromRGBO(0, 185, 255, 1),
        actions: const [Image(image: AssetImage('assets/kmitlfight.png'))],
      ),
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'จำนวนผู้โดยสารรวม',
                    style: TextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$totalPassengers คน',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(height: 30),
                  // พื้นที่ไว้ใส่กราฟในอนาคต
                  Container(
                    height: 200,
                    width: 300,
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('กราฟสรุปผู้โดยสาร (กำลังพัฒนา)'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
