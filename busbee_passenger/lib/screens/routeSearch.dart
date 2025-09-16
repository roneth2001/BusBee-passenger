import 'package:busbee_passenger/screens/results.dart';
import 'package:flutter/material.dart';

class BusBeeRouteSearchScreen extends StatefulWidget {
  const BusBeeRouteSearchScreen({Key? key}) : super(key: key);

  @override
  State<BusBeeRouteSearchScreen> createState() => _BusBeeRouteSearchScreenState();
}

class _BusBeeRouteSearchScreenState extends State<BusBeeRouteSearchScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();

  bool _isSearching = false;

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  void _swap() {
    final temp = _fromController.text;
    _fromController.text = _toController.text;
    _toController.text = temp;
  }


  Future<void> _findBuses() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSearching = true);
    try {
      // Small delay to show loading state
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      // Navigate to results screen with the search parameters
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BusBeeResultsScreen(
            fromLocation: _fromController.text.trim(),
            toLocation: _toController.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Stack(
          children: [
            // Yellow header
            Positioned(
              top: 0, left: 0, right: 0,
              height: MediaQuery.of(context).size.height * 0.35,
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

            // Back
            Positioned(
              top: 40, left: 20,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 2))],
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.black, size: 24),
                ),
              ),
            ),

            // Title
            Positioned(
              top: 95, left: 0, right: 0,
              child: Column(
                children: [
                  const Text(
                    'Plan your trip',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Find buses quickly',
                    style: TextStyle(fontSize: 16, color: Colors.black.withOpacity(0.7)),
                  ),
                ],
              ),
            ),

            // Card form
            Positioned(
              top: MediaQuery.of(context).size.height * 0.25,
              left: 20, right: 20, bottom: 20,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))],
                ),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // From
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('From', style: TextStyle(color: Colors.black87.withOpacity(.9), fontSize: 14)),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                          child: TextFormField(
                            controller: _fromController,
                            textInputAction: TextInputAction.next,
                            validator: (v) => _validateStop(v, label: 'your starting stop'),
                            decoration: InputDecoration(
                              hintText: 'e.g., Colombo Fort',
                              prefixIcon: const Icon(Icons.trip_origin, color: Colors.black54),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.my_location, color: Colors.black54),
                                onPressed: () {
                                  // TODO: current location → resolve to nearest stop
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Using current location soon…')),
                                  );
                                },
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Swap
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

                        // To
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('To', style: TextStyle(color: Colors.black87.withOpacity(.9), fontSize: 14)),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                          child: TextFormField(
                            controller: _toController,
                            textInputAction: TextInputAction.done,
                            validator: (v) => _validateStop(v, label: 'your destination stop'),
                            decoration: const InputDecoration(
                              hintText: 'e.g., Kandy',
                              prefixIcon: Icon(Icons.flag_outlined, color: Colors.black54),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Search
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
                              height: 20, width: 20,
                              child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                            )
                                : const Text('See Buses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Mini helper
                        Text(
                          'Tip: you can swap stops with the button above.',
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
    );
  }
}
