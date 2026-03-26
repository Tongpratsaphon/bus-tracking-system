import 'package:flutter/material.dart';
import 'package:myapp/Locationprovider.dart';
import 'package:myapp/buspage.dart';
import 'package:myapp/home.dart';
import 'package:myapp/login.dart';
import 'package:myapp/time.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  // โหลด .env ก่อนรันแอป
  await dotenv.load(fileName: ".env");
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => LocationProvider()),
      ],
      child: const Myapp(),
    ),
  );
  //runApp(
  //  const Myapp(),
  //);
}

class Myapp extends StatelessWidget {
  const Myapp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(home: Mainpage());
}

class Mainpage extends StatefulWidget {
  const Mainpage({super.key});
  @override
  State<Mainpage> createState() => MainpageState();
}

class MainpageState extends State<Mainpage> {
  var page = <Widget>[
    const Homepage(),
    const TimePage(),
    const Buspage(),
    const Login()
  ];
  int navitem = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: page[navitem],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: navitem,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          unselectedItemColor: Colors.black,
          selectedItemColor: Colors.orange[900],
          selectedFontSize: 10,
          unselectedFontSize: 10,
          onTap: (index) => setState(() {
            navitem = index;
          }),
          items: bottomNavItems(),
        ),
      );
  List<BottomNavigationBarItem> bottomNavItems() {
    var itemIcons = [
      Icons.home,
      Icons.calendar_today,
      Icons.bus_alert,
      Icons.login
    ];
    var itemLabels = ['หน้าหลัก', 'เวลา', 'สถานะรถ', 'เข้าสู่ระบบ'];
    var len = itemIcons.length;
    return List.generate(
        len,
        (index) => BottomNavigationBarItem(
              icon: Icon(itemIcons[index]),
              label: itemLabels[index],
            ));
  }
}
