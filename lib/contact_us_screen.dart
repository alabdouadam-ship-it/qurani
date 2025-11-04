import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key});

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  String? _email;
  String? _whatsApp;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final txt = await rootBundle.loadString('public/contact.json');
      final data = json.decode(txt) as Map<String, dynamic>;
      setState(() {
        _email = data['email'] as String?;
        _whatsApp = data['whatsapp'] as String?;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    final uri = Uri.parse('https://wa.me/${phone.replaceAll('+', '')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.contactUs)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.chat),
                    title: Text(l10n.contactViaWhatsApp),
                    subtitle: Text(_whatsApp ?? '-'),
                    onTap: _whatsApp == null ? null : () => _openWhatsApp(_whatsApp!),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy),
                      tooltip: l10n.copy,
                      onPressed: _whatsApp == null
                          ? null
                          : () async {
                              final v = _whatsApp;
                              if (v != null) {
                                await Clipboard.setData(ClipboardData(text: v));
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.copied)));
                              }
                            },
                    ),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.alternate_email),
                    title: Text(l10n.contactViaEmail),
                    subtitle: Text(_email ?? '-'),
                    onTap: _email == null ? null : () => _openEmail(_email!),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy),
                      tooltip: l10n.copy,
                      onPressed: _email == null
                          ? null
                          : () async {
                              final v = _email;
                              if (v != null) {
                                await Clipboard.setData(ClipboardData(text: v));
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.copied)));
                              }
                            },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}


