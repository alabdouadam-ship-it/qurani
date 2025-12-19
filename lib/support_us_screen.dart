import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qurani/l10n/app_localizations.dart';

class SupportUsScreen extends StatefulWidget {
  const SupportUsScreen({super.key});

  @override
  State<SupportUsScreen> createState() => _SupportUsScreenState();
}

class _SupportUsScreenState extends State<SupportUsScreen> {
  String? _paypalEmail;
  String? _usdt;
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
        _paypalEmail = data['paypal_email'] as String?;
        _usdt = data['usdt'] as String?;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.supportUs)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(l10n.supportIntro, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    title: Text(l10n.donateViaPayPal),
                    subtitle: Text('${l10n.paypalEmail}: ${_paypalEmail ?? '-'}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy),
                      tooltip: l10n.copy,
                      onPressed: _paypalEmail == null
                          ? null
                          : () async {
                              final v = _paypalEmail; // local promotion-safe
                              if (v != null) {
                                final messenger = ScaffoldMessenger.of(context);
                                final copiedText = l10n.copied;
                                await Clipboard.setData(ClipboardData(text: v));
                                if (!mounted) return;
                                messenger.showSnackBar(SnackBar(content: Text(copiedText)));
                              }
                            },
                    ),
                  ),
                ),
                Card(
                  child: ListTile(
                    title: Text(l10n.donateViaCrypto),
                    subtitle: Text('${l10n.usdtAddress}: ${_usdt ?? '-'}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy),
                      tooltip: l10n.copy,
                      onPressed: _usdt == null
                          ? null
                          : () async {
                              final v = _usdt; // local promotion-safe
                              if (v != null) {
                                final messenger = ScaffoldMessenger.of(context);
                                final copiedText = l10n.copied;
                                await Clipboard.setData(ClipboardData(text: v));
                                if (!mounted) return;
                                messenger.showSnackBar(SnackBar(content: Text(copiedText)));
                              }
                            },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.ondemand_video),
                  title: Text(l10n.watchAd),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.watchAd)),
                    );
                  },
                ),
              ],
            ),
    );
  }
}


