import 'package:busbee_passenger/screens/signUp.dart';
import 'package:busbee_passenger/screens/userDashBoard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class BusBeeLoginScreen extends StatefulWidget {
  const BusBeeLoginScreen({Key? key}) : super(key: key);

  @override
  State<BusBeeLoginScreen> createState() => _BusBeeLoginScreenState();
}

class _BusBeeLoginScreenState extends State<BusBeeLoginScreen> {
  final TextEditingController _usernameController = TextEditingController(); // phone number
  final TextEditingController _passwordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Normalize SL phone input -> '0XXXXXXXXX' or null if invalid
  String? _canonicalizeSriLankaPhone(String input) {
    final digits = input.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return null;

    // +94 / 94XXXXXXXXX -> 0XXXXXXXXX
    if (digits.startsWith('94') && digits.length >= 11) {
      final rest = digits.substring(2); // 9 digits
      if (rest.length == 9) return '0$rest';
    }

    // 9 digits starting 7 or 1 (no leading 0) -> add 0
    if (digits.length == 9 && (digits.startsWith('7') || digits.startsWith('1'))) {
      return '0$digits';
    }

    // Already 10 digits starting with 0
    if (digits.length == 10 && digits.startsWith('0')) {
      return digits;
    }

    return null;
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    final canonicalPhone = _canonicalizeSriLankaPhone(_usernameController.text.trim());
    if (canonicalPhone == null) {
      _showError('Please enter a valid phone number (e.g., 0771234567).');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1) Sign in using phone-as-email (no Firestore read before auth)
      final email = '$canonicalPhone@busbee.com';
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: _passwordController.text.trim(),
      );

      // 2) Post-login: update lastLoginDate (optional)
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        FirebaseFirestore.instance
            .collection('passengers')
            .doc(uid)
            .update({'lastLoginDate': FieldValue.serverTimestamp()})
            .catchError((_) {}); // ignore if it fails
      }

      if (!mounted) return;
      // 3) Navigate to dashboard
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const BusBeeMenuScreen()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          _showError('No account found for this phone number.');
          break;
        case 'wrong-password':
          _showError('Incorrect phone number or password.');
          break;
        case 'invalid-credential':
          _showError('Invalid credentials. Please try again.');
          break;
        case 'too-many-requests':
          _showError('Too many attempts. Please try again later.');
          break;
        case 'network-request-failed':
          _showError('Network error. Check your connection.');
          break;
        default:
          _showError(e.message ?? 'Login failed. Please try again.');
      }
    } catch (_) {
      _showError('Unexpected error. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _launchWebsite() async {
    try {
      final Uri url = Uri.parse('https://gwtechnologiez.com');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url);
      }
    } catch (e) {
      // Show a snackbar to inform the user
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

  String? _validatePhoneField(String? v) {
    final c = _canonicalizeSriLankaPhone(v?.trim() ?? '');
    return c == null ? 'Enter a valid phone number (e.g., 0771234567)' : null;
  }

  String? _validatePasswordField(String? v) {
    if (v == null || v.isEmpty) return 'Enter your password';
    if (v.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 700;
    final isTablet = screenWidth > 600;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    // Responsive dimensions
    final backgroundHeight = isLandscape ? screenHeight * 0.4 : screenHeight * 0.55;
    final cardHeight = isLandscape
        ? screenHeight * 0.85
        : isSmallScreen
            ? screenHeight * 0.75
            : screenHeight * 0.6;
    final horizontalPadding = isTablet ? screenWidth * 0.15 : 30.0;
    final cardPadding = isTablet ? 50.0 : isSmallScreen ? 25.0 : 40.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: screenHeight - MediaQuery.of(context).padding.top,
            ),
            child: Stack(
              children: [
                // Yellow background curved section
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
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                ),

                // Top decorative elements
                if (!isLandscape) ...[
                  // Top left moon icon
                  Positioned(
                    top: isSmallScreen ? 20 : 40,
                    left: 30,
                    child: CircleAvatar(
                      radius: isSmallScreen ? 20 : 25,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.nightlight_round,
                        color: Colors.black,
                        size: isSmallScreen ? 24 : 30,
                      ),
                    ),
                  ),

                  // Top right hamburger menu (decorative)
                  Positioned(
                    top: isSmallScreen ? 30 : 50,
                    right: 30,
                    child: Column(
                      children: List.generate(
                        3,
                        (index) => Container(
                          width: 25,
                          height: 3,
                          color: Colors.black,
                          margin: EdgeInsets.only(bottom: index < 2 ? 4 : 0),
                        ),
                      ),
                    ),
                  ),
                ],

                // Main login card - centered
                Center(
                  child: Container(
                    width: isTablet ? 500 : screenWidth - (horizontalPadding * 2),
                    margin: EdgeInsets.only(
                      top: isLandscape ? 20 : backgroundHeight - backgroundHeight / 2,
                      bottom: 20,
                    ),
                    constraints: BoxConstraints(
                      minHeight: cardHeight,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.all(Radius.circular(30)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 20,
                          offset: Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(cardPadding),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // BusBee logo section
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 40 : 30,
                                vertical: isSmallScreen ? 12 : 18,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1C1C1C),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: isSmallScreen ? 35 : 45,
                                    height: isSmallScreen ? 35 : 45,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFC107),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.directions_bus,
                                      color: Colors.black,
                                      size: isSmallScreen ? 22 : 28,
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Text(
                                    'BusBee',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isTablet ? 32 : isSmallScreen ? 24 : 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: isSmallScreen ? 30 : 50),

                            // Phone (username) field
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(color: Colors.black, width: 2),
                              ),
                              child: TextFormField(
                                controller: _usernameController,
                                keyboardType: TextInputType.phone,
                                validator: _validatePhoneField,
                                style: TextStyle(fontSize: isTablet ? 18 : 16),
                                decoration: InputDecoration(
                                  hintText: 'Phone number (e.g., 0771234567)',
                                  hintStyle: TextStyle(fontSize: isTablet ? 16 : 14),
                                  prefixIcon: Icon(
                                    Icons.phone,
                                    color: Colors.black,
                                    size: isTablet ? 24 : 20,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: isSmallScreen ? 12 : 15,
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(height: isSmallScreen ? 15 : 20),

                            // Password field
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(color: Colors.black, width: 2),
                              ),
                              child: TextFormField(
                                controller: _passwordController,
                                obscureText: !_isPasswordVisible,
                                validator: _validatePasswordField,
                                style: TextStyle(fontSize: isTablet ? 18 : 16),
                                decoration: InputDecoration(
                                  hintText: 'Password',
                                  hintStyle: TextStyle(fontSize: isTablet ? 16 : 14),
                                  prefixIcon: Icon(
                                    Icons.lock,
                                    color: Colors.black,
                                    size: isTablet ? 24 : 20,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                      color: Colors.black54,
                                      size: isTablet ? 24 : 20,
                                    ),
                                    onPressed: () =>
                                        setState(() => _isPasswordVisible = !_isPasswordVisible),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: isSmallScreen ? 12 : 15,
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(height: isSmallScreen ? 20 : 30),

                            // Login button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _signIn,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFC107),
                                  foregroundColor: Colors.black,
                                  padding: EdgeInsets.symmetric(
                                    vertical: isSmallScreen ? 12 : 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                    side: const BorderSide(color: Colors.black, width: 2),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isLoading
                                    ? SizedBox(
                                        height: isSmallScreen ? 18 : 20,
                                        width: isSmallScreen ? 18 : 20,
                                        child: const CircularProgressIndicator(
                                          color: Colors.black,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        'Login',
                                        style: TextStyle(
                                          fontSize: isTablet ? 20 : 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),

                            SizedBox(height: isSmallScreen ? 15 : 20),

                            // Sign up link
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  "Don't have an account? ",
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: isTablet ? 18 : 16,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const BusBeeSignUpScreen(),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    'Sign Up',
                                    style: TextStyle(
                                      color: const Color(0xFFFFC107),
                                      fontSize: isTablet ? 18 : 16,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: isSmallScreen ? 10 : 20),
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
}
