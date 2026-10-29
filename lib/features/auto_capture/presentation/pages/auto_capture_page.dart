import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/enums/category_type.dart';
import '../../../../core/enums/payment_method.dart';
import '../../../../core/enums/transaction_type.dart';
import '../../../categories/presentation/bloc/category_bloc.dart';
import '../../../wallet/presentation/bloc/wallet_bloc.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/bloc/transaction_bloc.dart';
import '../../../transactions/presentation/bloc/transaction_event.dart';
import '../../../transactions/presentation/bloc/transaction_state.dart';

class AutoCapturePage extends StatefulWidget {
  const AutoCapturePage({super.key});

  @override
  State<AutoCapturePage> createState() => _AutoCapturePageState();
}

class _AutoCapturePageState extends State<AutoCapturePage>
    with WidgetsBindingObserver {
  static const MethodChannel _channel = MethodChannel(
    'expolio/notification_capture',
  );

  bool _isLoading = true;
  bool _hasAccess = false;
  bool _hasSmsPermission = false;
  bool _hasPostNotificationsPermission = false;
  bool _hasOverlayPermission = false;
  String? _error;
  List<Map<String, dynamic>> _events = const [];
  List<Map<String, dynamic>> _smsEvents = const [];
  final Set<String> _promptedSmsIds = <String>{};
  Timer? _pollTimer;
  bool _refreshInProgress = false;
  bool _showingSmsDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted && !_isLoading) _refresh();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    if (_refreshInProgress) return;
    _refreshInProgress = true;
    if (!Platform.isAndroid) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasAccess = false;
          _error =
              'Notification capture is currently available on Android only.';
          _events = const [];
        });
      }
      _refreshInProgress = false;
      return;
    }

    try {
      final hasAccess =
          await _channel.invokeMethod<bool>('hasNotificationAccess') ?? false;
      final result =
          await _channel.invokeMethod<List<dynamic>>(
            'getCapturedNotifications',
          ) ??
          const [];
      final hasSmsPermission =
          await _channel.invokeMethod<bool>('hasSmsPermission') ?? false;
      final hasOverlayPermission =
          await _channel.invokeMethod<bool>('hasOverlayPermission') ?? false;
      final hasPostNotificationsPermission =
          await _channel.invokeMethod<bool>('hasPostNotificationsPermission') ??
          false;
      final smsResult =
          await _channel.invokeMethod<List<dynamic>>('getCapturedSmsEvents') ??
          const [];

      if (!mounted) return;
      setState(() {
        _hasAccess = hasAccess;
        _hasSmsPermission = hasSmsPermission;
        _hasOverlayPermission = hasOverlayPermission;
        _hasPostNotificationsPermission = hasPostNotificationsPermission;
        _events = result
            .whereType<Map>()
            .map((event) => Map<String, dynamic>.from(event))
            .toList();
        _smsEvents = smsResult
            .whereType<Map>()
            .map((event) => Map<String, dynamic>.from(event))
            .toList();
        _isLoading = false;
        _error = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybePromptSmsEvent();
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.message ?? 'Could not read notification capture status.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not read notification capture status.';
      });
    } finally {
      _refreshInProgress = false;
    }
  }

  Future<void> _maybePromptSmsEvent() async {
    if (!mounted || _showingSmsDialog) return;
    final candidate = _smsEvents.where((event) {
      final id = event['id']?.toString() ?? '';
      final amount = (event['amount'] as num?)?.toDouble() ?? 0;
      return id.isNotEmpty && amount > 0 && !_promptedSmsIds.contains(id);
    }).firstOrNull;
    if (candidate == null) return;

    final id = candidate['id']?.toString() ?? '';
    _promptedSmsIds.add(id);
    _showingSmsDialog = true;
    try {
      await _showSmsTransactionDialog(candidate);
    } finally {
      _showingSmsDialog = false;
    }
  }

  Future<void> _showSmsTransactionDialog(Map<String, dynamic> event) async {
    if (!mounted) return;
    final categoryBloc = context.read<CategoryBloc>();
    final walletBloc = context.read<WalletBloc>();
    final transactionBloc = context.read<TransactionBloc>();
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) return;

    final amount = (event['amount'] as num?)?.toDouble() ?? 0;
    final direction = event['direction']?.toString() ?? 'unknown';
    final merchant = event['merchant']?.toString().trim() ?? '';
    final reference = event['reference']?.toString().trim() ?? '';
    final postedAt = (event['postedAt'] as num?)?.toInt() ?? 0;
    final date = postedAt > 0
        ? DateTime.fromMillisecondsSinceEpoch(postedAt)
        : DateTime.now();
    final categories = categoryBloc.state.categories;
    final wallets = walletBloc.state.wallets;

    if (categories.isEmpty || wallets.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Add at least one category and wallet before reviewing captured transactions.',
            ),
          ),
        );
      }
      return;
    }

    var selectedType = direction == 'credit'
        ? TransactionType.income
        : TransactionType.expense;
    String? selectedCategoryId = categories
        .where(
          (c) =>
              c.type ==
              (selectedType == TransactionType.income
                  ? CategoryType.income
                  : CategoryType.expense),
        )
        .map((c) => c.id)
        .firstOrNull;
    String? selectedWalletId = wallets.first.id;
    bool saving = false;
    String? dialogError;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final typeCategory = selectedType == TransactionType.income
              ? CategoryType.income
              : CategoryType.expense;
          final matchingCategories = categories
              .where((c) => c.type == typeCategory)
              .toList();
          if (selectedCategoryId != null &&
              !matchingCategories.any((c) => c.id == selectedCategoryId)) {
            selectedCategoryId = matchingCategories.isNotEmpty
                ? matchingCategories.first.id
                : null;
          }
          final selectedCategory = matchingCategories
              .where((c) => c.id == selectedCategoryId)
              .firstOrNull;
          final selectedWallet = wallets
              .where((w) => w.id == selectedWalletId)
              .firstOrNull;
          return AlertDialog(
            title: const Text('Review detected transaction'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${selectedType == TransactionType.income ? 'Money received' : 'Money spent'} · ₹${amount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    merchant.isNotEmpty ? merchant : 'Merchant not identified',
                  ),
                  if (reference.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Ref: $reference',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 18),
                  const Text(
                    'Transaction type',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  SegmentedButton<TransactionType>(
                    segments: const [
                      ButtonSegment(
                        value: TransactionType.expense,
                        label: Text('Expense'),
                        icon: Icon(Icons.arrow_upward_rounded),
                      ),
                      ButtonSegment(
                        value: TransactionType.income,
                        label: Text('Income'),
                        icon: Icon(Icons.arrow_downward_rounded),
                      ),
                    ],
                    selected: {selectedType},
                    onSelectionChanged: saving
                        ? null
                        : (selection) {
                            setDialogState(() {
                              selectedType = selection.first;
                              selectedCategoryId = categories
                                  .where(
                                    (c) =>
                                        c.type ==
                                        (selectedType == TransactionType.income
                                            ? CategoryType.income
                                            : CategoryType.expense),
                                  )
                                  .map((c) => c.id)
                                  .firstOrNull;
                            });
                          },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Category',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedCategoryId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Choose category',
                    ),
                    items: matchingCategories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(
                              c.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: saving
                        ? null
                        : (value) =>
                              setDialogState(() => selectedCategoryId = value),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Wallet / account',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedWalletId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Choose wallet',
                    ),
                    items: wallets
                        .map(
                          (w) => DropdownMenuItem(
                            value: w.id,
                            child: Text(
                              w.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: saving
                        ? null
                        : (value) =>
                              setDialogState(() => selectedWalletId = value),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(date)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      dialogError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving
                    ? null
                    : () => Navigator.of(dialogContext).pop(false),
                child: const Text('Later'),
              ),
              FilledButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                        if (selectedCategory == null ||
                            selectedWallet == null) {
                          setDialogState(
                            () => dialogError = 'Choose a category and wallet.',
                          );
                          return;
                        }
                        setDialogState(() {
                          saving = true;
                          dialogError = null;
                        });
                        final eventId = event['id']?.toString() ?? '';
                        final transaction = TransactionEntity(
                          // Stable ID means retrying this same captured event overwrites the same
                          // Firestore document instead of creating a duplicate.
                          id: eventId.isEmpty ? '' : 'sms_$eventId',
                          userId: authUser.uid,
                          amount: amount,
                          type: selectedType,
                          categoryId: selectedCategory.id,
                          categoryName: selectedCategory.name,
                          paymentMethod: PaymentMethod.upi,
                          description: merchant.isNotEmpty
                              ? 'UPI: $merchant'
                              : (reference.isNotEmpty
                                    ? 'Bank SMS UPI ref $reference'
                                    : 'Bank SMS transaction'),
                          date: date,
                          createdAt: DateTime.now(),
                          walletId: selectedWallet.id,
                          walletName: selectedWallet.name,
                        );
                        final startedSaving = transactionBloc.stream.firstWhere(
                          (state) => state.isSaving,
                        );
                        transactionBloc.add(AddTransactionEvent(transaction));
                        await startedSaving;
                        final result = await transactionBloc.stream.firstWhere(
                          (state) =>
                              !state.isSaving &&
                              (state.saveSuccess ||
                                  state.status == TransactionStatus.failure),
                        );
                        if (result.saveSuccess) {
                          try {
                            await _channel.invokeMethod<bool>(
                              'removeCapturedSmsEvent',
                              {'id': eventId},
                            );
                          } catch (_) {}
                          if (dialogContext.mounted)
                            Navigator.of(dialogContext).pop(true);
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Transaction added to Expolio.'),
                              ),
                            );
                            await _refresh();
                          }
                        } else {
                          setDialogState(() {
                            saving = false;
                            dialogError =
                                result.errorMessage ??
                                'Could not save transaction.';
                          });
                        }
                      },
                icon: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(saving ? 'Saving…' : 'Save transaction'),
              ),
            ],
          );
        },
      ),
    );
    if (saved == true) {
      _promptedSmsIds.remove(event['id']?.toString() ?? '');
    }
  }

  Future<void> _openSettings() async {
    try {
      await _channel.invokeMethod<bool>('openNotificationSettings');
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Could not open Android settings.'),
        ),
      );
    }
  }

  Future<void> _requestNotificationPermission() async {
    try {
      await _channel.invokeMethod<bool>('requestPostNotificationsPermission');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await _refresh();
      if (mounted && !_hasPostNotificationsPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Allow Expolio notifications in Android Settings to receive capture alerts.',
            ),
          ),
        );
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ?? 'Could not request notification permission.',
          ),
        ),
      );
    }
  }

  Future<void> _requestOverlayPermission() async {
    try {
      await _channel.invokeMethod<bool>('openOverlaySettings');
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Could not open overlay settings.'),
          ),
        );
      }
    }
  }

  Future<void> _requestSmsPermission() async {
    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable bank SMS capture?'),
        content: const Text(
          'Expolio will process newly received SMS messages on this device to look for bank transaction alerts. '
          'It does not request inbox-reading access, store the original message, or upload SMS text to Firebase. '
          'Android may refuse this restricted permission for a sideloaded app. You can deny it and continue using Expolio.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (shouldContinue != true) return;

    try {
      await _channel.invokeMethod<bool>('requestSmsPermission');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Check the Android permission prompt, then return here.',
            ),
          ),
        );
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Could not request SMS permission.'),
        ),
      );
    }
  }

  Future<void> _clearEvents() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear captured test events?'),
        content: const Text(
          'This removes the locally stored test events from this device. '
          'It does not delete your existing Expolio transactions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (shouldClear != true) return;

    try {
      await _channel.invokeMethod<bool>('clearCapturedNotifications');
      await _channel.invokeMethod<bool>('clearCapturedSmsEvents');
      await _refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not clear captured events.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto Expense Capture'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                children: [
                  _buildIntroCard(theme, isDark),
                  const SizedBox(height: 14),
                  if (!Platform.isAndroid)
                    _buildInfoCard(
                      icon: Icons.info_outline_rounded,
                      title: 'Android only for this test',
                      body:
                          'iOS does not let Expolio read notifications from other apps. '
                          'We will need a separate method for iPhone users.',
                    )
                  else ...[
                    _buildPermissionCard(theme, isDark),
                    const SizedBox(height: 12),
                    _buildBackgroundNotificationCard(theme, isDark),
                    const SizedBox(height: 12),
                    _buildFloatingPopupCard(theme, isDark),
                    const SizedBox(height: 12),
                    _buildSmsPermissionCard(theme, isDark),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Detected notifications',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (_events.isNotEmpty || _smsEvents.isNotEmpty)
                          TextButton(
                            onPressed: _clearEvents,
                            child: const Text('Clear'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_error != null)
                      _buildInfoCard(
                        icon: Icons.error_outline_rounded,
                        title: 'Capture status unavailable',
                        body: _error!,
                      )
                    else if (!_hasAccess)
                      _buildInfoCard(
                        icon: Icons.notifications_off_outlined,
                        title: 'Permission is not enabled yet',
                        body: 'Enable Expolio in Android Notification access, then return here.',
                      )
                    else if (_events.isEmpty && _smsEvents.isEmpty)
                      _buildInfoCard(
                        icon: Icons.hourglass_empty_rounded,
                        title: 'Waiting for a test transaction',
                        body:
                            'Enable notification access and, if Android allows it, SMS capture. '
                            'Then test with a bank transaction alert and refresh this page.',
                      )
                    else ...[
                      if (_events.isNotEmpty) ...[
                        Text(
                          'Payment-app notifications',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._events.map(
                          (event) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildEventCard(theme, isDark, event),
                          ),
                        ),
                      ],
                      if (_smsEvents.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Bank SMS matches',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._smsEvents.map(
                          (event) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildSmsEventCard(theme, isDark, event),
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 10),
                    _buildInfoCard(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy and current limitations',
                      body: 'Payment notification events and parsed SMS matches stay on this device. Expolio does not store original SMS text, browse your inbox, upload SMS content, or create Firestore transactions yet. Android may block RECEIVE_SMS for sideloaded apps; Google Play publication requires a separate policy review.',
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildIntroCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: isDark ? 0.24 : 0.13),
            AppColors.primary.withValues(alpha: isDark ? 0.09 : 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 30),
          SizedBox(height: 12),
          Text(
            'Let Expolio notice your payments',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 7),
          Text(
            'This prototype tests supported payment notifications and newly received bank SMS alerts. '
            'Matches stay on-device for review; real expenses are not created automatically yet.',
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _hasAccess
              ? AppColors.primary.withValues(alpha: 0.35)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _hasAccess
                ? Icons.check_circle_rounded
                : Icons.notifications_active_outlined,
            color: _hasAccess ? AppColors.primary : theme.colorScheme.secondary,
            size: 27,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _hasAccess
                      ? 'Notification access enabled'
                      : 'Enable notification access',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Text(
                  _hasAccess
                      ? 'Expolio can check eligible payment notifications on this device.'
                      : 'Android requires you to enable this permission manually in Settings. '
                            'Expolio only uses it for the supported payment-app list.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _openSettings,
                  icon: const Icon(Icons.settings_rounded),
                  label: Text(
                    _hasAccess ? 'Open settings' : 'Enable in Settings',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundNotificationCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _hasPostNotificationsPermission
              ? AppColors.primary.withValues(alpha: 0.35)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _hasPostNotificationsPermission
                ? Icons.check_circle_rounded
                : Icons.notifications_active_outlined,
            color: _hasPostNotificationsPermission
                ? AppColors.primary
                : theme.colorScheme.secondary,
            size: 27,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _hasPostNotificationsPermission
                      ? 'Background capture alerts enabled'
                      : 'Enable background capture alerts',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Text(
                  _hasPostNotificationsPermission
                      ? 'Expolio can show a system notification when a bank SMS transaction is detected, even when the app is closed. Tap it to open the review popup.'
                      : 'Allow notifications so Expolio can alert you when a bank SMS is detected while the app is closed. Tap the alert to review category and wallet.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _hasPostNotificationsPermission
                      ? _refresh
                      : _requestNotificationPermission,
                  icon: Icon(
                    _hasPostNotificationsPermission
                        ? Icons.refresh_rounded
                        : Icons.notifications_active_rounded,
                  ),
                  label: Text(
                    _hasPostNotificationsPermission
                        ? 'Check notification permission'
                        : 'Enable notifications',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingPopupCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _hasOverlayPermission
              ? AppColors.primary.withValues(alpha: 0.35)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _hasOverlayPermission
                ? Icons.check_circle_rounded
                : Icons.picture_in_picture_alt_rounded,
            color: _hasOverlayPermission
                ? AppColors.primary
                : theme.colorScheme.secondary,
            size: 27,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _hasOverlayPermission
                      ? 'Floating popup enabled'
                      : 'Floating popup over other apps',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Text(
                  'Show a small Expolio card over your home screen when a bank SMS is detected. Tap it to choose the category and wallet.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _hasOverlayPermission
                      ? _refresh
                      : _requestOverlayPermission,
                  icon: Icon(
                    _hasOverlayPermission
                        ? Icons.refresh_rounded
                        : Icons.open_in_new_rounded,
                  ),
                  label: Text(
                    _hasOverlayPermission
                        ? 'Check overlay permission'
                        : 'Allow floating popup',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmsPermissionCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _hasSmsPermission
              ? AppColors.primary.withValues(alpha: 0.35)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _hasSmsPermission ? Icons.check_circle_rounded : Icons.sms_outlined,
            color: _hasSmsPermission
                ? AppColors.primary
                : theme.colorScheme.secondary,
            size: 27,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _hasSmsPermission
                      ? 'SMS capture permission enabled'
                      : 'Enable bank SMS capture',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Text(
                  _hasSmsPermission
                      ? 'New SMS messages are filtered locally for likely bank transaction alerts. The original message is not stored.'
                      : 'Requests RECEIVE_SMS only, not READ_SMS. Android may block this restricted permission for an APK installed outside an approved distribution path.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _hasSmsPermission
                      ? _refresh
                      : _requestSmsPermission,
                  icon: Icon(
                    _hasSmsPermission
                        ? Icons.refresh_rounded
                        : Icons.sms_rounded,
                  ),
                  label: Text(
                    _hasSmsPermission
                        ? 'Check permission'
                        : 'Request SMS permission',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmsEventCard(
    ThemeData theme,
    bool isDark,
    Map<String, dynamic> event,
  ) {
    final amount = (event['amount'] as num?)?.toDouble() ?? 0;
    final direction = event['direction']?.toString() ?? 'unknown';
    final merchant = event['merchant']?.toString() ?? '';
    final reference = event['reference']?.toString() ?? '';
    final accountHint = event['accountHint']?.toString() ?? '';
    final postedAt = (event['postedAt'] as num?)?.toInt() ?? 0;
    final date = postedAt > 0
        ? DateTime.fromMillisecondsSinceEpoch(postedAt)
        : DateTime.now();
    final directionLabel = switch (direction) {
      'debit' => 'Likely money spent',
      'credit' => 'Likely money received',
      _ => 'Direction unclear — review carefully',
    };
    final directionColor = direction == 'debit'
        ? AppColors.expense
        : direction == 'credit'
        ? AppColors.income
        : theme.colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: const Icon(Icons.sms_outlined, color: AppColors.primary),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bank SMS',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      DateFormat('dd MMM yyyy, hh:mm a').format(date),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                amount > 0 ? '₹${amount.toStringAsFixed(2)}' : 'Amount unknown',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: directionColor,
                ),
              ),
            ],
          ),
          if (merchant.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Possible merchant: $merchant'),
          ],
          if (reference.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Reference: $reference', style: theme.textTheme.bodySmall),
          ],
          if (accountHint.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Account: $accountHint', style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 8),
          Text(
            directionLabel,
            style: TextStyle(
              color: directionColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Original SMS text was not stored.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(
    ThemeData theme,
    bool isDark,
    Map<String, dynamic> event,
  ) {
    final amount = (event['amount'] as num?)?.toDouble() ?? 0;
    final direction = event['direction']?.toString() ?? 'unknown';
    final merchant = event['merchant']?.toString() ?? '';
    final appName = event['appName']?.toString() ?? 'Payment app';
    final title = event['title']?.toString() ?? '';
    final text = event['text']?.toString() ?? '';
    final postedAt = (event['postedAt'] as num?)?.toInt() ?? 0;
    final date = postedAt > 0
        ? DateTime.fromMillisecondsSinceEpoch(postedAt)
        : DateTime.now();
    final directionLabel = switch (direction) {
      'debit' => 'Money spent',
      'credit' => 'Money received',
      _ => 'Direction unclear',
    };
    final directionColor = direction == 'debit'
        ? AppColors.expense
        : direction == 'credit'
        ? AppColors.income
        : theme.colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appName,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (title.isNotEmpty)
                      Text(title, style: theme.textTheme.bodySmall),
                    Text(
                      DateFormat('dd MMM yyyy, hh:mm a').format(date),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                amount > 0 ? '₹${amount.toStringAsFixed(2)}' : 'Amount unknown',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: directionColor,
                ),
              ),
            ],
          ),
          if (merchant.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Merchant: $merchant'),
          ],
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.55,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              text.isEmpty ? 'No notification text available.' : text,
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            directionLabel,
            style: TextStyle(
              color: directionColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String body,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Text(body, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
