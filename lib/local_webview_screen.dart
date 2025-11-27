import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:io';

class LocalWebViewScreen extends StatefulWidget {
  const LocalWebViewScreen({
    super.key,
    required this.title,
    required this.assetPath,
    this.onlineUrl,
  });

  final String title;
  final String assetPath; // e.g. 'public/help_en.html'
  final String? onlineUrl; // Optional online URL to try first

  @override
  State<LocalWebViewScreen> createState() => _LocalWebViewScreenState();
}

class _LocalWebViewScreenState extends State<LocalWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            // If online URL fails, fallback to local asset
            if (widget.onlineUrl != null) {
              debugPrint('[LocalWebView] Online URL failed: ${error.description}');
              _loadLocalAsset();
            }
          },
        ),
      );
    
    _loadContent();
  }

  Future<void> _loadContent() async {
    // If online URL is provided, try to load it first
    if (widget.onlineUrl != null) {
      final hasInternet = await _checkInternetConnection();
      if (hasInternet) {
        try {
          await _controller.loadRequest(Uri.parse(widget.onlineUrl!));
          return;
        } catch (e) {
          debugPrint('[LocalWebView] Failed to load online URL: $e');
        }
      }
    }
    
    // Fallback to local asset
    _loadLocalAsset();
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('qurani.info');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _loadLocalAsset() {
    _controller.loadFlutterAsset(widget.assetPath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
