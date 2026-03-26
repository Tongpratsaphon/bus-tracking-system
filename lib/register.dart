import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController emailController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  void _submitForm() async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    if (_formKey.currentState!.validate()) {
      final email = emailController.text;
      final firstName = firstNameController.text;
      final lastName = lastNameController.text;
      final username = usernameController.text;
      final password = passwordController.text;
      final phone = phoneController.text;

      final url = Uri.parse('$baseUrl/register'); // 🔁 เปลี่ยนให้ตรง

      try {
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'first_name': firstName,
            'last_name': lastName,
            'username': username,
            'password': password,
            'phone': phone,
          }),
        );

        final responseData = jsonDecode(response.body);

        if (response.statusCode == 200) {
          // สำเร็จ
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Register success, please check email')),
          );
          Navigator.pop(context); // หรือไปหน้า login
        } else {
          // ล้มเหลว
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Error: ${responseData['error'] ?? 'Unknown error'}')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Register"),
        backgroundColor: const Color.fromRGBO(0, 185, 255, 1),
        actions: <Widget>[
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              shape: BoxShape.rectangle,
            ),
            child: const Image(
              image: AssetImage('assets/kmitlfight.png'),
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
      body: Container(
        height: double.infinity,
        width: double.infinity,
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
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                      labelText: 'email ที่ตามด้วย@kmitl.ac.th'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email is required';
                    } else if (!RegExp(r'^[\w\.-]+@kmitl\.ac\.th$')
                        .hasMatch(value)) {
                      return 'Email must end with @kmitl.ac.th';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: firstNameController,
                  decoration: const InputDecoration(labelText: 'ชื่อจริง'),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'กรุณากรอกชื่อ' : null,
                ),
                TextFormField(
                  controller: lastNameController,
                  decoration: const InputDecoration(labelText: 'นามสกุล'),
                  validator: (value) => value == null || value.isEmpty
                      ? 'กรุณากรอกนามสกุล'
                      : null,
                ),
                TextFormField(
                  controller: usernameController,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: (value) => value == null || value.length < 3
                      ? 'Min 3 characters'
                      : null,
                ),
                TextFormField(
                  controller: passwordController,
                  decoration:
                      const InputDecoration(labelText: 'Password อย่างน้อย4'),
                  obscureText: true,
                  validator: (value) => value == null || value.length < 4
                      ? 'Min 4 characters'
                      : null,
                ),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'เบอร์โทรศัพท์'),
                  keyboardType: TextInputType.phone,
                  validator: (value) => value == null || value.length < 9
                      ? 'กรอกให้ครบ 10 ตัวเลข'
                      : null,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0288D1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('สมัครสมาชิก'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
