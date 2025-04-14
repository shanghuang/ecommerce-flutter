import 'package:flutter/material.dart';
import 'pages/login_page.dart'; // Add this import

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      initialRoute: '/login', // Change this
      routes: {
        '/login': (context) => const LoginPage(),
        //'/home': (context) => const MyHomePage(title: 'Home Page'),
      },
    );
  }
}

// ... rest of the existing code remains the same ...
