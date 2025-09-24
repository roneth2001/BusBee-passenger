import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

class BusBeeTrackingScreen extends StatefulWidget {
  final Map<String, dynamic> busInfo; // must include 'id' (bus doc id)

  const BusBeeTrackingScreen({
    Key? key,
    required this.busInfo,
  }) : super(key: key);

  @override
  State<BusBeeTrackingScreen> createState() => _BusBeeTrackingScreenState();
}

class _BusBeeTrackingScreenState extends State<BusBeeTrackingScreen> {
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  GoogleMapController? _mapController;
  StreamSubscription<DatabaseEvent>? _busSub;
  Timer? _refreshTimer;

  // Live values
  LatLng? _busLocation;           // null until first snapshot
  double _busSpeed = 0.0;         // km/h
  String _busStatus = 'On Route'; // "On Route" | "At Stop" | "Delayed" (optional)
  int? _nextStopEtaMin;           // minutes to next stop (optional)
  int? _availableSeats;           // seats left (optional)
  String? _driverPhone;           // for call driver (optional)
  String? _nextStopName;          // show stop name if you have it (optional)
  bool _isOnline = false;         // bus online status

  Set<Marker> _markers = <Marker>{};

  @override
  void initState() {
    super.initState();
    _listenToBusDoc();
    _startPeriodicRefresh();
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _refreshBusData();
      }
    });
  }

  void _refreshBusData() {
    final busId = (widget.busInfo['id'] ?? '').toString();
    if (busId.isEmpty) return;

    // Force a one-time read to refresh data
    _database.ref('buses/$busId').once().then((DatabaseEvent event) {
      if (event.snapshot.exists) {
        _processBusData(event.snapshot);
      }
    }).catchError((error) {
      debugPrint('[BusBee] Refresh error: $error');
    });
  }

  void _listenToBusDoc() {
    final busId = (widget.busInfo['id'] ?? '').toString();
    if (busId.isEmpty) {
      debugPrint('[BusBee] busInfo["id"] missing');
      return;
    }

    _busSub = _database.ref('buses/$busId').onValue.listen((DatabaseEvent event) {
      if (!event.snapshot.exists) {
        debugPrint('[BusBee] buses/$busId not found');
        return;
      }
      
      _processBusData(event.snapshot);
    }, onError: (error) {
      debugPrint('[BusBee] Realtime Database error: $error');
    });
  }

  void _processBusData(DataSnapshot snapshot) {
    final data = snapshot.value as Map<dynamic, dynamic>?;
    if (data == null) return;

    // Extract location from your database structure
    final latitude = data['latitude'] as num?;
    final longitude = data['longitude'] as num?;
    
    if (latitude == null || longitude == null) {
      debugPrint('[BusBee] latitude or longitude missing');
      return;
    }

    // Read other optional fields if present
    _busSpeed = (data['speedKmh'] as num?)?.toDouble() ?? _busSpeed;
    _busStatus = (data['status'] as String?) ?? _busStatus;
    _nextStopEtaMin = (data['nextStopEtaMin'] as num?)?.toInt() ?? _nextStopEtaMin;
    _availableSeats = (data['availableSeats'] as num?)?.toInt() ?? _availableSeats;
    _driverPhone = (data['driverPhone'] as String?) ?? _driverPhone;
    _nextStopName = (data['nextStopName'] as String?) ?? _nextStopName;
    _isOnline = (data['isOnline'] as bool?) ?? true;

    // Get route name from your data structure
    final routeName = data['routeName'] as String?;
    if (routeName != null && widget.busInfo['routeName'] == null) {
      widget.busInfo['routeName'] = routeName;
    }

    // Get owner/operator name
    final ownerNumber = data['ownerNumber'] as String?;
    if (ownerNumber != null && widget.busInfo['operatorName'] == null) {
      widget.busInfo['operatorName'] = ownerNumber;
    }

    final newPos = LatLng(latitude.toDouble(), longitude.toDouble());

    if (!mounted) return;
    setState(() {
      _busLocation = newPos;
      _markers = {
        Marker(
          markerId: const MarkerId('bus'),
          position: newPos,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _isOnline ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueRed
          ),
          infoWindow: InfoWindow(
            title: widget.busInfo['busNumber'] ?? data['busNumber'] ?? 'Bus',
            snippet: _busSpeed > 0 
                ? 'Speed: ${_busSpeed.toStringAsFixed(0)} km/h ${_isOnline ? "• Online" : "• Offline"}'
                : (_isOnline ? 'Online' : 'Offline'),
          ),
        ),
      };
    });

    // keep camera on the bus (only if it's a significant location change)
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(newPos, 15),
      );
    }
  }

  @override
  void dispose() {
    _busSub?.cancel();
    _refreshTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Color _statusColor() {
    if (!_isOnline) return Colors.red;
    
    switch (_busStatus) {
      case 'On Route':
        return Colors.green;
      case 'At Stop':
        return Colors.blue;
      case 'Delayed':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText() {
    if (!_isOnline) return 'Offline';
    return _busStatus;
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    // center instantly on first build if we already have a location
    final target = _busLocation ?? const LatLng(7.8731, 80.7718); // Sri Lanka default
    controller.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: _busLocation == null ? 6 : 14),
      ),
    );
  }

  Future<void> _callDriver() async {
    final phone = _driverPhone ?? widget.busInfo['driverPhone'];
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver phone number not available')),
      );
      return;
    }
    final uri = Uri.parse('tel:$phone');
    try {
      final can = await canLaunchUrl(uri);
      if (can) {
        await launchUrl(uri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Can t start a call to $phone")),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to call $phone')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // Header with status pill
            Container(
              padding: EdgeInsets.all(isSmall ? 12 : 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: EdgeInsets.all(isSmall ? 6 : 8),
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.arrow_back, size: isSmall ? 20 : 24, color: Colors.black87),
                    ),
                  ),
                  SizedBox(width: isSmall ? 12 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.busInfo['busNumber'] ?? 'Bus Tracking',
                          style: TextStyle(
                            fontSize: isTablet ? 20 : isSmall ? 16 : 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          widget.busInfo['operatorName'] ?? widget.busInfo['routeName'] ?? 'Live Location',
                          style: TextStyle(
                            fontSize: isTablet ? 14 : isSmall ? 12 : 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: isSmall ? 8 : 12, vertical: isSmall ? 4 : 6),
                    decoration: BoxDecoration(
                      color: _statusColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _statusColor(), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: isSmall ? 6 : 8, height: isSmall ? 6 : 8, decoration: BoxDecoration(color: _statusColor(), shape: BoxShape.circle)),
                        SizedBox(width: isSmall ? 4 : 6),
                        Text(
                          _getStatusText(),
                          style: TextStyle(
                            fontSize: isTablet ? 12 : isSmall ? 10 : 11,
                            fontWeight: FontWeight.w600,
                            color: _statusColor(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Map (or loader until we have first location)
            Expanded(
              child: Container(
                margin: EdgeInsets.all(isSmall ? 8 : 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _busLocation == null
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Loading bus location...'),
                            ],
                          ),
                        )
                      : GoogleMap(
                    onMapCreated: _onMapCreated,
                    initialCameraPosition: CameraPosition(target: _busLocation!, zoom: 14),
                    markers: _markers,
                    polylines: const {}, // no routes
                    mapType: MapType.normal,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: true,
                    compassEnabled: true,
                    trafficEnabled: true,
                    buildingsEnabled: true,
                    mapToolbarEnabled: false,
                  ),
                ),
              ),
            ),

            // Info cards + actions
            Container(
              margin: EdgeInsets.all(isSmall ? 8 : 12),
              padding: EdgeInsets.all(isSmall ? 16 : 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _infoCard(
                        icon: Icons.speed,
                        title: 'Speed',
                        value: _busSpeed > 0 ? '${_busSpeed.toStringAsFixed(0)} km/h' : '—',
                        color: Colors.blue,
                        isSmall: isSmall,
                        isTablet: isTablet,
                      ),
                      SizedBox(width: isSmall ? 8 : 12),
                      _infoCard(
                        icon: Icons.access_time,
                        title: _nextStopName == null ? 'Next Stop' : _nextStopName!,
                        value: _nextStopEtaMin == null ? '—' : '${_nextStopEtaMin} min',
                        color: Colors.orange,
                        isSmall: isSmall,
                        isTablet: isTablet,
                      ),
                      SizedBox(width: isSmall ? 8 : 12),
                      _infoCard(
                        icon: Icons.people,
                        title: 'Seats',
                        value: _availableSeats == null ? '—' : '${_availableSeats} left',
                        color: Colors.green,
                        isSmall: isSmall,
                        isTablet: isTablet,
                      ),
                    ],
                  ),

                  SizedBox(height: isSmall ? 16 : 20),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _callDriver,
                          icon: Icon(Icons.phone, size: isSmall ? 16 : 18),
                          label: Text(
                            'Call Driver',
                            style: TextStyle(fontSize: isTablet ? 14 : isSmall ? 12 : 13, fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                            padding: EdgeInsets.symmetric(vertical: isSmall ? 12 : 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                              side: BorderSide(color: Colors.grey[300]!, width: 1),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      SizedBox(width: isSmall ? 8 : 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _busLocation == null
                              ? null
                              : () => _mapController?.animateCamera(
                            CameraUpdate.newLatLngZoom(_busLocation!, 16),
                          ),
                          icon: Icon(Icons.my_location, size: isSmall ? 16 : 18),
                          label: Text(
                            'Center Bus',
                            style: TextStyle(fontSize: isTablet ? 14 : isSmall ? 12 : 13, fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFC107),
                            foregroundColor: Colors.black,
                            padding: EdgeInsets.symmetric(vertical: isSmall ? 12 : 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                              side: const BorderSide(color: Colors.black, width: 1),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required bool isSmall,
    required bool isTablet,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(isSmall ? 12 : 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: isSmall ? 20 : 24),
            SizedBox(height: isSmall ? 4 : 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isTablet ? 12 : isSmall ? 10 : 11,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: isSmall ? 2 : 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isTablet ? 16 : isSmall ? 14 : 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}