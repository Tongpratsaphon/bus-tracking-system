import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'tickethistory.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Ticket extends StatefulWidget {
  final String token;
  const Ticket({super.key, required this.token});

  @override
  State<Ticket> createState() => TicketState();
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
  final int originOrdinal;
  final int destinationOrdinal;

  Reservation({
    required this.reservationId,
    required this.scheduleId,
    required this.seatNo,
    required this.status,
    required this.userId,
    required this.reservationDate,
    required this.originStopId,
    required this.destinationStopId,
    required this.originOrdinal,
    required this.destinationOrdinal,
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
      originOrdinal: json['origin_ordinal'],
      destinationOrdinal: json['destination_ordinal'],
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

class TicketState extends State<Ticket> {
  List<Item> schedules = [];
  Item? selectedSchedule;
  int? selectedScheduleId;
  List<dynamic> seats = [];
  List<Station> stations = [];
  Station? selectedOrigin;
  Station? selectedDestination;

  int? selectedSeat;

  void toggleSeatSelection(int seatNo) {
    setState(() {
      if (selectedSeat == seatNo) {
        selectedSeat = null; // ยกเลิกเลือก
      } else {
        selectedSeat = seatNo;
      }
    });
  }

  bool isSeatAvailable(
    int seatNo,
    List<Reservation> allReservations,
    int selectedScheduleId,
    int userOriginOrdinal,
    int userDestinationOrdinal,
  ) {
    for (var res in allReservations) {
      if (res.seatNo == seatNo && res.scheduleId == selectedScheduleId) {
        // เงื่อนไขทับซ้อนของช่วงต้นทาง-ปลายทาง
        bool overlap = !(userDestinationOrdinal <= res.originOrdinal ||
            userOriginOrdinal >= res.destinationOrdinal);
        if (overlap) return false;
      }
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    loadSchedules();
    fetchStations();
  }

  Future<void> loadSchedules() async {
    schedules = await fetchItems();
    setState(() {});
  }

  Future<Map<String, dynamic>?> fetchUserProfile() async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    final url = Uri.parse('$baseUrl/me');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      print('Failed to load user profile: ${response.statusCode}');
      return null;
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
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    if (selectedOrigin == null || selectedDestination == null) return;

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
          if (res['seat_no'] == seatNo &&
              res['schedule_id'] == scheduleId &&
              res['status'] == 'booked') {
            // <-- เพิ่มบรรทัดนี้
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

  Future<void> bookSeat(int seatNo) async {
    if (selectedScheduleId == null ||
        selectedOrigin == null ||
        selectedDestination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('กรุณาเลือกต้นทาง ปลายทาง และรอบเดินรถก่อนจอง')),
      );
      return;
    }

    // ใช้ token จาก widget.token เลย
    final token = widget.token;
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อนทำการจอง')),
      );
      return;
    }
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    final response = await http.post(
      Uri.parse('$baseUrl/book-seat'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        "schedule_id": selectedScheduleId,
        "seat_no": seatNo,
        "origin_stop_id": selectedOrigin!.id,
        "destination_stop_id": selectedDestination!.id,
      }),
    );

    if (response.statusCode == 200) {
      await fetchSeats(selectedScheduleId!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('จองสำเร็จ')),
      );
    } else {
      final errorMsg = json.decode(response.body)['message'] ?? 'จองไม่สำเร็จ';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
    }
  }

  Future<List<Reservation>> fetchReservations() async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    final response = await http.get(
      Uri.parse('$baseUrl/seat-reservations'),
      headers: {
        'Authorization': 'Bearer ${widget.token}',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data as List).map((e) => Reservation.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load seat reservations');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
              width: 800,
              padding: const EdgeInsets.all(16),
              // ย้าย gradient ออกไปแล้ว ไม่ต้องใส่ decoration ที่นี่
              child: Column(
                children: [
                  DropdownButton<Station>(
                    hint: const Text("เลือกต้นทาง"),
                    value: selectedOrigin,
                    items: stations.map((station) {
                      return DropdownMenuItem<Station>(
                        value: station,
                        child: Text(station.busstopname),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedOrigin = value;
                      });
                      if (selectedScheduleId != null &&
                          selectedDestination != null) {
                        fetchSeats(selectedScheduleId!);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButton<Station>(
                    hint: const Text("เลือกปลายทาง"),
                    value: selectedDestination,
                    items: stations.map((station) {
                      return DropdownMenuItem<Station>(
                        value: station,
                        child: Text(station.busstopname),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedDestination = value;
                      });
                      if (selectedScheduleId != null &&
                          selectedOrigin != null) {
                        fetchSeats(selectedScheduleId!);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  DropdownButton<Item>(
                    hint: const Text("เลือกรอบเดินรถ"),
                    value: selectedSchedule,
                    items: schedules.map((Item item) {
                      return DropdownMenuItem<Item>(
                        value: item,
                        child: Text("${item.time} (${item.path})"),
                      );
                    }).toList(),
                    onChanged: (Item? value) {
                      print("เลือกรอบเดินรถ: ${value?.id}");
                      setState(() {
                        selectedSchedule = value;
                        selectedScheduleId = value?.id;
                      });
                      if (value != null) fetchSeats(value.id);
                    },
                  ),
                  const SizedBox(height: 20),
                  // ใส่ GridView.builder แบบนี้แทน
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: seats.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemBuilder: (context, index) {
                      final seat = seats[index];
                      final seatNo = seat['seat_no'];
                      final status = seat['status'];

                      final isSelected = selectedSeat == seatNo;
                      final isBooked = status == 'booked';

                      return ElevatedButton(
                        onPressed:
                            isBooked ? null : () => toggleSeatSelection(seatNo),
                        style: ButtonStyle(
                          backgroundColor:
                              MaterialStateProperty.resolveWith<Color>(
                                  (states) {
                            if (states.contains(MaterialState.disabled)) {
                              return Colors.red; // สีปุ่มเมื่อ disable
                            }
                            if (isSelected) {
                              return Colors.blue;
                            }
                            return Colors.green;
                          }),
                          foregroundColor:
                              MaterialStateProperty.all<Color>(Colors.white),
                        ),
                        child: Text('$seatNo'),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: selectedSeat == null
                        ? null
                        : () async {
                            final seatNo = selectedSeat!;

                            final selectedTime = selectedSchedule?.time ?? "-";

                            // ดึงข้อมูล user จาก backend
                            final user = await fetchUserProfile();

                            // แสดง popup ยืนยัน
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('ยืนยันการจอง'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          'ชื่อผู้ใช้: ${user?['first_name'] ?? "-"} ${user?['last_name'] ?? "-"}'),
                                      Text(
                                          'ต้นทาง: ${selectedOrigin?.busstopname ?? "-"}'),
                                      Text(
                                          'ปลายทาง: ${selectedDestination?.busstopname ?? "-"}'),
                                      Text('เวลาที่จอง: $selectedTime'),
                                      Text('หมายเลขที่นั่ง: $seatNo'),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: const Text('ยกเลิก'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () async {
                                        Navigator.of(context)
                                            .pop(); // ปิด popup
                                        await bookSeat(seatNo);
                                        setState(() {
                                          selectedSeat = null;
                                        });
                                      },
                                      child: const Text('ยืนยัน'),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 12),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                    child: const Text('ยืนยันการจอง'),
                  ),
                  SizedBox(
                    height: 20,
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              Tickethistory(token: widget.token),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromARGB(255, 227, 127, 50),
                      textStyle:
                          TextStyle(color: Color.fromRGBO(102, 102, 102, 1)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: const Text(
                      'ดูประวัติการจอง',
                      style: TextStyle(color: Color.fromRGBO(102, 102, 102, 1)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ));
}
