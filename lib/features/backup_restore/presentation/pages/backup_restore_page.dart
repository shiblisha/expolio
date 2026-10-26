import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../data/backup_restore_service.dart';

class BackupRestorePage extends StatefulWidget {
  const BackupRestorePage({super.key});

  @override
  State<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends State<BackupRestorePage> {
  final _service = BackupRestoreService();
  bool _working = false;

  Future<void> _createBackup() async {
    if (_working) return;

    setState(() => _working = true);

    try {
      final path = await _service.saveBackupFile();

      if (!mounted) return;

      if (path == null || path.isEmpty) {
        _showMessage('Backup cancelled.');
      } else {
        _showMessage('Backup saved successfully.');
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        error.toString().replaceFirst('Bad state: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  Future<void> _restoreBackup() async {
    if (_working) return;

    final confirmed = await _showRestoreConfirmation();
    if (!confirmed || !mounted) return;

    setState(() => _working = true);

    try {
      final summary = await _service.pickAndRestore();

      if (!mounted) return;
      if (summary == null) {
        _showMessage('Restore cancelled.');
        return;
      }

      _showRestoreResult(summary);
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        error.toString().replaceFirst('Bad state: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  Future<bool> _showRestoreConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Restore backup?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'The backup will be merged into this account. Existing documents '
            'with the same IDs will be replaced, but documents that are not '
            'in the backup will not be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  void _showRestoreResult(RestoreSummary summary) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Restore complete',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Text(
            '${summary.totalDocuments} documents restored.\n\n'
            'Transactions: ${summary.counts['transactions'] ?? 0}\n'
            'Budgets: ${summary.counts['budgets'] ?? 0}\n'
            'Wallets: ${summary.counts['wallets'] ?? 0}\n'
            'Bills: ${summary.counts['bills'] ?? 0}\n'
            'Categories: ${summary.counts['categories'] ?? 0}\n'
            'Recurring: ${summary.counts['recurring_transactions'] ?? 0}\n'
            'Savings goals: ${summary.counts['savings_goals'] ?? 0}',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? AppColors.expense : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Backup & Restore',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
        children: [
          _buildHeroCard(context),
          const SizedBox(height: 20),
          _buildActionCard(
            context,
            icon: Icons.download_rounded,
            title: 'Create Backup',
            subtitle: 'Export your MoneyFlow data as a JSON file',
            accent: AppColors.primary,
            onTap: _working ? null : _createBackup,
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            context,
            icon: Icons.upload_rounded,
            title: 'Restore Backup',
            subtitle: 'Import a previous MoneyFlow JSON backup',
            accent: AppColors.navPurple,
            onTap: _working ? null : _restoreBackup,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurface
                  : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark
                    ? AppColors.darkBorder
                    : AppColors.lightBorder,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield_outlined,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Restore uses your current signed-in account. '
                    'It updates matching records but does not delete data '
                    'that is not present in the backup.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      height: 1.45,
                      color: theme.textTheme.bodySmall?.color
                          ?.withValues(alpha: 0.62),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_working) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: isDark ? 0.22 : 0.12),
            AppColors.navPurple.withValues(alpha: isDark ? 0.18 : 0.07),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_sync_rounded,
              color: AppColors.primary,
              size: 29,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Protect your MoneyFlow data',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Back up transactions, wallets, budgets, bills, categories, goals and recurring transactions.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.4,
                    color: theme.textTheme.bodySmall?.color
                        ?.withValues(alpha: 0.60),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
    required VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final disabled = onTap == null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurface
                : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark
                  ? AppColors.darkBorder
                  : AppColors.lightBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: disabled ? 0.05 : 0.11),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: disabled
                      ? accent.withValues(alpha: 0.4)
                      : accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.35,
                        color: theme.textTheme.bodySmall?.color
                            ?.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.textTheme.bodyMedium?.color
                    ?.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
