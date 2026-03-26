import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'model/item.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Timeadmin extends StatefulWidget {
  const Timeadmin({super.key});

  @override
  State<Timeadmin> createState() => TimeadminState();
}

class TimeadminState extends State<Timeadmin> {
  late Future<List<Item>> futureItems;

  @override
  void initState() {
    super.initState();
    futureItems = fetchItems(); // เรียกใช้ฟังก์ชัน fetchItems
  }

  // ฟังก์ชันดึงข้อมูลจาก API
  Future<List<Item>> fetchItems() async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    final response = await http.get(Uri.parse('$baseUrl/timetable'));

    if (response.statusCode == 200) {
      // แปลง JSON เป็น List<Item>
      List<dynamic> itemsJson =
          json.decode(response.body); // แปลง JSON ให้เป็น List
      return itemsJson
          .map((itemJson) => Item.fromJson(itemJson))
          .toList(); // แปลงเป็น List<Item>
    } else {
      throw Exception('Failed to load items');
    }
  }

  Future<void> _deleteItem(Item item) async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    final response = await http.delete(
      Uri.parse('$baseUrl/timetable/${item.cont}'), // ใช้ ID ใน URL
    );

    if (response.statusCode == 200) {
      setState(() {
        futureItems = fetchItems(); // โหลดข้อมูลใหม่
      });
    } else {
      print("Error deleting item: ${response.body}");
    }
  }

  void _confirmDelete(Item item) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('ยืนยันการลบ'),
          content: Text('ต้องการลบ "${item.time}" หรือไม่?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            ),
            TextButton(
              onPressed: () {
                _deleteItem(item);
                Navigator.pop(context);
              },
              child: const Text('ลบ', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _showEditTimeDialog(Item item) {
    TextEditingController timeController =
        TextEditingController(text: item.time);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('แก้ไขเวลา'),
          content: TextField(
            controller: timeController,
            decoration: const InputDecoration(labelText: 'เวลาใหม่'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  item.time = timeController.text; // อัปเดตเวลา
                });
                Navigator.pop(context);
              },
              child: const Text('บันทึก'),
            ),
          ],
        );
      },
    );
  }

  void _showAddTimeDialog(String path) {
    TextEditingController timeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('เพิ่มเวลาใหม่'),
          content: TextField(
            controller: timeController,
            decoration: const InputDecoration(labelText: 'เวลา'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            ),
            TextButton(
              onPressed: () async {
                String newTime = timeController.text;

                if (newTime.isNotEmpty) {
                  final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
                  // เรียก API เพื่อเพิ่มข้อมูลโดยไม่ส่ง count
                  final response = await http.post(
                    Uri.parse('$baseUrl/timetable'),
                    headers: {"Content-Type": "application/json"},
                    body: jsonEncode({
                      "time": newTime,
                      "path": path, // ส่งแค่ time กับ path
                    }),
                  );

                  if (response.statusCode == 201) {
                    setState(() {
                      futureItems = fetchItems(); // โหลดข้อมูลใหม่
                    });
                  } else {
                    print("Error: ${response.body}");
                  }
                }

                Navigator.pop(context);
              },
              child: const Text('เพิ่ม'),
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
        title: const Text(
          'ตารางการเดินรถ',
        ),
        actions: const <Widget>[
          Image(image: AssetImage('assets/kmitlfight.png'))
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
        child: FutureBuilder<List<Item>>(
          future: futureItems,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No items found.'));
            } else {
              final items = snapshot.data!;
              // แยกข้อมูลตามช่วงเวลา
              final morningItems =
                  items.where((item) => item.path == 'morning').toList();
              final lunchItems =
                  items.where((item) => item.path == 'lunch').toList();
              final eveningItems =
                  items.where((item) => item.path == 'evening').toList();

              return SingleChildScrollView(
                child: Center(
                  child: Column(
                    children: [
                      _buildTimeBlock('ช่วงเช้า', morningItems, 'morning'),
                      const SizedBox(height: 20),
                      _buildTimeBlock('ช่วงบ่าย', lunchItems, 'lunch'),
                      const SizedBox(height: 20),
                      _buildTimeBlock('ช่วงเย็น', eveningItems, 'evening'),
                    ],
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildTimeBlock(String title, List<Item> items, String path) {
    return Container(
      width: 350,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        shape: BoxShape.rectangle,
        color: Colors.blue[50],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const SizedBox(width: 20),
            Text(title, textScaleFactor: 1.5),
            IconButton(
                onPressed: () {
                  _showAddTimeDialog(path);
                },
                icon: const Icon(Icons.add)),
          ]),
          const SizedBox(height: 10),
          Column(
            children: items.map((item) {
              return ListTile(
                title: Text(item.time),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () {
                        _showEditTimeDialog(item);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        _confirmDelete(item);
                      },
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
