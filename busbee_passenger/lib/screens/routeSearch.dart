import 'package:busbee_passenger/screens/results.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';

class BusBeeRouteSearchScreen extends StatefulWidget {
  const BusBeeRouteSearchScreen({Key? key}) : super(key: key);

  @override
  State<BusBeeRouteSearchScreen> createState() => _BusBeeRouteSearchScreenState();
}

class _BusBeeRouteSearchScreenState extends State<BusBeeRouteSearchScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  // Focus nodes to track which field is focused
  final FocusNode _fromFocusNode = FocusNode();
  final FocusNode _toFocusNode = FocusNode();

  bool _isSearching = false;
  List<String> _availableStops = [];
  bool _isLoadingStops = false;

  // Track which field should show suggestions
  bool _showFromSuggestions = false;
  bool _showToSuggestions = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableStops();
    _setupFocusListeners();
  }

  void _setupFocusListeners() {
    _fromFocusNode.addListener(() {
      if (!_fromFocusNode.hasFocus) {
        setState(() => _showFromSuggestions = false);
      }
    });
    _toFocusNode.addListener(() {
      if (!_toFocusNode.hasFocus) {
        setState(() => _showToSuggestions = false);
      }
    });
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _fromFocusNode.dispose();
    _toFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableStops() async {
    setState(() => _isLoadingStops = true);
    try {
      final DatabaseEvent event = await _databaseRef.child('buses').once();
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        final Set<String> stops = {};
        data.forEach((busId, busData) {
          if (busData is Map) {
            final routeName = busData['routeName']?.toString();
            if (routeName != null) {
              final routeParts = routeName.split(RegExp(r'[-–—\s]+'));
              for (final part in routeParts) {
                final cleanPart = part.trim();
                if (cleanPart.isNotEmpty && cleanPart.length > 1) {
                  stops.add(cleanPart);
                }
              }
            }
            final destinations = busData['destinations'];
            if (destinations is List) {
              for (final dest in destinations) {
                if (dest is String && dest.trim().isNotEmpty) {
                  stops.add(dest.trim());
                }
              }
            }
          }
        });
        setState(() => _availableStops = stops.toList()..sort());
      }
    } catch (e) {
      debugPrint('Error loading stops: $e');
    } finally {
      if (mounted) setState(() => _isLoadingStops = false);
    }
  }

  List<String> _getFilteredStops(String query) {
    if (query.isEmpty) return [];
    return _availableStops
        .where((stop) => stop.toLowerCase().contains(query.toLowerCase()))
        .take(5)
        .toList();
  }

  void _swap() {
    final temp = _fromController.text;
    _fromController.text = _toController.text;
    _toController.text = temp;
    setState(() {
      _showFromSuggestions = false;
      _showToSuggestions = false;
    });
  }

  Future<List<Map<String, dynamic>>> _searchBuses(String from, String to) async {
    try {
      final DatabaseEvent event = await _databaseRef.child('buses').once();
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      final List<Map<String, dynamic>> matchingBuses = [];
      if (data != null) {
        data.forEach((busId, busData) {
          if (busData is Map) {
            final routeName = busData['routeName']?.toString() ?? '';
            final isOnline = busData['isOnline'] ?? false;

            final routeLower = routeName.toLowerCase();
            if (routeLower.contains(from.toLowerCase()) &&
                routeLower.contains(to.toLowerCase())) {
              matchingBuses.add({
                'busId': '$busId',
                'busNumber': busData['busNumber']?.toString() ?? 'Unknown',
                'routeName': routeName,
                'ownerNumber': busData['ownerNumber']?.toString() ?? 'Unknown',
                'isOnline': isOnline,
                'currentLocation': {
                  'latitude': (busData['latitude'] ?? 0.0).toDouble(),
                  'longitude': (busData['longitude'] ?? 0.0).toDouble(),
                },
                'lastUpdated': busData['lastUpdated']?.toString() ?? '',
                'tourEndTime': busData['tourEndTime']?.toString() ?? '',
              });
            }
          }
        });
      }
      return matchingBuses;
    } catch (e) {
      debugPrint('Error searching buses: $e');
      return [];
    }
  }

  Future<void> _findBuses() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _showFromSuggestions = false;
      _showToSuggestions = false;
      _isSearching = true;
    });
    FocusScope.of(context).unfocus();

    try {
      final from = _fromController.text.trim();
      final to = _toController.text.trim();
      final buses = await _searchBuses(from, to);
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BusBeeResultsScreen(
            fromLocation: from,
            toLocation: to,
            buses: buses,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  String? _validateStop(String? v, {required String label}) {
    if (v == null || v.trim().isEmpty) return 'Please enter $label';
    if (v.trim().length < 2) return '$label must be at least 2 characters';
    if (_fromController.text.trim().isNotEmpty &&
        _toController.text.trim().isNotEmpty &&
        _fromController.text.trim().toLowerCase() ==
            _toController.text.trim().toLowerCase()) {
      return 'From and To cannot be the same';
    }
    return null;
  }

  void _selectSuggestion(String suggestion, bool isFromField) {
    if (isFromField) {
      _fromController.text = suggestion;
      setState(() => _showFromSuggestions = false);
      _toFocusNode.requestFocus();
    } else {
      _toController.text = suggestion;
      setState(() => _showToSuggestions = false);
      FocusScope.of(context).unfocus();
    }
  }

  Widget _buildAutocompleteField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData prefixIcon,
    required String label,
    required bool showSuggestions,
    required bool isFromField,
    Widget? suffixIcon,
    TextInputAction? textInputAction,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.black87.withOpacity(.9), fontSize: 14)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: Column(
            children: [
              TextFormField(
                controller: controller,
                focusNode: focusNode,
                textInputAction: textInputAction,
                validator: (v) => _validateStop(v, label: label),
                onTap: () {
                  if (controller.text.isNotEmpty) {
                    setState(() {
                      if (isFromField) {
                        _showFromSuggestions = true;
                        _showToSuggestions = false;
                      } else {
                        _showToSuggestions = true;
                        _showFromSuggestions = false;
                      }
                    });
                  }
                },
                onChanged: (value) {
                  setState(() {
                    if (isFromField) {
                      _showFromSuggestions = value.isNotEmpty;
                      _showToSuggestions = false;
                    } else {
                      _showToSuggestions = value.isNotEmpty;
                      _showFromSuggestions = false;
                    }
                  });
                },
                onFieldSubmitted: (value) {
                  setState(() {
                    if (isFromField) {
                      _showFromSuggestions = false;
                      _toFocusNode.requestFocus();
                    } else {
                      _showToSuggestions = false;
                      FocusScope.of(context).unfocus();
                    }
                  });
                },
                decoration: InputDecoration(
                  hintText: hint,
                  prefixIcon: Icon(prefixIcon, color: Colors.black54),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (controller.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, color: Colors.black54, size: 20),
                          onPressed: () {
                            controller.clear();
                            setState(() {
                              if (isFromField) {
                                _showFromSuggestions = false;
                              } else {
                                _showToSuggestions = false;
                              }
                            });
                          },
                        ),
                      if (suffixIcon != null) suffixIcon,
                    ],
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
              ),
              if (showSuggestions && controller.text.isNotEmpty) ...[
                Container(height: 1, color: Colors.grey.withOpacity(0.3)),
                Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _getFilteredStops(controller.text).length,
                    itemBuilder: (context, index) {
                      final stop = _getFilteredStops(controller.text)[index];
                      return ListTile(
                        dense: true,
                        title: Text(stop, style: const TextStyle(fontSize: 14)),
                        trailing: const Icon(Icons.north_west, size: 16, color: Colors.grey),
                        onTap: () => _selectSuggestion(stop, isFromField),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // 🔗 Footer link
  Future<void> _launchWebsite() async {
    try {
      final Uri url = Uri.parse('https://gwtechnologiez.com');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open website. Please try again later.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          setState(() {
            _showFromSuggestions = false;
            _showToSuggestions = false;
          });
        },
        child: SafeArea(
          child: Stack(
            children: [
              // Yellow header
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: height * 0.35,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFFD54F), Color(0xFFFFC107)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                ),
              ),

              // Back button
              Positioned(
                top: 40,
                left: 20,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 2))
                      ],
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.black, size: 24),
                  ),
                ),
              ),

              // Refresh button for stops
              Positioned(
                top: 40,
                right: 20,
                child: GestureDetector(
                  onTap: _isLoadingStops ? null : _loadAvailableStops,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 2))
                      ],
                    ),
                    child: _isLoadingStops
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54),
                          )
                        : const Icon(Icons.refresh, color: Colors.black, size: 24),
                  ),
                ),
              ),

              // Title
              const Positioned(
                top: 95,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    Text(
                      'Plan your trip',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    SizedBox(height: 8),
                    // (Stop count is shown inside the form title below)
                  ],
                ),
              ),

              // Card form
              Positioned(
                top: height * 0.25,
                left: 20,
                right: 20,
                bottom: 90, // leave room for footer
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // Small subtitle with stops count

                          _buildAutocompleteField(
                            controller: _fromController,
                            focusNode: _fromFocusNode,
                            hint: 'e.g., Colombo Fort',
                            prefixIcon: Icons.trip_origin,
                            label: 'your starting stop',
                            showSuggestions: _showFromSuggestions,
                            isFromField: true,
                            textInputAction: TextInputAction.next,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.my_location, color: Colors.black54),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Using current location soon…')),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Swap button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(30),
                                onTap: _swap,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFC107),
                                    border: Border.all(color: Colors.black, width: 2),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: const Icon(Icons.swap_vert, color: Colors.black),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          _buildAutocompleteField(
                            controller: _toController,
                            focusNode: _toFocusNode,
                            hint: 'e.g., Kandy',
                            prefixIcon: Icons.flag_outlined,
                            label: 'your destination stop',
                            showSuggestions: _showToSuggestions,
                            isFromField: false,
                            textInputAction: TextInputAction.done,
                          ),

                          const SizedBox(height: 28),

                          // Search button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isSearching ? null : _findBuses,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFC107),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                  side: const BorderSide(color: Colors.black, width: 2),
                                ),
                                elevation: 0,
                              ),
                              child: _isSearching
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                                    )
                                  : const Text('See Buses',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ),
                          ),

                          const SizedBox(height: 12),

                          Text(
                            'Tip: Tap a suggestion to select it, or tap outside to close.',
                            style: TextStyle(color: Colors.black.withOpacity(.6)),
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
      ),

      // 🔻 Footer pinned at bottom
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
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
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w400,
                ),
              ),
              GestureDetector(
                onTap: _launchWebsite,
                child: Text(
                  'GW Technology',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue[600],
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
