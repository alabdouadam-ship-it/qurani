import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Utility class for showing debug-only error information
/// that users can screenshot and send to developers
class DebugErrorDisplay {
  /// Shows an error dialog only in debug mode
  /// The dialog contains concise error info suitable for screenshots
  static void showError(
    BuildContext context, {
    required String screen,
    required String operation,
    required String error,
    String? stackTrace,
  }) {
    // Only show in debug mode
    if (!kDebugMode) return;
    if (!context.mounted) return;

    // Extract first few lines of stack trace
    String shortStack = '';
    if (stackTrace != null) {
      final lines = stackTrace.split('\n');
      shortStack = lines.take(3).join('\n');
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red.shade50,
        title: Row(
          children: [
            Icon(Icons.bug_report, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Text(
              'DEBUG ERROR',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '📸 Take a screenshot and send to developer',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const Divider(),
              _buildInfoRow('Screen', screen),
              _buildInfoRow('Operation', operation),
              const SizedBox(height: 8),
              const Text(
                'Error:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.red.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(
                  error,
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              if (shortStack.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Stack (first 3 lines):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.red.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    shortStack,
                    style: const TextStyle(
                      fontSize: 9,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
