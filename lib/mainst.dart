import 'package:flutter/material.dart';
import 'package:myapp/buspage.dart';
import 'package:myapp/home.dart';
import 'package:myapp/Ticket.dart';
import 'package:myapp/time.dart';

class Mainpagest extends StatefulWidget {
  final String token;
  const Mainpagest({super.key, required this.token});
  @override
  State<Mainpagest> createState() => MainpagestState();
}

class MainpagestState extends State<Mainpagest> {
  late final List<Widget> page; // ใช้ late final



  @override
  void initState() {
    super.initState();
    page = [
      const Homepage(),
      const TimePage(),
      const Buspage(),
      Ticket(token: widget.token), // ✅ ตอนนี้เข้าถึง widget.token ได้
    ];
  }
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
      Icons.confirmation_number,
    ];
    var itemLabels = [
      'หน้าหลัก',
      'เวลา',
      'สถานะรถ',
      'จองที่นั่ง',
    ];
    var len = itemIcons.length;
    return List.generate(
        len,
        (index) => BottomNavigationBarItem(
              icon: Icon(itemIcons[index]),
              label: itemLabels[index],
            ));
  }
}
