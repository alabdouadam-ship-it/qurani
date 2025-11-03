import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class LocalWebViewScreen extends StatefulWidget {
  const LocalWebViewScreen({super.key, required this.title, required this.assetPath});

  final String title;
  final String assetPath; // e.g. 'public/help.html'

  @override
  State<LocalWebViewScreen> createState() => _LocalWebViewScreenState();
}

class _LocalWebViewScreenState extends State<LocalWebViewScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadFlutterAsset(widget.assetPath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: SafeArea(
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}


