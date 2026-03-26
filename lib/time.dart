import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class TimePage extends StatefulWidget {
  const TimePage({super.key});

  @override
  State<TimePage> createState() => _TimePageState();
}

class Station {
  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final bool status;
  final int ordinalNum; // เพิ่ม

  Station({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.ordinalNum, // เพิ่ม
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json['bus_stop_id'] ?? 0,
      name: json['bus_stop_name'] ?? 'ไม่ระบุชื่อ',
      latitude: double.tryParse(json['latitude'].toString()) ?? 0.0,
      longitude: double.tryParse(json['longitude'].toString()) ?? 0.0,
      status: json['status'] ?? false,
      ordinalNum: json['ordinal_num'] ?? 0, // ดึงจาก backend
    );
  }
}

class _TimePageState extends State<TimePage> {
  List<Station> stations = [];
  List<dynamic> timetables = [];
  bool isLoading = true;
  List<int> durations = [];

  @override
  void initState() {
    super.initState();
    fetchAllData();
  }

  Future<void> fetchAllData() async {
    await Future.wait([
      fetchStations(),
      fetchTimetables(),
      fetchCachedDurations().then((data) => durations = data),
    ]);
    setState(() {
      isLoading = false;
    });
  }

  Future<List<int>> fetchCachedDurations() async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    final response = await http.get(Uri.parse('$baseUrl/station-durations'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List<dynamic>;

      // เรียงข้อมูลตาม from_ordinal_num และ to_ordinal_num
      data.sort((a, b) {
        int fromA = a['from_ordinal_num'] as int? ?? 0;
        int fromB = b['from_ordinal_num'] as int? ?? 0;
        if (fromA != fromB) {
          return fromA.compareTo(fromB);
        }
        int toA = a['to_ordinal_num'] as int? ?? 0;
        int toB = b['to_ordinal_num'] as int? ?? 0;
        return toA.compareTo(toB);
      });

      // แปลงเป็น list ของ duration_minutes
      return data.map<int>((e) => e['duration_minutes'] as int? ?? 0).toList();
    } else {
      throw Exception('Failed to load travel durations');
    }
  }

  Future<void> fetchStations() async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    final response = await http.get(Uri.parse('$baseUrl/bus_stop'));
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      stations = data.map((json) => Station.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load stations');
    }
  }

  Future<void> fetchTimetables() async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    final response = await http.get(Uri.parse('$baseUrl/timetable'));
    if (response.statusCode == 200) {
      timetables = json.decode(response.body);
    } else {
      throw Exception('Failed to load timetable');
    }
  }

  List<Map<String, dynamic>> calculateEstimatedTimes(String path) {
    final DateFormat timeFormat = DateFormat.Hm();

    return timetables.where((t) => t['path'] == path).map((t) {
      final timeString = t['time'];
      final startTime = timeFormat.parse(timeString);

      List<Map<String, String>> stationTimes = [];
      DateTime currentTime = startTime;

      for (int i = 0; i < stations.length; i++) {
        stationTimes.add({
          'station': stations[i].name,
          'time': timeFormat.format(currentTime),
        });

        if (i < durations.length) {
          currentTime = currentTime.add(Duration(minutes: durations[i]));
        }
      }

      return {
        'routeTime': timeString,
        'stations': stationTimes,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เวลาเดินรถ'),
        backgroundColor: const Color.fromRGBO(0, 185, 255, 1),
        actions: const [Image(image: AssetImage('assets/kmitlfight.png'))],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromRGBO(0, 185, 255, 1),
              Colors.white,
            ],
          ),
        ),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: fetchAllData,
                child: ListView(
                  children: ['morning', 'lunch', 'evening'].map((path) {
                    final estimations = calculateEstimatedTimes(path);
                    return ExpansionTile(
                      title: Text(getThaiTitle(path),
                          style: const TextStyle(fontSize: 18)),
                      children: estimations.map((schedule) {
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('เวลาออกเดินทาง: ${schedule['routeTime']}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 5),
                                ...List.generate(
                                  stations.length,
                                  (index) => Text(
                                      '• ${schedule['stations'][index]['station']} - ${schedule['stations'][index]['time']}'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              ),
      ),
    );
  }

  String getThaiTitle(String path) {
    switch (path) {
      case 'morning':
        return 'ช่วงเช้า';
      case 'lunch':
        return 'ช่วงบ่าย';
      case 'evening':
        return 'ช่วงเย็น';
      default:
        return path;
    }
  }
}
