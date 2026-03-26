import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Station {
  final int id;
  final String busstopname;
  final double latitude;
  final double longitude;

  Station(
      {required this.id,
      required this.busstopname,
      required this.latitude,
      required this.longitude});

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json['bus_stop_id'],
      busstopname: json['bus_stop_name'],
      latitude: double.tryParse(json['latitude']) ?? 0.0,
      longitude: double.tryParse(json['longitude']) ?? 0.0,
      //latitude: json['latitude'],
      //longitude: json['longitude'],
    );
  }
}

class Stationpage extends StatefulWidget {
  @override
  const Stationpage({super.key});
  @override
  StationpageState createState() => StationpageState();
}

class StationpageState extends State<Stationpage> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _latCtrl = TextEditingController();
  final TextEditingController _longCtrl = TextEditingController();

  List<Station> stations = [];

  @override
  void initState() {
    super.initState();
    fetchStations();
  }

  // 📥 ดึงข้อมูลจุดจอดจาก API
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

  // 📤 เพิ่มจุดจอดใหม่
  Future<void> addStation() async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    final response = await http.post(
      Uri.parse('$baseUrl/bus_stop'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'bus_stop_name': _nameCtrl.text,
        'latitude': double.parse(_latCtrl.text),
        'longitude': double.parse(_longCtrl.text),
      }),
    );
    if (response.statusCode == 201) {
      fetchStations(); // โหลดข้อมูลใหม่
      _nameCtrl.clear();
      _latCtrl.clear();
      _longCtrl.clear();
    } else {
      throw Exception('Failed to add station');
    }
  }

  // ✏️ แก้ไขจุดจอด
  Future<void> editStation(int id) async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    final response = await http.put(
      Uri.parse('$baseUrl/bus_stop/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'bus_stop_name': _nameCtrl.text,
        'latitude': double.parse(_latCtrl.text),
        'longitude': double.parse(_longCtrl.text),
      }),
    );
    if (response.statusCode == 200) {
      fetchStations();
    } else {
      throw Exception('Failed to edit station');
    }
  }

  // 🗑️ ลบจุดจอด
  Future<void> deleteStation(int id) async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    final response = await http.delete(Uri.parse('$baseUrl/bus_stop/$id'));
    if (response.statusCode == 200) {
      fetchStations();
    } else {
      throw Exception('Failed to delete station');
    }
  }

  // 🖊️ แสดง Dialog เพิ่ม/แก้ไข
  void _showStationDialog({Station? station}) {
    if (station != null) {
      _nameCtrl.text = station.busstopname;
      _latCtrl.text = station.latitude.toString();
      _longCtrl.text = station.longitude.toString();
    } else {
      _nameCtrl.clear();
      _latCtrl.clear();
      _longCtrl.clear();
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(station == null ? 'เพิ่มจุดจอด' : 'แก้ไขจุดจอด'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'ชื่อจุดจอด')),
              TextField(
                  controller: _latCtrl,
                  decoration: const InputDecoration(labelText: 'ละติจูด')),
              TextField(
                  controller: _longCtrl,
                  decoration: const InputDecoration(labelText: 'ลองติจูด')),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () {
                if (station == null) {
                  addStation();
                } else {
                  editStation(station.id);
                }
                Navigator.pop(context);
              },
              child: Text(station == null ? 'เพิ่ม' : 'บันทึก'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(0, 185, 255, 1),
        title: const Text('จุดจอด'),
        actions: [
          IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showStationDialog())
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromRGBO(0, 185, 255, 1), // Light blue color
              Colors.white, // White color
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: stations.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: stations.length,
                itemBuilder: (context, index) {
                  final station = stations[index];
                  return Column(
                    children: [
                      const SizedBox(
                        height: 10,
                      ),
                      Container(
                        width: 350,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          shape: BoxShape.rectangle,
                          color: Colors.blue[50],
                        ),
                        child: ListTile(
                          title: Text(station.busstopname),
                          subtitle: Text(
                              'Lat: ${station.latitude}, Long: ${station.longitude}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () =>
                                      _showStationDialog(station: station)),
                              IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => deleteStation(station.id)),
                            ],
                          ),
                        ),
                      )
                    ],
                  );
                },
              ),
      ),
    );
  }
}
