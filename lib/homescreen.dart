import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

void main() => runApp(Homescreen());

class Homescreen extends StatelessWidget {
  const Homescreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eco Ride',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: Colors.green.shade900,
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          selectedIconTheme: IconThemeData(color: Colors.green.shade900),
        ),
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    SearchPage(),
    RideHistoryScreen(),
    InboxScreen(),
    ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green.shade900,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
          BottomNavigationBarItem(icon: Icon(Icons.directions_car), label: "Your Rides"),
          BottomNavigationBarItem(icon: Icon(Icons.inbox), label: "Inbox"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
          
        ],
      ),
    );
  }
}



class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController passengerController = TextEditingController();

  Future<void> _getCurrentLocation(TextEditingController controller) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator()),
    );

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Navigator.pop(context);
        await Geolocator.openLocationSettings();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.deniedForever) {
          Navigator.pop(context);
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks[0];
        controller.text =
            "${place.street}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea}, ${place.country}";
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get location: $e')),
      );
    } finally {
      Navigator.pop(context);
    }
  }

  void _saveToFirebase() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('rides')
        .add({
      'from': fromController.text,
      'to': toController.text,
      'date': dateController.text,
      'passengers': passengerController.text,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'lib/assets/ssb.png',
              fit: BoxFit.cover,
            ),
          ),
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 40),
              child: Column(
                children: [
                  Text(
                    'Book Your Ride',
                    style: TextStyle(
                      fontSize: 28,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          blurRadius: 10,
                          color: Colors.black,
                          offset: Offset(2, 2),
                        )
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(2, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: fromController,
                                decoration: InputDecoration(
                                  labelText: 'From',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.my_location, color: Colors.green),
                              onPressed: () => _getCurrentLocation(fromController),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        TextField(
                          controller: toController,
                          decoration: InputDecoration(
                            labelText: 'To',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        SizedBox(height: 10),
                        TextField(
                          controller: dateController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Date',
                            border: OutlineInputBorder(),
                          ),
                          onTap: () async {
                            FocusScope.of(context).unfocus();
                            DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              dateController.text =
                                  "${picked.day}/${picked.month}/${picked.year}";
                            }
                          },
                        ),
                        SizedBox(height: 10),
                        TextField(
                          controller: passengerController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'No. of Passengers',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            _saveToFirebase();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AvailableRidesPage(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: EdgeInsets.symmetric(
                                horizontal: 30, vertical: 15),
                            textStyle: TextStyle(fontSize: 16),
                          ),
                          child: Text('Search Rides'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class AvailableRidesPage extends StatelessWidget {
  final List<Map<String, dynamic>> rides = [
    {
      "from": "hyderabad",
      "to": "Bengaluru",
      "startTime": "06:00",
      "endTime": "16:30",
      "driver": "Sai Chandraa",
      "price": 1200,
      "seats": 3
    },
    {
      "from": "hyderabad",
      "to": "vijayawada",
      "startTime": "11:00",
      "endTime": "22:10",
      "driver": "Sateesh",
      "price": 1110,
      "seats": 2
    },
    {
      "from": "hyderabad",
      "to": "guntur",
      "startTime": "12:00",
      "endTime": "22:10",
      "driver": "Sateesh",
      "price": 1200,
      "seats": 1
    },
    {
      "from": "Vijayawada",
      "to": "Bengaluru",
      "startTime": "12:30",
      "endTime": "22:10",
      "driver": "Srikar",
      "price": 1250,
      "seats": 2
    },
  
  ];

  AvailableRidesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Available Rides")),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: ListView(
          children: [
            Text("Tomorrow", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            ...rides.map((ride) => buildRideCard(context, ride)),
          ],
        ),
      ),
    );
  }

  Widget buildRideCard(BuildContext context, Map<String, dynamic> ride) {
    bool isFull = ride['seats'] == 0;
    return GestureDetector(
      onTap: isFull
          ? null
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RideDetailsPage(
                    from: ride['from'],
                    to: ride['to'],
                    driver: ride['driver'],
                    date: "Tomorrow",
                    price: ride['price'].toString(),
                    seats: ride['seats'].toString(),
                  ),
                ),
              );
            },
      child: Card(
        margin: EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ride['startTime'], style: TextStyle(fontSize: 16)),
                      Text(ride['from'], style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    children: [
                      Icon(Icons.more_vert, size: 18),
                      SizedBox(height: 4),
                      Container(width: 2, height: 40, color: Colors.grey.shade400),
                      SizedBox(height: 4),
                      Icon(Icons.more_vert, size: 18),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(ride['endTime'], style: TextStyle(fontSize: 16)),
                      Text(ride['to'], style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.directions_car, size: 20),
                      SizedBox(width: 5),
                      Text(ride['driver'], style: TextStyle(fontSize: 16)),
                    ],
                  ),
                  Text(
                    isFull ? "Full" : "₹${ride['price']}.00",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isFull ? Colors.red : Colors.green.shade800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}



class RideDetailsPage extends StatelessWidget {
  final String from;
  final String to;
  final String driver;
  final String date;
  final String price;
  final String seats;

  const RideDetailsPage({super.key, 
    required this.from,
    required this.to,
    required this.driver,
    required this.date,
    required this.price,
    required this.seats,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(),
        title: Text("Select Your Car Here"),
        backgroundColor: Colors.green,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          buildCarCard(
            context,
            'lib/assets/kia.png',
            'lib/assets/kia int.png',
            'lib/assets/man.png',
            'Karthik',
            '9876543210',
            'AP09CD1234',
            price,
          ),
          buildCarCard(
            context,
            'lib/assets/ert.png',
            'lib/assets/ert int.png',
            'lib/assets/man22.png',
            'Tony',
            '9010993508',
            'KA01AB5678',
            price,
          ),
        ],
      ),
    );
  }

  Widget buildCarCard(
    BuildContext context,
    String externalImg,
    String internalImg,
    String driverImg,
    String driverName,
    String phone,
    String vehicleNumber,
    String price,
  ) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(externalImg, width: 100, height: 80, fit: BoxFit.cover),
                ),
                SizedBox(width: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(internalImg, width: 100, height: 80, fit: BoxFit.cover),
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: AssetImage(driverImg),
                  radius: 25,
                ),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driverName, style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Phone: $phone'),
                    Text('Vehicle No: $vehicleNumber'),
                  ],
                ),
              ],
            ),
            SizedBox(height: 10),
            Text("From: $from", style: TextStyle(fontSize: 16)),
            Text("To: $to", style: TextStyle(fontSize: 16)),
            Text("Date: $date", style: TextStyle(fontSize: 16)),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("₹ $price", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookingConfirmationScreen(
                          rideId: "sample_ride_id",
                          from: from,
                          to: to,
                          date: date,
                          driver: driverName,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text("Book Now"),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}

// ride_history_screen.dart

class RideHistoryScreen extends StatelessWidget {
  const RideHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => SearchPage()),
        );
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text("Your Ride History"),
          backgroundColor: Colors.green,
          leading: BackButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => HomeScreen()),
              );
            },
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('ride_history')
              .orderBy('date', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            final rides = snapshot.data?.docs ?? [];

            if (rides.isEmpty) {
              return Center(child: Text("No ride history available."));
            }

            return ListView.builder(
              itemCount: rides.length,
              itemBuilder: (context, index) {
                final ride = rides[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: Icon(Icons.directions_car, color: Colors.green),
                    title: Text("${ride['from']} ➝ ${ride['to']}"),
                    subtitle: Text("Date: ${ride['date']} | ₹${ride['price']}"),
                    trailing: Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RideDetailView(rideData: ride),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class RideDetailView extends StatelessWidget {
  final QueryDocumentSnapshot rideData;

  const RideDetailView({required this.rideData, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Ride Details"), backgroundColor: Colors.green),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            detailRow("From", rideData['from']),
            detailRow("To", rideData['to']),
            detailRow("Date", rideData['date']),
            detailRow("Time", rideData['time'] ?? "Not specified"),
            detailRow("Driver", rideData['driver']),
            detailRow("Vehicle", rideData['vehicle']),
            detailRow("Price", "₹${rideData['price']}"),
          ],
        ),
      ),
    );
  }

  Widget detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text("$label: ", style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}


// inbox_screen.dart



class InboxScreen extends StatelessWidget {
  final List<Map<String, dynamic>> notifications = [
    {
      "title": "Ride Confirmed!",
      "message": "Your ride from Guntur to Bangalore is confirmed for 21 June.",
      "timestamp": DateTime.now().subtract(Duration(hours: 1)),
    },
    {
      "title": "Special Offer 🎉",
      "message": "Get 20% off on your next ride. Use code ECO20.",
      "timestamp": DateTime.now().subtract(Duration(hours: 2)),
    },
  ];

  InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen()),
        );
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text("Inbox", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black,
          leading: BackButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => HomeScreen()),
              );
            },
          ),
        ),
        body: ListView.separated(
          padding: EdgeInsets.all(16),
          itemCount: notifications.length,
          separatorBuilder: (_, __) => SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = notifications[index];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NotificationDetailScreen(
                      title: item['title'],
                      message: item['message'],
                      timestamp: item['timestamp'],
                    ),
                  ),
                );
              },
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['title'], style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text(item['message'], maxLines: 2, overflow: TextOverflow.ellipsis),
                    SizedBox(height: 8),
                    Text(
                      DateFormat('dd MMM yyyy • hh:mm a').format(item['timestamp']),
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class NotificationDetailScreen extends StatelessWidget {
  final String title;
  final String message;
  final DateTime timestamp;

  const NotificationDetailScreen({
    super.key,
    required this.title,
    required this.message,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final formattedTime = DateFormat('dd MMM yyyy • hh:mm a').format(timestamp);
    return Scaffold(
      appBar: AppBar(
        title: Text("Notification"),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text(formattedTime, style: TextStyle(fontSize: 14, color: Colors.grey)),
            Divider(height: 30),
            Text(message, style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

// booking confirmation_screen.dart


class BookingConfirmationScreen extends StatelessWidget {
  final String rideId;
  final String from;
  final String to;
  final String date;
  final String driver;

  const BookingConfirmationScreen({
    super.key,
    required this.rideId,
    required this.from,
    required this.to,
    required this.date,
    required this.driver,
  });

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Cancel Ride"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Select a reason for cancellation:"),
            ListTile(
              title: Text("Change of plans"),
              onTap: () => _confirmCancel(context),
            ),
            ListTile(
              title: Text("Found another ride"),
              onTap: () => _confirmCancel(context),
            ),
            ListTile(
              title: Text("Other"),
              onTap: () => _confirmCancel(context),
              
            ),
          ],
        ),
      ),
    );
  }

  void _confirmCancel(BuildContext context) {
    Navigator.pop(context); // close dialog
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => AvailableRidesPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Booking Confirmation"),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 80),
            SizedBox(height: 20),
            Text("Your ride has been booked!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text("Details:", style: TextStyle(fontSize: 18)),
            SizedBox(height: 10),
            Text("From: $from", style: TextStyle(fontSize: 16)),
            Text("To: $to", style: TextStyle(fontSize: 16)),
            Text("Date: $date", style: TextStyle(fontSize: 16)),
            Text("Driver: $driver", style: TextStyle(fontSize: 16)),
            Spacer(),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PaymentScreen(
                      rideId: rideId,
                      amount: 500,
                    ),
                  ),
                );
              },
              icon: Icon(Icons.payment),
              label: Text("Pay Now"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
            SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _showCancelDialog(context),
              icon: Icon(Icons.cancel, color: Colors.red),
              label: Text("Cancel Ride", style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                side: BorderSide(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final user = FirebaseAuth.instance.currentUser;
  String name = "Tony😍";
  String about = "Busy";
  String phone = "+91 90109 93508";
  File? _image;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController aboutController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    nameController.text = name;
    aboutController.text = about;
    phoneController.text = phone;
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Profile"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 60,
                backgroundImage:
                    _image != null ? FileImage(_image!) : null,
                child: _image == null ? Icon(Icons.person, size: 60) : null,
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: "Name"),
            ),
            TextField(
              controller: aboutController,
              decoration: InputDecoration(labelText: "About"),
            ),
            TextField(
              controller: phoneController,
              decoration: InputDecoration(labelText: "Phone"),
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.email),
              title: Text("Email"),
              subtitle: Text(user?.email ?? "Not available"),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              icon: Icon(Icons.car_rental),
              label: Text("Publish a Ride"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PublishRideScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class PublishRideScreen extends StatefulWidget {
  const PublishRideScreen({super.key});

  @override
  _PublishRideScreenState createState() => _PublishRideScreenState();
}

class _PublishRideScreenState extends State<PublishRideScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();
  final TextEditingController carModelController = TextEditingController();
  final TextEditingController carNumberController = TextEditingController();
  final TextEditingController seatsController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController timeController = TextEditingController();

  final user = FirebaseAuth.instance.currentUser;

  Future<void> publishRide() async {
  if (_formKey.currentState!.validate()) {
    try {
      final newRide = await FirebaseFirestore.instance.collection('rides').add({
        'driverId': user?.uid,
        'driverEmail': user?.email,
        'from': fromController.text,
        'to': toController.text,
        'carModel': carModelController.text,
        'carNumber': carNumberController.text,
        'seats': int.parse(seatsController.text),
        'price': double.parse(priceController.text),
        'date': dateController.text,
        'time': timeController.text,
        'status': 'pending', // ← optional field to track ride status
        'timestamp': Timestamp.now(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ride published successfully!')),
        );

        await Future.delayed(Duration(milliseconds: 500));

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DriverRideScreen(publishedRideId: newRide.id),
          ),
        );
      }
    } catch (e) {
      print("🔥 Firestore error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to publish ride.")),
      );
    }
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Publish a Ride'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: fromController,
                decoration: InputDecoration(labelText: 'From'),
                validator: (value) => value!.isEmpty ? 'Enter starting point' : null,
              ),
              TextFormField(
                controller: toController,
                decoration: InputDecoration(labelText: 'To'),
                validator: (value) => value!.isEmpty ? 'Enter destination' : null,
              ),
              TextFormField(
                controller: carModelController,
                decoration: InputDecoration(labelText: 'Car Model'),
                validator: (value) => value!.isEmpty ? 'Enter car model' : null,
              ),
              TextFormField(
                controller: carNumberController,
                decoration: InputDecoration(labelText: 'Car Number'),
                validator: (value) => value!.isEmpty ? 'Enter car number' : null,
              ),
              TextFormField(
                controller: seatsController,
                decoration: InputDecoration(labelText: 'Available Seats'),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? 'Enter seat count' : null,
              ),
              TextFormField(
                controller: priceController,
                decoration: InputDecoration(labelText: 'Price per Seat'),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? 'Enter price' : null,
              ),
              TextFormField(
                controller: dateController,
                decoration: InputDecoration(labelText: 'Date (e.g., 25 June 2025)'),
                validator: (value) => value!.isEmpty ? 'Enter date' : null,
              ),
              TextFormField(
                controller: timeController,
                decoration: InputDecoration(labelText: 'Time (e.g., 5:00 PM)'),
                validator: (value) => value!.isEmpty ? 'Enter time' : null,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: publishRide,
                child: Text('Publish Ride'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DriverRideScreen(
          publishedRideId: 'j1ZlvBFM7QNGYw1bIGmS',
        ),
      ),
    );
  },
  backgroundColor: Colors.green,
  tooltip: 'Accept Rides',
  child: Icon(Icons.assignment_turned_in),
)

    );
  }
}

class DriverRideScreen extends StatelessWidget {
  final String? publishedRideId;

  const DriverRideScreen({super.key, this.publishedRideId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Your Ride Request")),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('rides').doc(publishedRideId).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          final data = snapshot.data!.data() as Map<String, dynamic>;

          return Card(
            margin: EdgeInsets.all(20),
            child: ListTile(
              title: Text("From ${data['from']} to ${data['to']}"),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Car: ${data['carModel']} - ${data['carNumber']}"),
                  Text("Seats: ${data['seats']}"),
                  Text("Price: ₹${data['price']}"),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.check, color: Colors.green),
                    onPressed: () {
                      FirebaseFirestore.instance
                          .collection('rides')
                          .doc(publishedRideId)
                          .update({'status': 'accepted'});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Ride Accepted')),
                      
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.red),
                    onPressed: () {
                      FirebaseFirestore.instance
                          .collection('rides')
                          .doc(publishedRideId)
                          .update({'status': 'rejected'});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Ride Rejected')),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
 
// payment_screen.dart
// payments screen 
class PaymentScreen extends StatefulWidget {
  final String rideId;
  final double amount;

  const PaymentScreen({super.key, required this.rideId, required this.amount});

  @override
  _PaymentScreenState createState() => _PaymentScreenState();
}
// Removed duplicate PaymentScreen StatelessWidget class to resolve naming and implementation errors.


class _PaymentScreenState extends State<PaymentScreen> {
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _startPayment() {
    var options = {
      'key': 'rzp_test_yS48Tc5RvKno7J', 
      'amount': (widget.amount * 100).toInt(), 
      'name': 'Eco Ride',
      'description': 'Booking for ride ${widget.rideId}',
      'prefill': {
        'contact': '9876543210',
        'email': FirebaseAuth.instance.currentUser?.email ?? 'test@example.com',
      },
      'timeout': 120, // seconds
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint("Razorpay open error: $e");
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    await FirebaseFirestore.instance.collection('payments').add({
      'userId': uid,
      'rideId': widget.rideId,
      'amount': widget.amount,
      'paymentId': response.paymentId,
      'status': 'success',
      'timestamp': FieldValue.serverTimestamp(),
    });

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("✅ Payment Successful"),
        content: Text("Ride booked successfully!"),
        actions: [
          TextButton(
            onPressed: () {Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => RouteVerificationScreen(
      pickupLocation: LatLng(17.385044, 78.486671), 
      destinationLocation: LatLng(17.5000, 78.5500), 
    ),
  ),
);



            },
            child: Text("OK"),
          )
        ],
      ),
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("❌ Payment Failed"),
        content: Text(
          response.message ?? "Payment failed. Please try again.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK"),
          )
        ],
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("External wallet selected: ${response.walletName}")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Payment"),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SizedBox(height: 20),
            Text("Ride ID: ${widget.rideId}", style: TextStyle(fontSize: 16)),
            SizedBox(height: 10),
            Text(
              "Amount to Pay: ₹${widget.amount}",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Spacer(),
            ElevatedButton(
              onPressed: _startPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text("Pay Now", style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}



class RouteVerificationScreen extends StatefulWidget {
  final LatLng pickupLocation;
  final LatLng destinationLocation;

  const RouteVerificationScreen({
    super.key,
    required this.pickupLocation,
    required this.destinationLocation,
  });

  @override
  _RouteVerificationScreenState createState() => _RouteVerificationScreenState();
}

class _RouteVerificationScreenState extends State<RouteVerificationScreen> {
  GoogleMapController? _mapController;
  loc.LocationData? _currentLocation;
  final loc.Location _location = loc.Location();
  final Set<Polyline> _polylines = {};
  final List<LatLng> _polylineCoordinates = [];
  final PolylinePoints _polylinePoints = PolylinePoints();
  bool _rideCompletedShown = false;
  bool _sosTriggered = false;

  final List<String> emergencyContacts = [
    'tel:9010993508',
    'tel:7675887130',
    'tel:9848099431'
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _getDirections();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
    }

    var permission = await _location.hasPermission();
    if (permission == loc.PermissionStatus.denied) {
      permission = await _location.requestPermission();
    }

    _currentLocation = await _location.getLocation();

    _location.onLocationChanged.listen((newLoc) {
      setState(() {
        _currentLocation = newLoc;
      });

      _checkForDeviation(newLoc);
      _checkForCompletion(newLoc);
    });
  }

  Future<void> _getDirections() async {
    PolylineResult result = await _polylinePoints.getRouteBetweenCoordinates(
      'AIzaSyBYBr1YNKB7MrH31twhPleKdUyaPhdTWCM',
      PointLatLng(widget.pickupLocation.latitude, widget.pickupLocation.longitude),
      PointLatLng(widget.destinationLocation.latitude, widget.destinationLocation.longitude),
    );

    if (result.points.isNotEmpty) {
      _polylineCoordinates.clear();
      for (var point in result.points) {
        _polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      }

      setState(() {
        _polylines.clear();
        _polylines.add(Polyline(
          polylineId: PolylineId("route"),
          color: Colors.blue,
          width: 6,
          points: _polylineCoordinates,
        ));
      });
    }
  }

  void _checkForDeviation(loc.LocationData locData) {
    if (_polylineCoordinates.isEmpty || _sosTriggered) return;

    double minDistance = double.infinity;
    LatLng current = LatLng(locData.latitude!, locData.longitude!);

    for (var point in _polylineCoordinates) {
      double distance = Geolocator.distanceBetween(
        current.latitude,
        current.longitude,
        point.latitude,
        point.longitude,
      );
      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    if (minDistance > 200) {
      _sosTriggered = true;
      _showDeviationDialog();
    }
  }

  void _checkForCompletion(loc.LocationData locData) {
    if (_rideCompletedShown) return;

    double distanceToDestination = Geolocator.distanceBetween(
      locData.latitude!,
      locData.longitude!,
      widget.destinationLocation.latitude,
      widget.destinationLocation.longitude,
    );

    if (distanceToDestination < 100) {
      _rideCompletedShown = true;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text("🎉 Ride Completed"),
          content: Text("You have arrived at your destination."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => RatingScreen(rideId: ''),
            ),
          );
              },
              child: Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  void _showDeviationDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("🚨 Route Deviation"),
        content: Text("You have moved away from the planned route."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _callEmergencyContacts();
            },
            child: Text("Send SOS"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text("Ignore"),
          ),
        ],
      ),
    );
  }

  void _callEmergencyContacts() async {
    for (String contact in emergencyContacts) {
      if (await canLaunchUrl(Uri.parse(contact))) {
        await launchUrl(Uri.parse(contact));
        break; // Only make one call
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("🚨 Calling emergency contact...")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Route Verification")),
      body: _currentLocation == null
          ? Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: widget.pickupLocation,
                zoom: 14,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              polylines: _polylines,
              onMapCreated: (controller) async {
                _mapController = controller;
                await Future.delayed(Duration(milliseconds: 500));

                LatLngBounds bounds = LatLngBounds(
                  southwest: LatLng(
                    widget.pickupLocation.latitude <= widget.destinationLocation.latitude
                        ? widget.pickupLocation.latitude
                        : widget.destinationLocation.latitude,
                    widget.pickupLocation.longitude <= widget.destinationLocation.longitude
                        ? widget.pickupLocation.longitude
                        : widget.destinationLocation.longitude,
                  ),
                  northeast: LatLng(
                    widget.pickupLocation.latitude > widget.destinationLocation.latitude
                        ? widget.pickupLocation.latitude
                        : widget.destinationLocation.latitude,
                    widget.pickupLocation.longitude > widget.destinationLocation.longitude
                        ? widget.pickupLocation.longitude
                        : widget.destinationLocation.longitude,
                  ),
                );

                try {
                  controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
                } catch (e) {
                  print("❌ Camera error: $e");
                }
              },
            ),
    );
  }
}


class RatingScreen extends StatefulWidget {
  final String rideId; // Pass ride document ID to store rating

  const RatingScreen({super.key, required this.rideId});

  @override
  _RatingScreenState createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  double _rating = 3.0;
  final TextEditingController _feedbackController = TextEditingController();

  void _submitRating() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('ride_ratings')
        .add({
          'rideId': widget.rideId,
          'userId': user.uid,
          'userEmail': user.email,
          'rating': _rating,
          'feedback': _feedbackController.text.trim(),
          'timestamp': Timestamp.now(),
        });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('⭐ Thank you for your feedback!')),
    );

    Navigator.pop(context); // Return to previous screen
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Rate Your Ride')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text("How was your ride?", style: TextStyle(fontSize: 18)),
            SizedBox(height: 20),
            RatingBar.builder(
              initialRating: _rating,
              minRating: 1,
              direction: Axis.horizontal,
              itemCount: 5,
              itemBuilder: (context, _) => Icon(Icons.star, color: Colors.amber),
              onRatingUpdate: (rating) => setState(() => _rating = rating),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _feedbackController,
              decoration: InputDecoration(
                labelText: 'Leave a comment (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitRating,
              child: Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
