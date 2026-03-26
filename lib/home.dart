import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'Locationprovider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:marquee/marquee.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

final PageController _pageController = PageController();

class Station {
  final int id;
  final String busstopname;
  final double latitude;
  final double longitude;
  final bool status;

  Station({
    required this.id,
    required this.busstopname,
    required this.latitude,
    required this.longitude,
    required this.status,
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json['bus_stop_id'],
      busstopname: json['bus_stop_name'],
      latitude: double.tryParse(json['latitude'].toString()) ?? 0.0,
      longitude: double.tryParse(json['longitude'].toString()) ?? 0.0,
      status: json['status'] ?? false,
    );
  }
}

class Announcement {
  final String text;

  Announcement({required this.text});

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      text: json['announcements_text'],
    );
  }
}

class FeedItem {
  final String imageUrl;
  final String description;

  FeedItem({required this.imageUrl, required this.description});

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    return FeedItem(
      imageUrl: json['pictureUrl'], // ✅ ใช้อันที่ API ส่งมา
      description: json['text'], // ✅ ใช้ฟิลด์ text เป็นคำอธิบาย
    );
  }
}

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => HomePageState();
}

class HomePageState extends State<Homepage> {
  List<Station> stations = [];

  List<Announcement> announcements = [];

  Future<void> fetchAnnouncements() async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    final response = await http.get(
      Uri.parse('$baseUrl/announcements'),
    );
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      setState(() {
        announcements = data.map((e) => Announcement.fromJson(e)).toList();
      });
    } else {
      print("❌ โหลดประกาศไม่สำเร็จ: ${response.statusCode}");
    }
  }

  Set<Marker> getStationMarkers(List<Station> stations) {
    return stations.map((station) {
      return Marker(
        markerId: MarkerId(station.id.toString()),
        position: LatLng(station.latitude, station.longitude),
        infoWindow: InfoWindow(title: station.busstopname),
      );
    }).toSet();
  }

  List<FeedItem> feedItems = [];
  Future<void> fetchFeed() async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    final response = await http.get(
      Uri.parse('$baseUrl/images'),
    );
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      setState(() {
        feedItems = data.map((item) => FeedItem.fromJson(item)).toList();
      });
    } else {
      print('❌ โหลด feed ไม่สำเร็จ');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
    }
  }

  BitmapDescriptor busStopIcon = BitmapDescriptor.defaultMarker;

  LatLng driverLocation =
      const LatLng(0.0, 0.0); // กำหนดค่าเริ่มต้นให้กับตำแหน่งคนขับ
  Future<void> fetchLatestDriverLocation() async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    final response = await http.get(
      Uri.parse('$baseUrl/latest_driver_location'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      double latitude = data['latitude'];
      double longitude = data['longitude'];

      setState(() {
        driverLocation = LatLng(latitude, longitude);
      });
    } else {
      print("❌ ไม่พบตำแหน่งคนขับภายใน 10 นาทีล่าสุด");
    }
  }

  Future<void> fetchDriverLocation(String driverId) async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    final response = await http.get(
      Uri.parse('$baseUrl/latest_driver_location'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      double latitude = data['latitude'];
      double longitude = data['longitude'];

      setState(() {
        driverLocation = LatLng(latitude, longitude);
      });
    } else {
      throw Exception('Failed to load driver location');
    }
  }

  // 📥 ดึงข้อมูลจุดจอดจาก API
  Future<void> fetchStations() async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    final response = await http.get(Uri.parse('$baseUrl/bus_stop'));
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      setState(() {
        stations = data.map((json) => Station.fromJson(json)).toList();
        print(
            'Stations loaded: ${stations.length}'); // เช็กว่าโหลดข้อมูลได้หรือไม่
      });
    } else {
      throw Exception('Failed to load stations');
    }
  }

  BitmapDescriptor custommark = BitmapDescriptor.defaultMarker;
  Timer? locationTimer; // เพิ่มตรงนี้
  @override
  void initState() {
    super.initState();
    setCustomMark();
    fetchStations();
    fetchFeed();
    fetchAnnouncements();
    fetchLatestDriverLocation();
    Timer.periodic(const Duration(seconds: 10), (timer) {
      fetchLatestDriverLocation(); // 🔁 โหลดตำแหน่ง driver ใหม่ทุก 10 วิ
    });
  }

  @override
  void dispose() {
    // ยกเลิก timer เมื่อ widget หายไป
    locationTimer?.cancel();
    super.dispose();
  }

  void setCustomMark() async {
    final BitmapDescriptor customIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(16, 16)),
      'assets/location-arrow.png',
    );
    final BitmapDescriptor customStopIcon =
        await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(16, 16)),
      'assets/pin.png',
    );
    setState(() {
      custommark = customIcon;
      busStopIcon = customStopIcon;
    });
  }

  Set<Marker> getMarkers(LatLng driverLocation) {
    Set<Marker> markers = stations.map((station) {
      return Marker(
          markerId: MarkerId(station.id.toString()),
          position: LatLng(station.latitude, station.longitude),
          infoWindow: InfoWindow(title: station.busstopname),
          icon: busStopIcon);
    }).toSet();
    // เฉพาะเมื่อ driverLocation ไม่ใช่ตำแหน่งเริ่มต้น
    if (driverLocation.latitude != 0.0 && driverLocation.longitude != 0.0) {
      markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: driverLocation,
        icon: custommark,
        infoWindow: const InfoWindow(title: "Bus"),
      ));
    }

    print('Markers count: ${markers.length}'); // เช็กว่า marker สร้างครบหรือไม่
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    print(
        "🚗 Driver Location: ${driverLocation.latitude}, ${driverLocation.longitude}");

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color.fromRGBO(0, 185, 255, 1),
          title: const Text(
            'PCC Bus Tracking',
          ),
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
        body: Stack(
          children: [
            // ✅ พื้นหลัง gradient เต็มจอ
            Container(
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
            ),
            RefreshIndicator(
              onRefresh: () async {
                await fetchStations();
                await fetchFeed();
                await fetchLatestDriverLocation();
                await fetchAnnouncements();
              },
              // ✅ เนื้อหาอยู่ด้านบน พร้อใส่ scroll ได้ และจัดกึ่งกลาง
              child: SingleChildScrollView(
                child: Center(
                  child: Container(
                    width: 800,
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Column(
                      children: [
                        Container(
                          height: 30,
                          color: Colors.blue.shade100,
                          child: Marquee(
                            text: announcements.isEmpty
                                ? '📢 ยินดีต้อนรับสู่ PCC Bus Tracking'
                                : announcements
                                    .map((a) => a.text)
                                    .join('     ⏺     '),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                            scrollAxis: Axis.horizontal,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            blankSpace: 80.0,
                            velocity: 50.0,
                            pauseAfterRound: const Duration(seconds: 1),
                            startPadding: 10.0,
                            accelerationDuration: const Duration(seconds: 1),
                            accelerationCurve: Curves.linear,
                            decelerationDuration:
                                const Duration(milliseconds: 500),
                            decelerationCurve: Curves.easeOut,
                          ),
                        ),
                        const SizedBox(
                          height: 5,
                        ),
                        Consumer<LocationProvider>(
                          builder: (context, locationProvider, _) {
                            return SizedBox(
                              width: 345,
                              height: 350,
                              child: GoogleMap(
                                initialCameraPosition: const CameraPosition(
                                  target: LatLng(10.722179, 99.374701),
                                  zoom: 14,
                                ),
                                mapType: MapType.hybrid,
                                markers: getMarkers(driverLocation),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 15),
                        const Row(
                          children: [
                            SizedBox(width: 10),
                            Text('ประชาสัมพันธ์',
                                style: TextStyle(fontSize: 18)),
                          ],
                        ),
                        const SizedBox(height: 15),
                        feedItems.isEmpty
                            ? const CircularProgressIndicator()
                            : SmoothPageIndicator(
                                controller: _pageController,
                                count: feedItems.length,
                                effect: WormEffect(
                                  dotWidth: 10,
                                  dotHeight: 10,
                                  activeDotColor:
                                      const Color.fromRGBO(227, 82, 5, 1),
                                  dotColor: Colors.grey.shade400,
                                ),
                              ),
                        SizedBox(
                          height: 350,
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: feedItems.length,
                            itemBuilder: (context, index) {
                              final item = feedItems[index];
                              return Column(
                                children: [
                                  const SizedBox(height: 10),
                                  Image.network(
                                    width: 280,
                                    item.imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(
                                        Icons.broken_image,
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 5),
                                  Text(item.description),
                                  const SizedBox(
                                    height: 20,
                                  )
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
