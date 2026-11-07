import 'package:flutter/material.dart';

void main() {
  runApp(const TimeTrackApp());
}

/// Root widget. The real screens (Today, Calendar, Projects, …) arrive in milestone M2.
class TimeTrackApp extends StatelessWidget {
  const TimeTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TimeTrack',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const Scaffold(body: Center(child: Text('TimeTrack'))),
    );
  }
}
