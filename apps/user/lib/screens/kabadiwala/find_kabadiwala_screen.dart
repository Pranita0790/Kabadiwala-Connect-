import 'package:flutter/material.dart';

class FindKabadiwalaScreen extends StatefulWidget {
  final String title;

  const FindKabadiwalaScreen({super.key, this.title = 'Find Kabadiwala'});

  @override
  State<FindKabadiwalaScreen> createState() => _FindKabadiwalaScreenState();
}

class _FindKabadiwalaScreenState extends State<FindKabadiwalaScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Text(
          widget.title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
