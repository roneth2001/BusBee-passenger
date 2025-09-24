import 'package:busbee_passenger/screens/userDashBoard.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

class BusBeeSignUpScreen extends StatefulWidget {
  const BusBeeSignUpScreen({Key? key}) : super(key: key);

  @override
  State<BusBeeSignUpScreen> createState() => _BusBeeSignUpScreenState();
}

class _BusBeeSignUpScreenState extends State<BusBeeSignUpScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Optional (Firebase already hashes passwords)
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<bool> _isPhoneNumberExists(String phoneNumber) async {
    try {
      final querySnapshot = await _firestore
          .collection('passengers')
          .where('phoneNumber', isEqualTo: phoneNumber.trim())
          .limit(1)
          .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking phone number: $e');
      return false;
    }
  }

  Future<void> _createUserAccount() async {
    if (!_formKey.currentState!.validate()) return;

    final phoneExists = await _isPhoneNumberExists(_phoneController.text.trim());
    if (phoneExists) {
      _showErrorSnackBar('An account with this phone number already exists.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String email = '${_phoneController.text.trim()}@busbee.com';

      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: _passwordController.text.trim(),
      );

      final String userId = userCredential.user!.uid;

      await _firestore.collection('passengers').doc(userId).set({
        'userId': userId,
        'fullName': _nameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'email': email,
        'passwordHash': _hashPassword(_passwordController.text.trim()),
        'accountType': 'passenger',
        'isActive': true,
        'profileComplete': true,
        'registrationDate': FieldValue.serverTimestamp(),
        'lastLoginDate': FieldValue.serverTimestamp(),
        'notificationSettings': {
          'busArrival': true,
          'delayAlerts': true,
          'generalUpdates': true,
        },
        'version': 1,
      });

      await userCredential.user!.updateDisplayName(_nameController.text.trim());

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created successfully!'),
          backgroundColor: Color(0xFFFFC107),
          duration: Duration(seconds: 2),
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const BusBeeMenuScreen()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      _showErrorSnackBar(_getAuthErrorMessage(e.code));
    } catch (e) {
      debugPrint('Error creating user account: $e');
      _showErrorSnackBar('An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getAuthErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account with this phone number already exists.';
      case 'invalid-email':
        return 'Invalid phone number format.';
      case 'operation-not-allowed':
        return 'Account creation is disabled.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your full name';
    if (value.trim().length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  String? _validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your phone number';
    final clean = value.replaceAll(RegExp(r'[^\d]'), '');
    if (clean.length == 10 && clean.startsWith('0')) return null;
    return 'Please enter a valid Sri Lankan phone number (e.g., 0771234567)';
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Please enter a password';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
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
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 700;
    final isTablet = screenWidth > 600;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    // Responsive dimensions
    final backgroundHeight = isLandscape ? screenHeight * 0.25 : screenHeight * 0.4;
    final horizontalPadding = isTablet ? screenWidth * 0.15 : 20.0;
    final cardPadding = isTablet ? 50.0 : isSmallScreen ? 25.0 : 40.0;
    final titleTopPosition = isLandscape ? 40.0 : 100.0;
    final formTopPosition = isLandscape ? backgroundHeight - 20 : screenHeight * 0.28;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SizedBox(
          height: screenHeight - MediaQuery.of(context).padding.top,
          width: screenWidth,
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
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
              ),

              // Back button
              Positioned(
                top: isSmallScreen ? 20 : 40,
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

              // Sign Up Title
              if (!isLandscape)
                Positioned(
                  top: titleTopPosition,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: isTablet ? 36 : isSmallScreen ? 28 : 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 4 : 8),
                      Text(
                        'Join BusBee today!',
                        style: TextStyle(
                          fontSize: isTablet ? 18 : 16,
                          color: Colors.black.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),

              // Main sign up form - responsive positioning
              Positioned.fill(
                top: formTopPosition,
                left: horizontalPadding,
                right: horizontalPadding,
                bottom: 20,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: isTablet ? 600 : double.infinity,
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
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(cardPadding),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: isSmallScreen ? 10 : 20),

                          // BusBee logo section
                          Center(
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 30 : 25,
                                vertical: isSmallScreen ? 10 : 15,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2C2C2C),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: isSmallScreen ? 30 : 40,
                                    height: isSmallScreen ? 30 : 40,
                                    child: DecoratedBox(
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFFC107),
                                        borderRadius: BorderRadius.all(Radius.circular(8)),
                                      ),
                                      child: Icon(
                                        Icons.directions_bus,
                                        color: Colors.black,
                                        size: isSmallScreen ? 18 : 24,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'BusBee',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isTablet ? 28 : isSmallScreen ? 20 : 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: isSmallScreen ? 25 : 40),

                          // Full Name
                          Text(
                            'Full Name',
                            style: TextStyle(
                              fontSize: isTablet ? 18 : 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 6 : 8),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                            child: TextFormField(
                              controller: _nameController,
                              validator: _validateName,
                              textCapitalization: TextCapitalization.words,
                              style: TextStyle(fontSize: isTablet ? 18 : 16),
                              decoration: InputDecoration(
                                hintText: 'Enter your full name',
                                hintStyle: TextStyle(fontSize: isTablet ? 16 : 14),
                                prefixIcon: Icon(
                                  Icons.person_outline,
                                  color: Colors.black54,
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

                          // Phone Number
                          Text(
                            'Phone Number',
                            style: TextStyle(
                              fontSize: isTablet ? 18 : 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 6 : 8),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                            child: TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              validator: _validatePhoneNumber,
                              style: TextStyle(fontSize: isTablet ? 18 : 16),
                              decoration: InputDecoration(
                                hintText: '07X XX XX XXX',
                                hintStyle: TextStyle(fontSize: isTablet ? 16 : 14),
                                prefixIcon: Icon(
                                  Icons.phone_outlined,
                                  color: Colors.black54,
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

                          // Password
                          Text(
                            'Password',
                            style: TextStyle(
                              fontSize: isTablet ? 18 : 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 6 : 8),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                            child: TextFormField(
                              controller: _passwordController,
                              obscureText: !_isPasswordVisible,
                              validator: _validatePassword,
                              style: TextStyle(fontSize: isTablet ? 18 : 16),
                              decoration: InputDecoration(
                                hintText: 'Create a strong password',
                                hintStyle: TextStyle(fontSize: isTablet ? 16 : 14),
                                prefixIcon: Icon(
                                  Icons.lock_outline,
                                  color: Colors.black54,
                                  size: isTablet ? 24 : 20,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                    color: Colors.black54,
                                    size: isTablet ? 24 : 20,
                                  ),
                                  onPressed: () {
                                    setState(() => _isPasswordVisible = !_isPasswordVisible);
                                  },
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

                          // Confirm Password
                          Text(
                            'Confirm Password',
                            style: TextStyle(
                              fontSize: isTablet ? 18 : 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 6 : 8),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                            child: TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: !_isConfirmPasswordVisible,
                              style: TextStyle(fontSize: isTablet ? 18 : 16),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please confirm your password';
                                }
                                if (value != _passwordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                hintText: 'Re-enter your password',
                                hintStyle: TextStyle(fontSize: isTablet ? 16 : 14),
                                prefixIcon: Icon(
                                  Icons.lock_outline,
                                  color: Colors.black54,
                                  size: isTablet ? 24 : 20,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                    color: Colors.black54,
                                    size: isTablet ? 24 : 20,
                                  ),
                                  onPressed: () {
                                    setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible);
                                  },
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: isSmallScreen ? 12 : 15,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: isSmallScreen ? 25 : 40),

                          // Sign Up button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _createUserAccount,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFC107),
                                foregroundColor: Colors.black,
                                padding: EdgeInsets.symmetric(
                                  vertical: isSmallScreen ? 15 : 18,
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
                                      'Create Account',
                                      style: TextStyle(
                                        fontSize: isTablet ? 20 : 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),

                          SizedBox(height: isSmallScreen ? 20 : 25),

                          // Already have an account
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Already have an account? ",
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: isTablet ? 18 : 16,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Text(
                                  'Sign In',
                                  style: TextStyle(
                                    color: const Color(0xFFFFC107),
                                    fontSize: isTablet ? 16 : 14,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: isSmallScreen ? 15 : 20),
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
