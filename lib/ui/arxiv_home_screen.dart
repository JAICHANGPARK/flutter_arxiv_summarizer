import 'package:flutter/material.dart';


class ArxivHomeScreen extends StatefulWidget {
  const ArxivHomeScreen({super.key});

  @override
  State<ArxivHomeScreen> createState() => _ArxivHomeScreenState();
}

class _ArxivHomeScreenState extends State<ArxivHomeScreen> {
  TextEditingController textEditingController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Arxiv Summarizer"),
      ),
      body: Column(
        children: [

        ],
      ),
    );
  }
}
