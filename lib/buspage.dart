import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Buspage extends StatefulWidget {
  const Buspage({super.key});

  @override
  State<Buspage> createState() => BuspageState();
}

class Station {
  final int id;
  final String busstopname;
  final double latitude;
  final double longitude;
  final bool status;

  Station({
    required this.id,
    required this.busstopname,
    required this.latitude,
    required this.longitude,
    required this.status,
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json['bus_stop_id'],
      busstopname: json['bus_stop_name'],
      latitude: double.tryParse(json['latitude'].toString()) ?? 0.0,
      longitude: double.tryParse(json['longitude'].toString()) ?? 0.0,
      status: json['status'] ?? false,
    );
  }
}

class BuspageState extends State<Buspage> {
  List<Station> stations = [];

  @override
  void initState() {
    super.initState();
    fetchStations();
  }

  Future<void> fetchStations() async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    final response = await http.get(Uri.parse('$baseUrl/bus_stop'));
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      setState(() {
        stations = data.map((json) => Station.fromJson(json)).toList();
      });
    } else {
      throw Exception('Failed to load stations');
    }
  }

  Station? getNextStation(int currentId, List<Station> stations) {
    stations.sort((a, b) => a.id.compareTo(b.id)); // เรียงตาม id
    final currentIndex = stations.indexWhere((s) => s.id == currentId);

    if (currentIndex == -1) return null;

    final nextIndex = (currentIndex + 1) % stations.length;
    return stations[nextIndex];
  }

  @override
  Widget build(BuildContext context) {
    final latest = stations.where((s) => s.status).toList();
    final currentStation = latest.isNotEmpty ? latest.last : null;
    final nextStation = currentStation != null
        ? getNextStation(currentStation.id, stations)
        : null;
    print('จุดจอดถัดไปคือ: ${nextStation?.busstopname}');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(0, 185, 255, 1),
        title: const Text('สถานะรถปัจจุบัน'),
        actions: const [Image(image: AssetImage('assets/kmitlfight.png'))],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [Color.fromRGBO(0, 185, 255, 1), Colors.white],
          ),
        ),
        child: Column(
          children: [
            Text(
              stations.any((s) => s.status)
                  ? 'กำลังปฏิบัติงาน'
                  : 'ไม่ปฏิบัติงาน',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: stations.any((s) => s.status)
                    ? Colors.white
                    : const Color.fromRGBO(227, 82, 5, 1),
              ),
            ),
            const SizedBox(height: 35),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text(
                  'จุดรับส่งล่าสุด',
                  textScaleFactor: 1.25,
                ),
                Text(
                  'จุดจอดถัดไป',
                  textScaleFactor: 1.25,
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                SizedBox(
                  height: 75,
                  child: Image(image: AssetImage('assets/bustrackicon.png')),
                ),
                SizedBox(
                  width: 75,
                  child: Image(image: AssetImage('assets/arrow.png')),
                ),
                SizedBox(
                  height: 75,
                  child: Image(image: AssetImage('assets/bustrackicon.png')),
                ),
              ],
            ),
            const SizedBox(
              height: 10,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text(currentStation?.busstopname ?? '-'),
                Text(nextStation?.busstopname ?? '-'),
              ],
            ),
            const SizedBox(height: 25),
            const Text('ประวัติการผ่านจุดจอด'),
            Expanded(
              child: currentStation == null
                  ? ListView(
                      children: stations.map((station) {
                        return Container(
                          margin: const EdgeInsets.symmetric(
                              vertical: 5, horizontal: 20),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.blue[50],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(station.busstopname),
                              Text(
                                station.status ? '✅' : '❌',
                                style: TextStyle(
                                  color: station.status
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    )
                  : ListView(
                      children: stations
                          .where((s) => s.status)
                          .map((station) => Container(
                                margin: const EdgeInsets.symmetric(
                                    vertical: 5, horizontal: 20),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.blue[50],
                                ),
                                child: Text(station.busstopname),
                              ))
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
