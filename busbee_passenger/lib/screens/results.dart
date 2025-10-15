import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';

import 'bustracking.dart';

class BusBeeResultsScreen extends StatefulWidget {
  final String fromLocation;
  final String toLocation;

  const BusBeeResultsScreen({
    Key? key,
    required this.fromLocation,
    required this.toLocation,
    required List<Map<String, dynamic>> buses,
  }) : super(key: key);

  @override
  State<BusBeeResultsScreen> createState() => _BusBeeResultsScreenState();
}

class _BusBeeResultsScreenState extends State<BusBeeResultsScreen> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _buses = [];
  bool _isLoading = true;
  String _sortBy = 'departureTime'; // departureTime, price, duration

  @override
  void initState() {
    super.initState();
    _searchBuses();
  }

  Future<void> _searchBuses() async {
    setState(() => _isLoading = true);

    try {
      // Query all buses from the realtime database
      final DatabaseEvent event = await _databaseRef.child('buses').once();
      final DataSnapshot snapshot = event.snapshot;

      if (!snapshot.exists) {
        setState(() {
          _buses = [];
          _isLoading = false;
        });
        return;
      }

      List<Map<String, dynamic>> matchingBuses = [];
      final Map<Object?, Object?> busesData = snapshot.value as Map<Object?, Object?>;

      busesData.forEach((busId, busDataObj) {
        final Map<String, dynamic> busData = Map<String, dynamic>.from(busDataObj as Map);
        
        // Only include buses that are online
        if (busData['isOnline'] != true) {
          return;
        }

        // Get destinations array
        final List<dynamic> destinations = busData['destinations'] ?? [];
        
        // Check if destinations contain both from and to locations
        int fromIndex = -1;
        int toIndex = -1;

        for (int i = 0; i < destinations.length; i++) {
          final destination = destinations[i].toString().toLowerCase().trim();
          final fromLocation = widget.fromLocation.toLowerCase().trim();
          final toLocation = widget.toLocation.toLowerCase().trim();

          // Check for exact match or partial match
          if (destination.contains(fromLocation) || fromLocation.contains(destination)) {
            fromIndex = i;
          }
          if (destination.contains(toLocation) || toLocation.contains(destination)) {
            toIndex = i;
          }
        }

        // If both stops are found and from comes before to
        if (fromIndex != -1 && toIndex != -1 && fromIndex < toIndex) {
          // Generate mock times based on route position
          final baseHour = 6; // Start at 6 AM
          final departureHour = baseHour + (fromIndex * 1); // 1 hour between stops
          final arrivalHour = baseHour + (toIndex * 1);

          final departureTime = '${departureHour.toString().padLeft(2, '0')}:00';
          final arrivalTime = '${arrivalHour.toString().padLeft(2, '0')}:00';
          final duration = (toIndex - fromIndex) * 60; // 1 hour per stop difference

          // Calculate price based on distance
          final basePrice = 50.0; // Base price per segment
          final distance = toIndex - fromIndex;
          final price = (basePrice * distance).round();

          matchingBuses.add({
            'id': busId.toString(),
            'busNumber': busData['busNumber'] ?? busData['number'] ?? '',
            'operatorName': busData['ownerNumber'] ?? busData['ownerName'] ?? 'Unknown Operator',
            'route': busData['routeName'] ?? 'Unknown Route',
            'departureTime': departureTime,
            'arrivalTime': arrivalTime,
            'duration': duration,
            'price': price,
            'fromStop': destinations[fromIndex].toString(),
            'toStop': destinations[toIndex].toString(),
            'currentLocation': busData['currentLocation'] ?? 'Location not available',
            'latitude': busData['latitude'],
            'longitude': busData['longitude'],
            'lastLocationUpdate': busData['lastLocationUpdate'],
            'isOnline': busData['isOnline'],
          });
        }
      });

      // Sort buses
      _sortBuses(matchingBuses);

      setState(() {
        _buses = matchingBuses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching buses: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper methods to generate bus details
 


  void _sortBuses(List<Map<String, dynamic>> buses) {
    buses.sort((a, b) {
      switch (_sortBy) {
        case 'price':
          return a['price'].compareTo(b['price']);
        case 'duration':
          return a['duration'].compareTo(b['duration']);
        case 'departureTime':
        default:
          return a['departureTime'].compareTo(b['departureTime']);
      }
    });
  }


  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}m';
  }

  Future<void> _launchWebsite() async {
    try {
      final Uri url = Uri.parse('https://gwtechnologiez.com');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: try launching without mode specification
        await launchUrl(url);
      }
    } catch (e) {
      print('Error launching website: $e');
      // Show a snackbar or dialog to inform the user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open website. Please try again later.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 700;
    final isTablet = screenWidth > 600;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    // Responsive dimensions
    final backgroundHeight = isLandscape ? screenHeight * 0.25 : screenHeight * 0.3;
    final horizontalPadding = isTablet ? screenWidth * 0.1 : 16.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SizedBox(
                height: screenHeight - MediaQuery.of(context).padding.top,
                width: screenWidth,
                child: Stack(
                  children: [
                    // Yellow background header
                    Container(
                      height: backgroundHeight,
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color.fromARGB(255, 247, 246, 246), Color.fromARGB(255, 255, 0, 0)],
                        ),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(25),
                          bottomRight: Radius.circular(25),
                        ),
                      ),
                    ),

                    // Back button
                    Positioned(
                      top: isSmallScreen ? 15 : 20,
                      left: 20,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 10,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.arrow_back,
                            color: Colors.black,
                            size: isSmallScreen ? 20 : 24,
                          ),
                        ),
                      ),
                    ),

                    // Header content
                    Positioned(
                      top: isLandscape ? 15 : isSmallScreen ? 60 : 80,
                      left: horizontalPadding,
                      right: horizontalPadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Available Buses',
                            style: TextStyle(
                              fontSize: isTablet ? 28 : isSmallScreen ? 22 : 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 4 : 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 12 : 16,
                              vertical: isSmallScreen ? 6 : 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.trip_origin,
                                  size: isSmallScreen ? 14 : 16,
                                  color: Colors.black54,
                                ),
                                SizedBox(width: isSmallScreen ? 6 : 8),
                                Text(
                                  widget.fromLocation,
                                  style: TextStyle(
                                    fontSize: isTablet ? 16 : isSmallScreen ? 12 : 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: isSmallScreen ? 8 : 12),
                                Icon(
                                  Icons.arrow_forward,
                                  size: isSmallScreen ? 12 : 14,
                                  color: Colors.black54,
                                ),
                                SizedBox(width: isSmallScreen ? 8 : 12),
                                Icon(
                                  Icons.flag_outlined,
                                  size: isSmallScreen ? 14 : 16,
                                  color: Colors.black54,
                                ),
                                SizedBox(width: isSmallScreen ? 6 : 8),
                                Text(
                                  widget.toLocation,
                                  style: TextStyle(
                                    fontSize: isTablet ? 16 : isSmallScreen ? 12 : 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Main content area
                    Positioned(
                      top: backgroundHeight - 20,
                      left: horizontalPadding,
                      right: horizontalPadding,
                      bottom: 0,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(25),
                            topRight: Radius.circular(25),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 20,
                              offset: Offset(0, -5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Results
                            Expanded(
                              child: _isLoading
                                  ? const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFFFFC107),
                                ),
                              )
                                  : _buses.isEmpty
                                  ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.directions_bus_outlined,
                                      size: isTablet ? 80 : 60,
                                      color: Colors.grey[400],
                                    ),
                                    SizedBox(height: isSmallScreen ? 12 : 16),
                                    Text(
                                      'No online buses found',
                                      style: TextStyle(
                                        fontSize: isTablet ? 20 : 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    SizedBox(height: isSmallScreen ? 6 : 8),
                                    Text(
                                      'Try different locations or check back later',
                                      style: TextStyle(
                                        fontSize: isTablet ? 16 : 14,
                                        color: Colors.grey[500],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                                  : ListView.builder(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isSmallScreen ? 12 : 16,
                                  vertical: isSmallScreen ? 6 : 8,
                                ),
                                itemCount: _buses.length,
                                itemBuilder: (context, index) {
                                  final bus = _buses[index];
                                  return _buildBusCard(bus, isSmallScreen, isTablet);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Footer Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Powered by ',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  GestureDetector(
                    onTap: _launchWebsite,
                    child: Text(
                      'GW Technology (PVT) LTD',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue[600],
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildBusCard(Map<String, dynamic> bus, bool isSmallScreen, bool isTablet) {
    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bus number, route name and operator
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bus['busNumber'],
                        style: TextStyle(
                          fontSize: isTablet ? 20 : isSmallScreen ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        bus['route'],
                        style: TextStyle(
                          fontSize: isTablet ? 14 : isSmallScreen ? 12 : 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[700],
                        ),
                      ),
                      
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Online',
                        style: TextStyle(
                          fontSize: isTablet ? 10 : 9,
                          color: Colors.green[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: isSmallScreen ? 12 : 16),

            // Time and duration info
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bus['fromStop'],
                        style: TextStyle(
                          fontSize: isTablet ? 12 : isSmallScreen ? 10 : 11,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        bus['toStop'],
                        style: TextStyle(
                          fontSize: isTablet ? 12 : isSmallScreen ? 10 : 11,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: isSmallScreen ? 12 : 16),

            // Price and booking section
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Rs. 0.00',
                    style: TextStyle(
                      fontSize: isTablet ? 16 : isSmallScreen ? 14 : 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[800],
                    ),
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {
                    //Navigate to Tracking screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BusBeeTrackingScreen(
                          busInfo: bus,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 24 : isSmallScreen ? 16 : 20,
                      vertical: isTablet ? 12 : isSmallScreen ? 8 : 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: Colors.black, width: 1.5),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: isSmallScreen ? 14 : 16,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Track',
                        style: TextStyle(
                          fontSize: isTablet ? 14 : isSmallScreen ? 12 : 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}