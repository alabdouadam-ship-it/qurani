import 'package:flutter/material.dart';

void main() {
  runApp(IconGeneratorApp());
}

class IconGeneratorApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Qurani Icon Generator',
      home: Scaffold(
        backgroundColor: Colors.green[700],
        body: Center(
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.menu_book,
                  size: 80,
                  color: Colors.green[700],
                ),
                SizedBox(height: 10),
                Text(
                  'Qurani',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                    fontFamily: 'Cairo',
                  ),
                ),
                Text(
                  'القرآن الكريم',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.green[600],
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

