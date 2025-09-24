import 'package:busbee_passenger/authentication/auth.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp();
  
  // For development: Set log level to reduce warnings
  if (kDebugMode) {
    // This reduces Firebase SDK logging
    FirebaseDatabase.instance.setLoggingEnabled(false);
  }
  
  runApp(MyApp());
}