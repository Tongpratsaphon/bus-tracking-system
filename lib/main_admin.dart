import 'package:flutter/material.dart';
import 'package:myapp/dashboard.dart';
import 'package:myapp/stationpage.dart';
import 'package:myapp/timeadmin.dart';
import 'adhome.dart';

class Mainpage_admin extends StatefulWidget {
  final String token;
  const Mainpage_admin({super.key, required this.token});
  @override
  State<Mainpage_admin> createState() => Mainpage_adminState();
}

class Mainpage_adminState extends State<Mainpage_admin> {
  var page = <Widget>[
    const Adhome(),
    const Timeadmin(),
    const Stationpage(),
    // const Dashboard(),
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
      Icons.pin_drop_outlined,
      // Icons.dashboard_customize_outlined,
    ];
    var itemLabels = [
      'หน้าหลัก',
      'เวลา',
      'จัดการจุดรับส่ง',
      //'แดชบอร์ด',
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
