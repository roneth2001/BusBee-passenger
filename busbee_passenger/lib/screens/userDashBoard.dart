import 'package:busbee_passenger/screens/routeSearch.dart';
import 'package:busbee_passenger/screens/welcomePage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

// If you use an AuthGate as home, you can just signOut() and not navigate.
// If you want to navigate explicitly after logout, import your login screen:
// <-- change to your actual path/file if needed

class BusBeeMenuScreen extends StatelessWidget {
  const BusBeeMenuScreen({Key? key}) : super(key: key);

  /// Reads the current user's Firestore doc and returns a stream of their full name.
  Stream<String?> _userNameStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream<String?>.empty();

    return FirebaseFirestore.instance
        .collection('passengers')
        .doc(uid)
        .snapshots()
        .map((snap) {
      final data = snap.data();
      if (data == null) return null;
      final name = (data['fullName'] as String?)?.trim();
      return (name != null && name.isNotEmpty) ? name : null;
    });
  }

  /// Best-effort greeting name: Firestore fullName → displayName → phone/email → "there"
  Widget _greeting() {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<String?>(
      stream: _userNameStream(),
      builder: (context, snapshot) {
        String fallback = 'there';

        // Try displayName
        final dn = user?.displayName?.trim();
        if (dn != null && dn.isNotEmpty) fallback = dn;

        // Try phone
        final phone = user?.phoneNumber?.trim();
        if (phone != null && phone.isNotEmpty) fallback = phone;

        // Try email
        final email = user?.email?.trim();
        if (email != null && email.isNotEmpty) fallback = email;

        // Prefer Firestore name if available
        final nameFromFirestore = snapshot.data;
        final greetingName = (nameFromFirestore != null && nameFromFirestore.isNotEmpty)
            ? nameFromFirestore
            : fallback;

        // Only first name
        final first = greetingName.split(' ').first;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text(
            'Hi ...',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          );
        }

        return Text(
          'Hi $first!',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        );
      },
    );
  }


  Future<void> _launchWebsite() async {
    try {
      final Uri url = Uri.parse('https://gwtechnologiez.com');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url);
      }
    } catch (_) {
      // You can show a snackbar via a passed BuildContext if needed
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFC107),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              // (You can put an illustration here)

              // 👇 Dynamic greeting from Firestore/Auth
              _greeting(),

              // Underline
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 40),
                height: 2,
                width: 100,
                color: Colors.black87,
              ),

              // Menu container
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Menu',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 1,
                      width: double.infinity,
                      color: Colors.black87,
                      margin: const EdgeInsets.only(bottom: 25),
                    ),

                    _buildMenuItem(
                      icon: Icons.directions_bus,
                      text: 'See Your Bus',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const BusBeeRouteSearchScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    _buildMenuItem(
                      icon: Icons.notifications,
                      text: 'Notifications',
                      showBadge: true,
                      onTap: () {
                        // TODO: Navigate to notifications screen
                      },
                    ),
                    const SizedBox(height: 20),

                    _buildMenuItem(
                      icon: Icons.settings,
                      text: 'Settings',
                      onTap: () {
                        // TODO: Navigate to settings screen
                      },
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Logout button
              Center(
                child: SizedBox(
                  width: 200,
                  child: ElevatedButton(
                    onPressed: () async {
                      // 1. Sign out
                      await FirebaseAuth.instance.signOut();

                      // 2. Navigate to WelcomePage and clear history
                      if (!context.mounted) return;
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const BusBeeWelcomeScreen()),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      elevation: 5,
                    ),
                    child: const Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // BusBee logo
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC107),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.directions_bus,
                          color: Colors.black,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'BusBee',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
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

      // 🔻 Footer pinned to bottom of the screen
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

  Widget _buildMenuItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    bool showBadge = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Stack(
              children: [
                Icon(icon, size: 30, color: Colors.black87),
                if (showBadge)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          '1',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
