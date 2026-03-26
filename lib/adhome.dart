import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class Adhome extends StatefulWidget {
  const Adhome({super.key});

  // final String token;
  //const Adhome({super.key, required this.token});
  @override
  State<Adhome> createState() => adminstate();
}

class adminstate extends State<Adhome> {
  final _ctrlsubtext = TextEditingController();
  final _ctrltext = TextEditingController();
  File? _image;

  List<Map<String, dynamic>> uploadedImages = [];

  Future<void> fetchUploadedImages() async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    try {
      final response = await http.get(Uri.parse('$baseUrl/images'));
      print('📦 RESPONSE BODY: ${response.body}');
      print('📦 Status Code: ${response.statusCode}');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          uploadedImages = data.cast<Map<String, dynamic>>();
        });
      } else {
        print('❌ ไม่สามารถโหลดรูปภาพได้');
      }
    } catch (e) {
      print('❌ เกิดข้อผิดพลาดในการโหลดรูปภาพ: $e');
    }
  }

  Future<void> deleteImage(int id) async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    final response = await http.delete(
      Uri.parse('$baseUrl/images/$id'),
    );
    if (response.statusCode == 204) {
      fetchUploadedImages(); // รีโหลดภาพใหม่
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ ลบรูปภาพแล้ว')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ ลบไม่สำเร็จ: ${response.body}')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    fetchUploadedImages();
    fetchTextAnnouncements();
  }

  // เลือกรูปจากแกลเลอรี่
  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  List<Map<String, dynamic>> textAnnouncements = [];

  Future<void> fetchTextAnnouncements() async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    try {
      final response = await http.get(Uri.parse('$baseUrl/announcements'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          textAnnouncements = data.cast<Map<String, dynamic>>();
        });
      } else {
        print('❌ โหลดประกาศไม่สำเร็จ');
      }
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  Future<void> addTextAnnouncement() async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    final text = _ctrltext.text;
    if (text.isEmpty) return;

    final response = await http.post(
      Uri.parse('$baseUrl/announcements'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'announcements_text': text}),
    );

    if (response.statusCode == 201) {
      _ctrltext.clear();
      fetchTextAnnouncements();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('✅ เพิ่มประกาศแล้ว')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ เพิ่มไม่สำเร็จ: ${response.body}')));
    }
  }

  Future<void> deleteTextAnnouncement(int id) async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    final response = await http.delete(
      Uri.parse('$baseUrl/announcements/$id'),
    );
    if (response.statusCode == 204) {
      fetchTextAnnouncements();
    }
  }

  Future<String?> uploadToCloudinary(File imageFile) async {
    final url = Uri.parse(dotenv.env['CLOUDINARY_URL'] ?? '');
    final preset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';

    if (url.toString().isEmpty || preset.isEmpty) {
      print('❌ ไม่พบ CLOUDINARY_URL หรือ UPLOAD_PRESET ใน .env');
      return null;
    }

    final request = http.MultipartRequest('POST', url);
    request.fields['upload_preset'] = preset;
    request.files
        .add(await http.MultipartFile.fromPath('file', imageFile.path));

    try {
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = json.decode(responseBody);
        return data['secure_url'];
      } else {
        print('❌ Upload failed: ${response.statusCode}');
        print('Body: $responseBody');
        return null;
      }
    } catch (e) {
      print('❌ Upload error: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(0, 185, 255, 1),
        title: const Text('หน้าหลักผู้ดูแลระบบ'),
        actions: const <Widget>[
          Image(image: AssetImage('assets/kmitlfight.png'))
        ],
      ),
      body: Center(
        child: Container(
          width: 800,
          decoration: const BoxDecoration(
              gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [
              Color.fromRGBO(0, 185, 255, 1),
              Colors.white,
            ],
          )),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Column(
              children: [
                const SizedBox(
                  height: 45,
                ),
                Container(
                  width: 280,
                  height: 125,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    shape: BoxShape.rectangle,
                    color: Colors.blue[50],
                  ),
                  child: Column(
                    children: [
                      const Row(children: [
                        SizedBox(
                          width: 20,
                        ),
                        Text(
                          'แนบรูปประชาสัมพันธ์',
                          textScaleFactor: 1.5,
                        ),
                      ]),
                      const SizedBox(
                        height: 20,
                        width: 200,
                      ),
                      Row(
                        children: [
                          const SizedBox(
                            width: 20,
                          ),
                          SizedBox(
                            width: 150,
                            child: TextField(
                              controller: _ctrlsubtext,
                              decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  hintText: 'คำอธิบายรูป'),
                              style: const TextStyle(
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: 2,
                          ),
                          SizedBox(
                            child: IconButton(
                              onPressed: () => _pickImage(),
                              icon: const Icon(Icons.add_a_photo_outlined),
                            ),
                          ),
                          SizedBox(
                            child: IconButton(
                              onPressed: () async {
                                if (_image != null) {
                                  final imageUrl =
                                      await uploadToCloudinary(_image!);

                                  if (imageUrl != null) {
                                    print(
                                        '📸 อัปโหลดเสร็จแล้ว! URL: $imageUrl');

                                    final response = await http.post(
                                      Uri.parse(
                                          'https://pccbustracking-production.up.railway.app/upload-image-url'),
                                      headers: {
                                        'Content-Type': 'application/json'
                                      },
                                      body: jsonEncode({
                                        'imageUrl': imageUrl,
                                        'text': _ctrlsubtext.text
                                      }),
                                    );

                                    if (response.statusCode == 200 ||
                                        response.statusCode == 201) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text("✅ อัปโหลดสำเร็จ")),
                                      );
                                      _ctrlsubtext.clear();
                                      setState(() {
                                        _image = null;
                                      });
                                      fetchUploadedImages(); // รีเฟรชรายการภาพ
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                "❌ บันทึก URL ไม่สำเร็จ: ${response.body}")),
                                      );
                                    }
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text("❌ อัปโหลดรูปไม่สำเร็จ")),
                                    );
                                  }
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text("กรุณาเลือกรูปก่อน")),
                                  );
                                }
                              },
                              icon: const Icon(Icons.send_outlined),
                            ),
                          ),
                          const Column(
                            children: [],
                          )
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                Container(
                  width: 280,
                  height: 125,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    shape: BoxShape.rectangle,
                    color: Colors.blue[50],
                  ),
                  child: Column(
                    children: [
                      const Row(children: [
                        SizedBox(
                          width: 20,
                        ),
                        Text(
                          'เพิ่มประกาศ',
                          textScaleFactor: 1.3,
                        ),
                      ]),
                      const SizedBox(
                        height: 10,
                        width: 200,
                      ),
                      Row(
                        children: [
                          const SizedBox(
                            width: 20,
                          ),
                          SizedBox(
                            width: 200,
                            child: TextField(
                              controller: _ctrltext,
                              decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  hintText: 'ข้อความประกาศ'),
                              style: const TextStyle(
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          SizedBox(
                            child: IconButton(
                                onPressed: addTextAnnouncement,
                                icon: const Icon(Icons.send_outlined)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 5,
                ),
                const Row(
                  children: [
                    SizedBox(
                      width: 40,
                    ),
                    Text(
                      'การประชาสัมพันธ์',
                      textScaleFactor: 1.5,
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                const Row(
                  children: [
                    SizedBox(width: 40),
                    Text(
                      'ประกาศทั่วไป',
                      textScaleFactor: 1.5,
                    ),
                  ],
                ),
                Column(
                  children: textAnnouncements.map((announcement) {
                    final text = announcement['announcements_text'] ?? '';
                    final id = announcement['post_id'];

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      width: 350,
                      decoration: BoxDecoration(
                        color: Colors.yellow[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        title: Text(
                          text,
                          style: const TextStyle(fontSize: 16),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_forever,
                              color: Colors.red),
                          onPressed: () => deleteTextAnnouncement(id),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(
                  height: 30,
                ),
                Column(
                  children: uploadedImages.map((imgData) {
                    final imageUrl = imgData['pictureUrl'];
                    final text = imgData['text'];
                    final postId = imgData['post_id'];

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      width: 350,
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 🔹 แถวข้อความ + ปุ่มลบ/แก้ไข
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    text ?? "ไม่มีข้อความ",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit,
                                          color: Colors.blue),
                                      onPressed: () {
                                        final editCtrl =
                                            TextEditingController(text: text);
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title:
                                                const Text("แก้ไขคำอธิบายรูป"),
                                            content:
                                                TextField(controller: editCtrl),
                                            actions: [
                                              TextButton(
                                                child: const Text("ยกเลิก"),
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                              ),
                                              TextButton(
                                                child: const Text("บันทึก"),
                                                onPressed: () async {
                                                  final newText =
                                                      editCtrl.text.trim();
                                                  if (newText.isNotEmpty) {
                                                    final response =
                                                        await http.put(
                                                      Uri.parse(
                                                          'https://pccbustracking-production.up.railway.app/images/$postId'),
                                                      headers: {
                                                        'Content-Type':
                                                            'application/json'
                                                      },
                                                      body: jsonEncode(
                                                          {'text': newText}),
                                                    );
                                                    if (response.statusCode ==
                                                        200) {
                                                      fetchUploadedImages();
                                                      Navigator.pop(context);
                                                    }
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_forever,
                                          color: Colors.red),
                                      onPressed: () {
                                        if (postId != null) {
                                          deleteImage(postId);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // 🔹 แสดงรูปถ้ามี
                          if (imageUrl != null && imageUrl.isNotEmpty)
                            Center(
                              child: Image.network(
                                imageUrl,
                                width: 300,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Text("⚠️ โหลดรูปไม่สำเร็จ"),
                              ),
                            ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
