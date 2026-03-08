import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/services/contact_service.dart';
import 'package:qurani/widgets/modern_ui.dart';
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
    return ModernPageScaffold(
      title: l10n.contactUs,
      icon: Icons.support_agent_rounded,
      subtitle: l10n.localeName == 'ar'
          ? 'تواصل معنا للإبلاغ عن مشكلة أو مشاركة فكرة أو دعم التطبيق.'
          : l10n.localeName == 'fr'
              ? 'Contactez-nous pour signaler un problème, proposer une idée ou soutenir l’application.'
              : 'Contact us to report an issue, share an idea, or support the app.',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 48),
              children: [
                Text(
                  l10n.whyContactUs,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildReasonCard(
                  context,
                  icon: Icons.bug_report,
                  title: l10n.reportBugTitle,
                  description: l10n.reportBugDesc,
                ),
                const SizedBox(height: 12),
                _buildReasonCard(
                  context,
                  icon: Icons.favorite,
                  title: l10n.supportUsTitle,
                  description: l10n.supportUsDesc,
                ),
                const SizedBox(height: 12),
                _buildReasonCard(
                  context,
                  icon: Icons.lightbulb,
                  title: l10n.shareIdeaTitle,
                  description: l10n.shareIdeaDesc,
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.getInTouch,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ModernSurfaceCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.chat),
                    title: Text(l10n.contactViaWhatsApp),
                    subtitle: _whatsApp == null
                        ? const Text('-')
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
                const SizedBox(height: 12),
                ModernSurfaceCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.group),
                    subtitle: _whatsAppGroup == null
                        ? const Text('-')
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
                const SizedBox(height: 12),
                ModernSurfaceCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.alternate_email),
                    title: Text(l10n.contactViaEmail),
                    subtitle: _email == null
                        ? const Text('-')
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
              ],
            ),
    );
  }

  Widget _buildReasonCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);
    return ModernSurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
 }


