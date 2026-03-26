import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Station {
  final int id;
  final String busstopname;
  final double latitude;
  final double longitude;
  final int ordinalNum; // เพิ่มฟิลด์ใหม่

  Station({
    required this.id,
    required this.busstopname,
    required this.latitude,
    required this.longitude,
    required this.ordinalNum, // เพิ่มฟิลด์ใหม่
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json['bus_stop_id'],
      busstopname: json['bus_stop_name'],
      latitude: double.tryParse(json['latitude']) ?? 0.0,
      longitude: double.tryParse(json['longitude']) ?? 0.0,
      ordinalNum: json['ordinal_num'] ?? 0, // เพิ่มการอ่านค่าจาก JSON
    );
  }
}

class Driverpage extends StatefulWidget {
  final String token;

  const Driverpage({
    super.key,
    required this.token,
  });

  @override
  State<Driverpage> createState() => _DriverpageState();
}

class _DriverpageState extends State<Driverpage> {
  bool _switchvalue = false;
  Position? _currentPosition;
  String _locationText = "ยังไม่ได้อ่านพิกัด";
  List<Station> stations = [];
  StreamSubscription<Position>? _positionStream;
  int passengerCount = 0;
  int _passengerCount = 0;
  @override
  void initState() {
    super.initState();
    fetchStations();
    fetchPassengerCount();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> fetchStations() async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    final response = await http.get(Uri.parse('$baseUrl/bus_stop'));
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      setState(() {
        stations = data.map((json) => Station.fromJson(json)).toList();
        // เรียงลำดับตาม ordinalNum
        stations.sort((a, b) => a.ordinalNum.compareTo(b.ordinalNum));
      });
    } else {
      throw Exception('Failed to load stations');
    }
  }

  void _startTracking() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      // ไม่ได้รับอนุญาต ใช้ SnackBar / Alert แจ้งผู้ใช้ให้เปิด permission
      print("❌ Location permission denied. Please enable in settings.");
      return;
    }

    // เริ่มติดตามตำแหน่ง
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      _handlePositionUpdate(position);
      _sendLocationToServer(
        widget.token,
        position.latitude,
        position.longitude,
      );
    });
  }

  Future<void> fetchPassengerCount() async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    final response = await http.get(
      Uri.parse('$baseUrl/passenger-summary'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final countString = data['total_passengers'] ?? "0";

      setState(() {
        _passengerCount = int.tryParse(countString.toString()) ?? 0;
      });

      print("🧾 จำนวนผู้โดยสาร: $countString → $_passengerCount");
    } else {
      print("❌ โหลดจำนวนไม่สำเร็จ: ${response.statusCode}");
    }
  }

  Future<void> _savePassengerCount(int count) async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    Map<String, dynamic> decodedToken = JwtDecoder.decode(widget.token);
    if (decodedToken.containsKey('userId')) {
      String driverId = decodedToken['userId'];

      final response = await http.post(
        Uri.parse('$baseUrl/save_passenger_count'),
        headers: {
          'Content-Type': 'application/json',
          //   'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({
          'driver_id': driverId,
          'passenger_count': count,
        }),
      );

      if (response.statusCode == 200) {
        print("✅ บันทึกจำนวนผู้โดยสารเรียบร้อย");
      } else {
        print("❌ บันทึกไม่สำเร็จ: ${response.body}");
      }
    } else {
      print("❌ ไม่พบ id ใน JWT");
    }
  }

  void _stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  void _sendLocationToServer(String token, double lat, double lng) async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    try {
      final Map<String, dynamic> data = {
        'latitude': lat,
        'longitude': lng,
      };

      print('🔄 Sending location update: $lat, $lng');

      final response = await http.post(
        Uri.parse('$baseUrl/update_driver_location'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        print('✅ ส่งตำแหน่งไปเซิร์ฟเวอร์สำเร็จ');
      } else {
        print('❌ ส่งไม่สำเร็จ: ${response.statusCode}');
        print('ข้อความ: ${response.body}');

        // Check for specific error types
        if (response.statusCode == 401) {
          print('🔑 โทเค็นไม่ถูกต้องหรือหมดอายุ - ต้องเข้าสู่ระบบใหม่');
          // Consider adding auto-logout or re-authentication logic here
        }
      }
    } catch (e) {
      print('❌ เกิดข้อผิดพลาด: $e');

      // Check for network errors
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        print(
            '📡 ปัญหาการเชื่อมต่อเน็ตเวิร์ค - ตรวจสอบการเชื่อมต่ออินเทอร์เน็ต');
      }
    }
  }

  Future<void> _handlePositionUpdate(Position position) async {
    setState(() {
      _currentPosition = position;
      _locationText =
          "ละติจูด: ${position.latitude}, ลองจิจูด: ${position.longitude}";
    });

    // ✅ ส่งตำแหน่งไป backend ทุกครั้ง
    _sendLocationToServer(
      widget.token,
      position.latitude,
      position.longitude,
    );

    Station? matchedStation;

    for (Station station in stations) {
      double latDiff = (station.latitude - position.latitude).abs();
      double lonDiff = (station.longitude - position.longitude).abs();

      if (latDiff < 0.0001 && lonDiff < 0.0001) {
        matchedStation = station;

        // ✅ บันทึกจำนวนผู้โดยสาร
        await _savePassengerCount(passengerCount);
        setState(() {
          passengerCount = 0;
        });
        final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
        // ✅ อัปเดตจุดนี้เป็น true
        final updateResponse = await http.patch(
          Uri.parse('$baseUrl/bus_stop/${station.id}/status'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'status': true}),
        );

        if (updateResponse.statusCode == 200) {
          print("✅ อัปเดต ${station.busstopname} เป็น true");
        } else {
          print("❌ อัปเดตสถานะจุดจอดล้มเหลว");
        }

        break;
      }
    }

    // ✅ ถ้าเจอว่าตรงจุดเริ่มต้น → set จุดอื่นเป็น false
    if (matchedStation != null) {
      final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
      //final minId = stations.map((s) => s.id).reduce((a, b) => a < b ? a : b);
      // ใช้ ordinalNum แทน - จุดเริ่มต้นคือจุดที่มี ordinalNum = 1
      if (matchedStation.ordinalNum == 1) {
        // รีเซ็ตสถานะของทุกป้าย
        for (final station in stations) {
          if (station.id != matchedStation.id) {
            await http.patch(
              Uri.parse('$baseUrl/bus_stop/${station.id}/status'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'status': false}),
            );
          }
        }
      }
    }
  }

  Future<void> _setAllStationsStatusFalse() async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    for (final station in stations) {
      await http.patch(
        Uri.parse('$baseUrl/bus_stop/${station.id}/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': false}),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(0, 185, 255, 1),
        title: const Text('พนักงานขับรถ'),
        actions: const [Image(image: AssetImage('assets/kmitlfight.png'))],
      ),
      body: SingleChildScrollView(
        child: Container(
          height: 750,
          width: 800,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [
                Color.fromRGBO(0, 185, 255, 1),
                Colors.white,
              ],
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 35),
              const Text(
                "กรุณาเปิดหน้านี้ไว้ขณะปฏิบัติงาน",
                textScaleFactor: 1.5,
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 20),
                    child: Text("จำนวนการใช้บริการ",
                        style: TextStyle(color: Colors.white)),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: Text(
                      "$_passengerCount",
                      textScaleFactor: 2,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const SizedBox(width: 20),
                  const Text("จำนวนผู้โดยสาร",
                      style: TextStyle(color: Colors.white)),
                  const SizedBox(width: 70),
                  Text("$passengerCount",
                      textScaleFactor: 2,
                      style: const TextStyle(color: Colors.white)),
                ],
              ),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.undo_rounded,
                        size: 60, color: Colors.orange),
                    onPressed: () {
                      setState(() {
                        if (passengerCount > 0) passengerCount--;
                      });
                    },
                  ),
                  const SizedBox(width: 50),
                  Text(
                    "$passengerCount",
                    style: const TextStyle(
                        fontSize: 36, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 50),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline,
                        size: 60, color: Colors.orange),
                    onPressed: () {
                      setState(() {
                        passengerCount++;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 35),
              Row(
                children: [
                  const SizedBox(width: 50),
                  Switch(
                    value: _switchvalue,
                    activeColor: Colors.green,
                    inactiveTrackColor: Colors.orange,
                    onChanged: (isOn) {
                      setState(() {
                        _switchvalue = isOn;
                      });

                      if (isOn) {
                        if (stations.isNotEmpty) {
                          _startTracking();
                        } else {
                          print("❌ ยังโหลดจุดจอดไม่เสร็จ");
                        }
                      } else {
                        _stopTracking();
                        _locationText = "ยังไม่ได้อ่านพิกัด";
                        _setAllStationsStatusFalse();
                      }
                    },
                  ),
                  const Text(textScaleFactor: 1.2, "กดเพื่อแสดงตำแหน่งรถ"),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
