import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';
import 'screens/lesson_screen.dart';

void main() {
  runApp(DyscalculiaApp());
}

class DyscalculiaApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MathMinds',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Arial',
      ),
      home: WelcomeScreen(),
    );
  }
}
