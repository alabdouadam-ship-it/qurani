import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

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
  bool _isLoading = true;
  String? _htmlContent;
  final String _iframeId = 'help-iframe-${DateTime.now().millisecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      // Load HTML content from assets
      final content = await rootBundle.loadString(widget.assetPath);
      
      if (mounted) {
        setState(() {
          _htmlContent = content;
          _isLoading = false;
        });
        
        // Register the iframe view
        _registerIframe();
      }
    } catch (e) {
      debugPrint('[LocalWebView] Failed to load asset: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _registerIframe() {
    if (_htmlContent == null) return;
    
    // Register view factory for iframe
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
      _iframeId,
      (int viewId) {
        final iframe = html.IFrameElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.border = 'none'
          ..srcdoc = _htmlContent;
        
        return iframe;
      },
    );
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _htmlContent != null
                ? HtmlElementView(viewType: _iframeId)
                : const Center(
                    child: Text('Failed to load content'),
                  ),
      ),
    );
  }
}
