import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'bustracking.dart';

class BusBeeResultsScreen extends StatefulWidget {
  final String fromLocation;
  final String toLocation;

  const BusBeeResultsScreen({
    Key? key,
    required this.fromLocation,
    required this.toLocation,
  }) : super(key: key);

  @override
  State<BusBeeResultsScreen> createState() => _BusBeeResultsScreenState();
}

class _BusBeeResultsScreenState extends State<BusBeeResultsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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
      // Query all buses from the collection
      final busQuery = await _firestore.collection('buses').get();

      List<Map<String, dynamic>> matchingBuses = [];

      for (var busDoc in busQuery.docs) {
        final busData = busDoc.data();
        final List<dynamic> route = busData['route'] ?? [];

        // Check if route contains both from and to locations
        int fromIndex = -1;
        int toIndex = -1;

        for (int i = 0; i < route.length; i++) {
          final stopLocation = route[i].toString().toLowerCase();

          if (stopLocation.contains(widget.fromLocation.toLowerCase()) ||
              widget.fromLocation.toLowerCase().contains(stopLocation)) {
            fromIndex = i;
          }
          if (stopLocation.contains(widget.toLocation.toLowerCase()) ||
              widget.toLocation.toLowerCase().contains(stopLocation)) {
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
            'id': busDoc.id,
            'busNumber': busData['number'] ?? '',
            'operatorName': busData['ownerName'] ?? 'Unknown Operator',
            'route': busData['routeName'] ?? '',
            'departureTime': departureTime,
            'arrivalTime': arrivalTime,
            'duration': duration,
            'fromStop': route[fromIndex].toString(),
            'toStop': route[toIndex].toString(),
          });
        }
      }

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
  String _getBusTypeFromRoute(String routeName) {
    if (routeName.toLowerCase().contains('express')) return 'Express';
    if (routeName.toLowerCase().contains('luxury')) return 'Luxury';
    if (routeName.toLowerCase().contains('ac')) return 'AC';
    return 'Regular';
  }

  int _generateAvailableSeats() {
    final random = DateTime.now().millisecondsSinceEpoch % 45;
    return 10 + random; // Between 10-54 seats
  }

  List<String> _generateAmenities() {
    final allAmenities = ['AC', 'WiFi', 'Charging Port', 'TV', 'Reclining Seats', 'Water'];
    final count = (DateTime.now().millisecondsSinceEpoch % 4) + 1; // 1-4 amenities
    return allAmenities.take(count).toList();
  }

  double _generateRating() {
    final rating = 3.5 + ((DateTime.now().millisecondsSinceEpoch % 15) / 10);
    return double.parse(rating.toStringAsFixed(1));
  }

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

  void _changeSorting(String newSortBy) {
    setState(() {
      _sortBy = newSortBy;
      _sortBuses(_buses);
    });
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}m';
  }

  Color _getBusTypeColor(String busType) {
    switch (busType.toLowerCase()) {
      case 'luxury':
        return Colors.purple;
      case 'semi-luxury':
        return Colors.blue;
      case 'ac':
        return Colors.green;
      default:
        return Colors.grey;
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
                    colors: [Color(0xFFFFD54F), Color(0xFFFFC107)],
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
                                'No buses found',
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
    );
  }

  Widget _buildSortChip(String value, String label, bool isSmallScreen, bool isTablet) {
    final isSelected = _sortBy == value;
    return GestureDetector(
      onTap: () => _changeSorting(value),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 12 : 16,
          vertical: isSmallScreen ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFC107) : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: isTablet ? 14 : isSmallScreen ? 12 : 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.black : Colors.grey[700],
          ),
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
                fontSize: isTablet ? 20 : isSmallScreen ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              bus['operatorName'],
              style: TextStyle(
                fontSize: isTablet ? 14 : isSmallScreen ? 12 : 13,
                color: Colors.grey[600],
              ),
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
                        bus['departureTime'],
                        style: TextStyle(
                          fontSize: isTablet ? 18 : isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
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
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 8 : 10,
                          vertical: isSmallScreen ? 2 : 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _formatDuration(bus['duration']),
                          style: TextStyle(
                            fontSize: isTablet ? 12 : isSmallScreen ? 10 : 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 2 : 4),
                      Container(
                        height: 1,
                        width: isSmallScreen ? 60 : 80,
                        color: Colors.grey[300],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        bus['arrivalTime'],
                        style: TextStyle(
                          fontSize: isTablet ? 18 : isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Show location of ${bus['busNumber']}...'),
                        backgroundColor: const Color(0xFFFFC107),
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
                  child: Text(
                    'Navigate',
                    style: TextStyle(
                      fontSize: isTablet ? 14 : isSmallScreen ? 12 : 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            // Amenities (if available)

          ],
        ),
      ),
    );
  }
}