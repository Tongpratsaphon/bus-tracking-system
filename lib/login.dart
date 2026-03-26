import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:myapp/driverpage.dart';
import 'package:myapp/main_admin.dart';
import 'package:myapp/mainst.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:myapp/register.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => LoginpageState();
}

class LoginpageState extends State<Login> {
  final formkey = GlobalKey<FormState>();
  final _ctrlid = TextEditingController();
  final _ctrlPassword = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  // ฟังก์ชันสำหรับส่งข้อมูล login ไปยัง server.js
  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final String email = _ctrlid.text;
    final String password = _ctrlPassword.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please enter both ID and Password';
      });
      return;
    }

    try {
      final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
      final response = await http.post(
        Uri.parse('$baseUrl/login'), // URL ของ server.js
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        // หาก login สำเร็จ
        final responseData = json.decode(response.body);
        print('Token: ${responseData['token']}'); // JWT token
        setState(() {
          _isLoading = false;
        });

        Map<String, dynamic> jwtDecode(String token) {
          final parts = token.split('.');
          final payload = parts[1];
          final normalized = _base64UrlDecode(payload);
          return json.decode(normalized);
        }

        final String token = responseData['token'];

        // นำ token มาแยกข้อมูล role จาก token
        final decodedToken = jwtDecode(token);
        final String role = decodedToken['role'];

        // ถ้า login สำเร็จ, เราจะไปยังหน้า Home หรือ Admin
        if (role == 'admin') {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => Mainpage_admin(token: token)),
          );
        }
        if (role == 'user') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => Mainpagest(token: token)),
          );
        }
        if (role == 'driver') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => Driverpage(token: token)),
          );
        }

        // สามารถนำ token ไปใช้งานต่อได้ เช่น เก็บไว้ใน SharedPreferences
      } else {
        // หากเกิดข้อผิดพลาด
        setState(() {
          _isLoading = false;
          _errorMessage = 'Login failed: ${response.body}';
        });
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Something went wrong. Please try again later.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color.fromRGBO(0, 185, 255, 1),
          title: const Text('Login Page'),
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
            child: Column(
              children: [
                const SizedBox(
                  height: 45,
                ),
                Image.asset(
                  'assets/image.png',
                  width: 150,
                ),
                const SizedBox(
                  child: Text(
                    'PCC Bus Tracking',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 45,
                ),
                Form(
                  child: SingleChildScrollView(
                    child: Column(children: [
                      SizedBox(
                        width: 275,
                        child: TextFormField(
                          controller: _ctrlid,
                          decoration: const InputDecoration(
                            hintText: 'email',
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      SizedBox(
                        width: 275,
                        child: TextFormField(
                          obscureText: true,
                          controller: _ctrlPassword,
                          decoration: const InputDecoration(
                            hintText: 'Password',
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => RegisterPage()),
                          );
                        },
                        child: const Text(
                          'register',
                          style: TextStyle(
                            color: Colors.purple,
                            fontSize: 14, // แนะนำเพิ่มขนาดให้ใหญ่ขึ้นด้วย
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 30,
                      ),
                      _isLoading
                          ? const CircularProgressIndicator()
                          : ElevatedButton(
                              onPressed: _login,
                              child: const Text('Login'),
                            ),
                      if (_errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

// ฟังก์ชันสำหรับ decode JWT token
  Map<String, dynamic> jwtDecode(String token) {
    final parts = token.split('.');
    final payload = parts[1];
    final normalized = _base64UrlDecode(payload);
    return json.decode(normalized);
  }

  String _base64UrlDecode(String input) {
    var output = input;
    output = output.replaceAll('-', '+').replaceAll('_', '/');
    switch (output.length % 4) {
      case 2:
        output = '$output==';
        break;
      case 3:
        output = '$output=';
        break;
    }
    return utf8.decode(base64Url.decode(output));
  }
}
