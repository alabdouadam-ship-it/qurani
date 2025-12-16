import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/services/contact_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key});

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  String? _email;
  String? _whatsApp;
  String? _whatsAppGroup;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ContactService.getContactInfo();
      if (!mounted) return;
      setState(() {
        _email = data['email'] as String?;
        _whatsApp = data['whatsapp'] as String?;
        _whatsAppGroup = data['whatsapp_group'] as String?;
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

  Future<void> _openWhatsAppGroup(String groupUrl) async {
    final uri = Uri.parse(groupUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.contactUs)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
              children: [
                Text(
                  l10n.whyContactUs,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.bug_report, color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.reportBugTitle,
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.reportBugDesc,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.favorite, color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.supportUsTitle,
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.supportUsDesc,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb, color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.shareIdeaTitle,
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.shareIdeaDesc,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.getInTouch,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.chat),
                    title: Text(l10n.contactViaWhatsApp),
                    subtitle: _whatsApp == null 
                        ? Text('-')
                        : GestureDetector(
                            onTap: () => _openWhatsApp(_whatsApp!),
                            child: Text(
                              _whatsApp!,
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
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
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.group),
                    //title: Text(l10n.contactViaWhatsAppGroup),
                    subtitle: _whatsAppGroup == null 
                        ? Text('-')
                        : GestureDetector(
                            onTap: () => _openWhatsAppGroup(_whatsAppGroup!),
                            child: Text(
                              l10n.contactViaWhatsAppGroup,
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                    onTap: _whatsAppGroup == null ? null : () => _openWhatsAppGroup(_whatsAppGroup!),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy),
                      tooltip: l10n.copy,
                      onPressed: _whatsAppGroup == null
                          ? null
                          : () async {
                              final v = _whatsAppGroup;
                              if (v != null) {
                                await Clipboard.setData(ClipboardData(text: v));
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.copied)));
                              }
                            },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.alternate_email),
                    title: Text(l10n.contactViaEmail),
                    subtitle: _email == null
                        ? Text('-')
                        : GestureDetector(
                            onTap: () => _openEmail(_email!),
                            child: Text(
                              _email!,
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
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


