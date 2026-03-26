import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Tickethistory extends StatefulWidget {
  final String token;
  const Tickethistory({super.key, required this.token});

  @override
  State<Tickethistory> createState() => TickethistoryState();
}

class Reservation {
  final int reservationId;
  final int scheduleId;
  final int seatNo;
  final String status;
  final int userId;
  final DateTime reservationDate;
  final int originStopId;
  final int destinationStopId;

  Reservation({
    required this.reservationId,
    required this.scheduleId,
    required this.seatNo,
    required this.status,
    required this.userId,
    required this.reservationDate,
    required this.originStopId,
    required this.destinationStopId,
  });

  factory Reservation.fromJson(Map<String, dynamic> json) {
    return Reservation(
      reservationId: json['reservation_id'],
      scheduleId: json['schedule_id'],
      seatNo: json['seat_no'],
      status: json['status'],
      userId: json['user_id'],
      reservationDate: DateTime.parse(json['reservation_date']),
      originStopId: json['origin_stop_id'],
      destinationStopId: json['destination_stop_id'],
    );
  }
}

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

class Item {
  final int id;
  final String time;
  final String path;

  Item({
    required this.id,
    required this.time,
    required this.path,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    // ตรวจสอบว่า key มีอยู่และไม่เป็น null
    if (json['cont'] == null || json['time'] == null || json['path'] == null) {
      throw Exception("Invalid item: $json");
    }

    return Item(
      id: json['cont'] as int,
      time: json['time'] as String,
      path: json['path'] as String,
    );
  }
}

class TickethistoryState extends State<Tickethistory> {
  List<Item> schedules = [];
  Item? selectedSchedule;
  int? selectedScheduleId;
  List<dynamic> seats = [];
  List<Station> stations = [];
  Station? selectedOrigin;
  Station? selectedDestination;
  Future<List<Reservation>>? _reservationsFuture;

  Future<List<Reservation>> fetchReservations() async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    final response = await http.get(
      Uri.parse('$baseUrl/my-reservations'),
      headers: {
        'Authorization': 'Bearer ${widget.token}',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Reservation>.from(
        data.map((json) => Reservation.fromJson(json)),
      );
    } else {
      throw Exception('Failed to load reservation history');
    }
  }

  Future<void> cancelReservation(int reservationId) async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    final response = await http.put(
      Uri.parse('$baseUrl/cancel-reservation/$reservationId'),
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ยกเลิกการจองสำเร็จ')),
      );

      setState(() {
        _reservationsFuture = fetchReservations(); // โหลดใหม่
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: ${response.body}')),
      );
    }
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

  Future<List<Item>> fetchItems() async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    final response = await http.get(Uri.parse('$baseUrl/timetable'));
    print("Response: ${response.body}");

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);

      // debug ตรวจดูว่าเป็น List จริงมั้ย
      if (decoded is List) {
        return decoded
            .where((itemJson) =>
                itemJson != null &&
                itemJson['cont'] != null &&
                itemJson['time'] != null &&
                itemJson['path'] != null)
            .map<Item>((itemJson) => Item.fromJson(itemJson))
            .toList();
      } else {
        throw Exception('Unexpected response format: ${response.body}');
      }
    } else {
      throw Exception('Failed to load items');
    }
  }

  Future<void> fetchSeats(int scheduleId) async {
    if (selectedOrigin == null || selectedDestination == null) return;
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    final response = await http.get(
      Uri.parse('$baseUrl/seat-reservations'),
      headers: {
        'Authorization': 'Bearer ${widget.token}',
      },
    );

    if (response.statusCode == 200) {
      final allReservations = json.decode(response.body);
      const totalSeats = 16;

      final userOriginOrdinal = selectedOrigin!.ordinalNum;
      final userDestinationOrdinal = selectedDestination!.ordinalNum;

      List<Map<String, dynamic>> allSeatStatus = [];

      for (int seatNo = 1; seatNo <= totalSeats; seatNo++) {
        String status = 'available';

        for (var res in allReservations) {
          if (res['seat_no'] == seatNo && res['schedule_id'] == scheduleId) {
            final int resOrigin = res['origin_ordinal'];
            final int resDest = res['destination_ordinal'];

            final bool overlap = !(userDestinationOrdinal <= resOrigin ||
                userOriginOrdinal >= resDest);
            if (overlap) {
              status = 'booked';
              break;
            }
          }
        }

        allSeatStatus.add({'seat_no': seatNo, 'status': status});
      }

      setState(() {
        seats = allSeatStatus;
      });
    } else {
      throw Exception('Failed to load seat reservations');
    }
  }

  void showCancelConfirmationDialog(
    int reservationId,
    String seatNo,
    String originName,
    String destinationName,
    String time,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("ยืนยันการยกเลิกการจอง"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("ที่นั่ง: $seatNo"),
              Text("ต้นทาง: $originName"),
              Text("ปลายทาง: $destinationName"),
              Text("รอบเวลา: $time"),
              const SizedBox(height: 16),
              const Text("คุณต้องการยกเลิกการจองนี้หรือไม่?"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child:
                  const Text("ไม่ยกเลิก", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                cancelReservation(reservationId);
              },
              child: const Text("ยืนยัน"),
            ),
          ],
        );
      },
    );
  }

  String getScheduleTimeById(int id) {
    final item = schedules.firstWhere(
      (item) => item.id == id,
      orElse: () => Item(id: 0, time: 'ไม่พบเวลา', path: ''),
    );
    return item.time;
  }

  String getBusStopNameById(int id) {
    final stop = stations.firstWhere(
      (station) => station.id == id,
      orElse: () => Station(
          id: 0,
          busstopname: 'ไม่พบชื่อป้าย',
          latitude: 0,
          longitude: 0,
          ordinalNum: 0),
    );
    return stop.busstopname;
  }

  @override
  void initState() {
    super.initState();
    loadSchedules();
    fetchStations();
    _reservationsFuture = fetchReservations(); // ✅ เพิ่มตรงนี้
  }

  Future<void> loadSchedules() async {
    schedules = await fetchItems();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color.fromRGBO(0, 185, 255, 1),
          title: const Text('จองที่นั่ง'),
          actions: const <Widget>[
            Image(image: AssetImage('assets/kmitlfight.png')),
          ],
        ),
        body: Container(
          height: double.infinity, // ให้เต็มความสูงหน้าจอ
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
          child: SingleChildScrollView(
            child: Center(
              child: Container(
                child: Column(
                  children: [
                    FutureBuilder<List<Reservation>>(
                      future: _reservationsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        } else if (snapshot.hasError) {
                          return Text('Error: ${snapshot.error}');
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return const Text('ไม่มีประวัติการจอง');
                        } else {
                          final reservations = snapshot.data!;
                          return ListView.builder(
                            shrinkWrap: true,
                            itemCount: reservations.length,
                            itemBuilder: (context, index) {
                              final res = reservations[index];
                              return ListTile(
                                title: Text(
                                    'ที่นั่ง ${res.seatNo} - ${res.status}'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'จาก: ${getBusStopNameById(res.originStopId)} → ปลายทาง: ${getBusStopNameById(res.destinationStopId)}',
                                    ),
                                    Text(
                                        'รอบเวลา: ${getScheduleTimeById(res.scheduleId)}'),
                                    Text(
                                        'วันที่ทำการจอง: ${res.reservationDate.toLocal().toString().split(' ')[0]}'),
                                  ],
                                ),
                                trailing: res.status != 'ยกเลิก'
                                    ? IconButton(
                                        icon: Icon(Icons.cancel,
                                            color: Colors.red),
                                        onPressed: () {
                                          final origin = stations.firstWhere(
                                            (s) => s.id == res.originStopId,
                                            orElse: () => Station(
                                              id: 0,
                                              busstopname: 'ไม่ทราบ',
                                              latitude: 0,
                                              longitude: 0,
                                              ordinalNum: 0,
                                            ),
                                          );
                                          final destination =
                                              stations.firstWhere(
                                            (s) =>
                                                s.id == res.destinationStopId,
                                            orElse: () => Station(
                                              id: 0,
                                              busstopname: 'ไม่ทราบ',
                                              latitude: 0,
                                              longitude: 0,
                                              ordinalNum: 0,
                                            ),
                                          );
                                          final schedule = schedules.firstWhere(
                                            (s) => s.id == res.scheduleId,
                                            orElse: () => Item(
                                              id: 0,
                                              time: 'ไม่ทราบ',
                                              path: '-',
                                            ),
                                          );

                                          showCancelConfirmationDialog(
                                            res.reservationId,
                                            res.seatNo.toString(),
                                            origin.busstopname,
                                            destination.busstopname,
                                            schedule.time,
                                          );
                                        },
                                      )
                                    : const Text("ยกเลิกแล้ว",
                                        style: TextStyle(color: Colors.grey)),
                              );
                            },
                          );
                        }
                      },
                    )
                  ],
                ),
              ),
            ),
          ),
        ));
  }
}
