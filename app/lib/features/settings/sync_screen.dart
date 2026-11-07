import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timetrack_core/timetrack_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/format.dart';
import '../../sync/sync_controller.dart';

/// Connects to Nextcloud (Login Flow v2 or app password) and shows the sync
/// status (sync-format.md §7, §10).
class SyncScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  final _server = TextEditingController(text: 'https://');
  final _login = TextEditingController();
  final _appPassword = TextEditingController();
  final _proxy = TextEditingController();
  bool _manual = false;
  bool _busy = false;
  String? _message;
  bool _cancelled = false;
  final _resumed = StreamController<void>.broadcast();
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Coming back from the browser triggers an immediate login poll.
    _lifecycle = AppLifecycleListener(onResume: () => _resumed.add(null));
  }

  @override
  void dispose() {
    _cancelled = true;
    _lifecycle.dispose();
    unawaited(_resumed.close());
    for (final c in [_server, _login, _appPassword, _proxy]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _connect() async {
    final l = context.l10n;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final server = Uri.parse(_server.text.trim());
      final NextcloudCredentials creds;
      if (_manual) {
        creds = NextcloudCredentials(
          server: server,
          loginName: _login.text.trim(),
          appPassword: _appPassword.text.trim(),
        );
      } else {
        final flow = await LoginFlow.start(
          server,
          client: ref.read(httpClientFactoryProvider)(_proxy.text),
        );
        // Android: an in-app browser tab (closing it returns to TimeTrack).
        // Desktop: the default browser.
        await launchUrl(
          flow.loginUrl,
          mode: Platform.isAndroid
              ? LaunchMode.inAppBrowserView
              : LaunchMode.externalApplication,
        );
        setState(() => _message = l.syncWaitingForLogin);
        final got = await flow.waitForApproval(
          wakeUp: _resumed.stream,
          cancelled: () => _cancelled,
        );
        if (got == null) throw TimeoutException(l.syncLoginTimeout);
        creds = got;
      }
      final remote = WebDavRemoteFolder(
        root: creds.webDavRoot(),
        username: creds.loginName,
        appPassword: creds.appPassword,
        client: ref.read(httpClientFactoryProvider)(_proxy.text),
      );
      final joining = await remote.read('format.json') != null;
      if (!mounted) return;
      final passphrase = await _askPassphrase(confirm: !joining);
      if (passphrase == null) return;
      setState(() => _message = l.syncDerivingKey);
      final cipher = await connectSyncFolder(remote, passphrase);
      await ref
          .read(syncControllerProvider.notifier)
          .connect(
            SyncConfig(
              root: creds.webDavRoot(),
              loginName: creds.loginName,
              appPassword: creds.appPassword,
              keyBytes: await cipher.key.extractBytes(),
              proxy: _proxy.text.trim(),
            ),
          );
      if (mounted) setState(() => _message = null);
    } on SyncCryptoException {
      if (mounted) setState(() => _message = l.syncWrongPassphrase);
    } on Object catch (e) {
      if (mounted) setState(() => _message = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Asks for the sync passphrase; twice when creating a new sync folder.
  Future<String?> _askPassphrase({required bool confirm}) {
    final first = TextEditingController();
    final second = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (c) {
        String? error;
        return StatefulBuilder(
          builder: (c, setState) => AlertDialog(
            title: Text(c.l10n.syncPassphrase),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  confirm
                      ? c.l10n.syncPassphraseNew
                      : c.l10n.syncPassphraseJoin,
                ),
                TextField(
                  controller: first,
                  obscureText: true,
                  autofocus: true,
                ),
                if (confirm)
                  TextField(
                    controller: second,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: c.l10n.syncPassphraseRepeat,
                    ),
                  ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(color: Theme.of(c).colorScheme.error),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: Text(c.l10n.cancel),
              ),
              FilledButton(
                onPressed: () {
                  if (first.text.length < 8) {
                    setState(() => error = c.l10n.syncPassphraseShort);
                  } else if (confirm && first.text != second.text) {
                    setState(() => error = c.l10n.syncPassphraseMismatch);
                  } else {
                    Navigator.pop(c, first.text);
                  }
                },
                child: Text(c.l10n.save),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final status = ref.watch(syncControllerProvider);
    final controller = ref.read(syncControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(l.sync)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (status.phase != SyncPhase.notConfigured) ...[
            Card(
              child: ListTile(
                leading: Icon(switch (status.phase) {
                  SyncPhase.syncing => Icons.sync,
                  SyncPhase.error => Icons.sync_problem,
                  _ => Icons.cloud_done_outlined,
                }),
                title: Text('${status.root?.host}'),
                subtitle: Text(
                  [
                    if (status.lastSuccess != null)
                      l.syncLastSuccess(
                        TimeOfDay.fromDateTime(status.lastSuccess!)
                            .format(context),
                      ),
                    if (status.phase == SyncPhase.error) '${status.error}',
                  ].join('\n'),
                ),
                trailing: IconButton(
                  tooltip: l.syncNow,
                  icon: const Icon(Icons.refresh),
                  onPressed: status.phase == SyncPhase.syncing
                      ? null
                      : controller.syncNow,
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: controller.disconnect,
              icon: const Icon(Icons.link_off),
              label: Text(l.syncDisconnect),
            ),
          ] else ...[
            Text(l.syncIntro),
            const SizedBox(height: 16),
            TextField(
              controller: _server,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: l.syncServer,
                hintText: 'https://cloud.example.com',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.syncManual),
              value: _manual,
              onChanged: (v) => setState(() => _manual = v),
            ),
            if (_manual) ...[
              TextField(
                controller: _login,
                decoration: InputDecoration(labelText: l.syncLoginName),
              ),
              TextField(
                controller: _appPassword,
                obscureText: true,
                decoration: InputDecoration(labelText: l.syncAppPassword),
              ),
            ],
            TextField(
              controller: _proxy,
              decoration: InputDecoration(
                labelText: l.syncProxy,
                hintText: 'proxy.example.com:8080',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _connect,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: Text(l.syncConnect),
            ),
          ],
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_message!),
            ),
        ],
      ),
    );
  }
}
