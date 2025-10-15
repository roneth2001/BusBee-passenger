import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';

class BusBeeTrackingScreen extends StatefulWidget {
  final Map<String, dynamic> busInfo;

  const BusBeeTrackingScreen({
    Key? key,
    required this.busInfo,
  }) : super(key: key);

  @override
  State<BusBeeTrackingScreen> createState() => _BusBeeTrackingScreenState();
}

class _BusBeeTrackingScreenState extends State<BusBeeTrackingScreen> {
  GoogleMapController? _mapController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _realtimeDb = FirebaseDatabase.instance;
  StreamSubscription? _busLocationSubscription;
  StreamSubscription<Position>? _userLocationSubscription;
  Timer? _locationUpdateTimer;
  
  LatLng? _currentBusLocation;
  LatLng? _userLocation;
  double _currentSpeed = 0.0;
  bool _isFavorite = false;
  bool _isOnline = true;
  String _lastUpdateTime = 'Unknown';
  bool _locationPermissionGranted = false;
  
  // Map markers
  Set<Marker> _markers = {};
  BitmapDescriptor? _busIcon;
  BitmapDescriptor? _userIcon;
  
  @override
  void initState() {
    super.initState();
    _createBusIcon();
    _createUserIcon();
    _requestLocationPermission();
    _initializeBusTracking();
    _checkIfFavorite();
    _startLocationUpdateTimer();
  }

  @override
  void dispose() {
    _busLocationSubscription?.cancel();
    _userLocationSubscription?.cancel();
    _locationUpdateTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // Create custom user location icon
  Future<void> _createUserIcon() async {
    try {
      _userIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      setState(() {});
    } catch (e) {
      print('Error creating user icon: $e');
    }
  }

  // Request location permission and start tracking user location
  Future<void> _requestLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permission denied');
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        print('Location permissions are permanently denied');
        return;
      }

      setState(() {
        _locationPermissionGranted = true;
      });
      
      // Start listening to user location updates
      _startUserLocationTracking();
    } catch (e) {
      print('Error requesting location permission: $e');
    }
  }

  // Start tracking user's location in real-time
  void _startUserLocationTracking() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    _userLocationSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _updateMarkers();
      });
    });

    // Get initial location
    Geolocator.getCurrentPosition().then((position) {
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _updateMarkers();
      });
    });
  }

  // Create custom bus icon with proper resizing
  Future<void> _createBusIcon() async {
    try {
      // Load the image asset
      final imageData = await rootBundle.load('assets/icons/bus_icon_on_map.png');
      final bytes = imageData.buffer.asUint8List();
      
      // Decode and resize the image
      final ui.Codec codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 100,
        targetHeight: 100,
      );
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ByteData? resizedData = await frameInfo.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      
      // Create custom icon with bus number text
      final icon = await _createMarkerWithLabel(
        resizedData!.buffer.asUint8List(),
        widget.busInfo['busNumber'],
      );
      
      setState(() {
        _busIcon = icon;
        if (_currentBusLocation != null) {
          _updateMarkers();
        }
      });
    } catch (e) {
      print('Error loading bus icon: $e');
      setState(() {
        _busIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
      });
    }
  }

  Future<BitmapDescriptor> _createMarkerWithLabel(Uint8List iconBytes, String label) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    
    // Decode the bus icon
    final ui.Codec codec = await ui.instantiateImageCodec(iconBytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ui.Image busImage = frameInfo.image;
    
    // Calculate sizes
    final int busWidth = busImage.width;
    final int busHeight = busImage.height;
    final int labelHeight = 40;
    final int totalHeight = labelHeight + busHeight;
    
    // Draw background for label
    final Paint bgPaint = Paint()
      ..color = const Color(0xFFFFC107)
      ..style = PaintingStyle.fill;
    
    final RRect labelBackground = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, busWidth.toDouble(), labelHeight.toDouble()),
      const Radius.circular(8),
    );
    canvas.drawRRect(labelBackground, bgPaint);
    
    // Draw border for label
    final Paint borderPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(labelBackground, borderPaint);
    
    // Draw text
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    
    final double textX = (busWidth - textPainter.width) / 2;
    final double textY = (labelHeight - textPainter.height) / 2;
    textPainter.paint(canvas, Offset(textX, textY));
    
    // Draw the bus icon below the label
    canvas.drawImage(busImage, Offset(0, labelHeight.toDouble()), Paint());
    
    // Convert to image
    final ui.Image markerImage = await pictureRecorder.endRecording().toImage(
      busWidth,
      totalHeight,
    );
    
    final ByteData? byteData = await markerImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  void _initializeBusTracking() {
    // Set initial location from busInfo
    if (widget.busInfo['latitude'] != null && widget.busInfo['longitude'] != null) {
      _currentBusLocation = LatLng(
        widget.busInfo['latitude'],
        widget.busInfo['longitude'],
      );
      _updateMarkers();
    }

    // Listen to real-time location updates from Realtime Database
    final busId = widget.busInfo['id'];
    final DatabaseReference busRef = _realtimeDb.ref('buses/$busId');
    
    _busLocationSubscription = busRef.onValue.listen((DatabaseEvent event) {
      if (event.snapshot.exists) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        
        setState(() {
          if (data['latitude'] != null && data['longitude'] != null) {
            _currentBusLocation = LatLng(
              (data['latitude'] as num).toDouble(),
              (data['longitude'] as num).toDouble(),
            );
            _updateMarkers();
          }
          
          _currentSpeed = (data['speed'] ?? 0).toDouble();
          _isOnline = data['isOnline'] ?? false;
          
          // Format timestamp properly
          if (data['lastLocationUpdate'] != null) {
            try {
              final timestamp = data['lastLocationUpdate'];
              if (timestamp is int) {
                // Realtime Database uses milliseconds since epoch
                final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
                _lastUpdateTime = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
              } else {
                _lastUpdateTime = DateTime.now().toString().substring(11, 19);
              }
            } catch (e) {
              _lastUpdateTime = DateTime.now().toString().substring(11, 19);
            }
          } else {
            _lastUpdateTime = DateTime.now().toString().substring(11, 19);
          }
        });
      }
    });
  }

  // Start timer to update map view every 10 seconds
  void _startLocationUpdateTimer() {
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_currentBusLocation != null && mounted) {
        _animateToLocation(_currentBusLocation!);
        print('Map updated at: ${DateTime.now().toString().substring(11, 19)}');
      }
    });
  }

  void _updateMarkers() {
    if (_currentBusLocation == null) return;

    Set<Marker> markers = {
      Marker(
        markerId: MarkerId(widget.busInfo['id']),
        position: _currentBusLocation!,
        icon: _busIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
        anchor: const Offset(0.5, 0.85),
        rotation: 0,
      ),
    };

    // Add user location marker if available
    if (_userLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: _userLocation!,
          icon: _userIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(
            title: 'Your Location',
          ),
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }

  void _animateToLocation(LatLng location) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(location),
    );
  }

  Future<void> _checkIfFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      setState(() {
        _isFavorite = false;
      });
      return;
    }
    
    final userId = user.uid;
    
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(widget.busInfo['id'])
          .get();
      
      setState(() {
        _isFavorite = doc.exists;
      });
    } catch (e) {
      print('Error checking favorite status: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login to add favorites'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    
    final userId = user.uid;
    
    try {
      final favoriteRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(widget.busInfo['id']);
      
      if (_isFavorite) {
        // Remove from favorites
        await favoriteRef.delete();
        
        setState(() {
          _isFavorite = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Removed from favorites'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Add to favorites
        await favoriteRef.set({
          'busNumber': widget.busInfo['busNumber'],
          'routeName': widget.busInfo['route'],
          'nextStop': widget.busInfo['toStop'],
          'operatorName': widget.busInfo['operatorName'],
          'fromStop': widget.busInfo['fromStop'],
          'busId': widget.busInfo['id'],
          'timestamp': FieldValue.serverTimestamp(),
        });
        
        setState(() {
          _isFavorite = true;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Added to favorites'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error toggling favorite: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_currentBusLocation != null) {
      _animateToLocation(_currentBusLocation!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tracking Bus',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              widget.busInfo['busNumber'],
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isOnline ? Colors.green[100] : Colors.red[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isOnline ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    color: _isOnline ? Colors.green[700] : Colors.red[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                _currentBusLocation != null
                    ? GoogleMap(
                        onMapCreated: _onMapCreated,
                        initialCameraPosition: CameraPosition(
                          target: _currentBusLocation!,
                          zoom: 15,
                        ),
                        markers: _markers,
                        myLocationEnabled: false,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                      )
                    : Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFFFC107),
                          ),
                        ),
                      ),
                Positioned(
                  right: 16,
                  bottom: 80,
                  child: Column(
                    children: [
                      // Center on bus button
                      FloatingActionButton(
                        heroTag: 'centerBus',
                        onPressed: () {
                          if (_currentBusLocation != null) {
                            _animateToLocation(_currentBusLocation!);
                          }
                        },
                        backgroundColor: Colors.white,
                        elevation: 4,
                        child: const Icon(
                          Icons.directions_bus,
                          color: Color(0xFFFFC107),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Center on user location button
                      if (_userLocation != null)
                        FloatingActionButton(
                          heroTag: 'centerUser',
                          onPressed: () {
                            if (_userLocation != null) {
                              _animateToLocation(_userLocation!);
                            }
                          },
                          backgroundColor: Colors.white,
                          elevation: 4,
                          child: const Icon(
                            Icons.my_location,
                            color: Colors.blue,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: Colors.grey[300]),
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Bus Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'Updated: $_lastUpdateTime',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoCard(
                            Icons.directions_bus,
                            'Bus Number',
                            widget.busInfo['busNumber'],
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      Icons.route,
                      'Route Name',
                      widget.busInfo['route'],
                      Colors.purple,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.popUntil(context, (route) => route.isFirst);
                            },
                            icon: const Icon(Icons.search, size: 20),
                            label: const Text(
                              'Route Search',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFC107),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _toggleFavorite,
                            icon: Icon(
                              _isFavorite ? Icons.favorite : Icons.favorite_border,
                              size: 20,
                            ),
                            label: Text(
                              _isFavorite ? 'Favorited' : 'Add Favorite',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isFavorite ? Colors.red : Colors.white,
                              foregroundColor: _isFavorite ? Colors.white : Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: Colors.red,
                                  width: _isFavorite ? 0 : 2,
                                ),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}