import 'package:flutter/material.dart';
import 'package:opencv_4/opencv_4.dart';
import 'package:opencv_4/factory/pathfrom.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenCV Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const OpenCVTestPage(),
    );
  }
}

class OpenCVTestPage extends StatefulWidget {
  const OpenCVTestPage({super.key});

  @override
  State<OpenCVTestPage> createState() => _OpenCVTestPageState();
}

class _OpenCVTestPageState extends State<OpenCVTestPage> {
  bool _isInitialized = false;
  String _message = 'Initializing OpenCV...';

  @override
  void initState() {
    super.initState();
    _initOpenCV();
  }

  Future<void> _initOpenCV() async {
    try {
      // Print the OpenCV class to see its structure
      print('OpenCV class: ${OpenCV}');
      
      // Initialize OpenCV
      final opencv = OpenCV();
      final result = await opencv.initAsync();
      
      setState(() {
        _isInitialized = result;
        _message = 'OpenCV initialized: $result';
      });
      
      print('OpenCV initialized: $result');
      
      // Print available methods
      print('Available methods:');
      print(opencv.toString());
      
    } catch (e) {
      setState(() {
        _message = 'Error initializing OpenCV: $e';
      });
      print('Error initializing OpenCV: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OpenCV Test'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              _message,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
    );
  }
}
