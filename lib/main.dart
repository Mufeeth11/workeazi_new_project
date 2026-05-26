import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'login_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      title: 'WorkEazi',
      theme: const CupertinoThemeData(
        primaryColor: CupertinoColors.systemPurple,
        // Use Roboto globally — removes iOS San Francisco font
        textTheme: CupertinoTextThemeData(
          textStyle: TextStyle(
            fontFamily: 'Roboto',
            color: CupertinoColors.black,
          ),
        ),
      ),
      home: const LoginPage(),
    );
  }
}
