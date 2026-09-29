import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/error/user_message.dart';
import '../../auth/domain/auth_provider.dart';
import '../data/ai_assistant_models.dart';
import '../data/ai_assistant_repository.dart';

class AiAssistantCreditsScreen extends ConsumerStatefulWidget {
  const AiAssistantCreditsScreen({super.key});
  @override
  ConsumerState<AiAssistantCreditsScreen> createState() => _CreditsState();
}

class _CreditsState extends ConsumerState<AiAssistantCreditsScreen> {
  AiCreditsBalanceModel? _balance;
  String? _error;
  int _sessionRevision = 0;
  bool _purchasing = false;
  bool _historyLoading = false;
  List<Map<String, dynamic>> _history = [];
  int? _nextHistory = 1;
  @override
  void initState() {
    super.initState();
    ref.listenManual(
      authProvider.select(
        (state) => (state.user?.serverId, state.user?.currentOrganizationId),
      ),
      (previous, next) {
        if (previous != next) {
          _sessionRevision++;
          if (mounted) Navigator.maybePop(context);
        }
      },
    );
    _load();
  }

  Future<void> _load() async {
    final revision = _sessionRevision;
    try {
      final balance =
          await ref.read(aiAssistantRepositoryProvider).fetchCreditsBalance();
      if (mounted && revision == _sessionRevision) {
        setState(() {
          _balance = balance;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted && revision == _sessionRevision) {
        setState(() => _error = UserMessage.fromError(error));
      }
    }
  }

  Future<void> _loadHistory() async {
    if (_historyLoading || _nextHistory == null) return;
    final revision = _sessionRevision;
    setState(() => _historyLoading = true);
    try {
      final page = await ref
          .read(aiAssistantRepositoryProvider)
          .fetchCreditHistory(page: _nextHistory!);
      if (!mounted || revision != _sessionRevision) return;
      setState(() {
        _history = [..._history, ...page.items];
        _nextHistory = page.nextPage;
      });
    } catch (error) {
      if (mounted && revision == _sessionRevision) {
        setState(() => _error = UserMessage.fromError(error));
      }
    } finally {
      if (mounted && revision == _sessionRevision) {
        setState(() => _historyLoading = false);
      }
    }
  }

  Future<void> _purchase(String pack) async {
    if (_balance?.billingMode == 'shadow' ||
        _balance?.chargingEnabled != true ||
        _balance?.canPurchase != true ||
        _balance?.packPurchaseEnabled != true) {
      return;
    }
    final revision = _sessionRevision;
    setState(() => _purchasing = true);
    try {
      final url = await ref
          .read(aiAssistantRepositoryProvider)
          .purchaseCredits(packId: pack);
      if (!mounted || revision != _sessionRevision) return;
      final uri = Uri.tryParse(url ?? '');
      if (uri == null ||
          uri.scheme != 'https' ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Не удалось открыть страницу оплаты.');
      }
    } catch (error) {
      if (mounted) setState(() => _error = UserMessage.fromError(error));
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Баланс помощника')),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_balance == null && _error == null)
            const Center(child: CircularProgressIndicator()),
          if (_balance != null) ...[
            Text(
              'Доступно: ${_balance!.available} ${_balance!.unit}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text('Включено в период: ${_balance!.base}'),
            Text('Куплено: ${_balance!.purchased}'),
            Text('Зарезервировано: ${_balance!.reserved}'),
            const SizedBox(height: 20),
            Text(
              _balance!.billingMode == 'shadow'
                  ? 'Тестовый режим: списания выключены. Показана оценка расхода, фактическое списание — 0.'
                  : !_balance!.chargingEnabled
                  ? 'Списания пока не включены.'
                  : 'Купленные единицы бессрочные. Оплата доступна пользователям с правом управления оплатой.',
            ),
            const SizedBox(height: 16),
            ..._history.map(
              (entry) => ListTile(
                title: Text(switch (entry['operation'] ?? entry['type']) {
                  'charge' => 'Списание',
                  'reserve' => 'Резерв',
                  'release' => 'Освобождение резерва',
                  'grant' => 'Начисление',
                  _ => 'Операция помощника',
                }),
                subtitle: Text(entry['created_at']?.toString() ?? ''),
                trailing: Text(
                  '${formatAiMinor(int.tryParse(entry['amount_minor']?.toString() ?? '') ?? 0)} ед.',
                ),
              ),
            ),
            if (_nextHistory != null)
              TextButton(
                onPressed: _historyLoading ? null : _loadHistory,
                child: const Text('Журнал операций'),
              ),
            if (_balance!.basePeriodExpiresAt != null)
              Text(
                'Включённые единицы действуют до ${_balance!.basePeriodExpiresAt!.toLocal().toString().split(' ').first}',
              ),
            if (_balance!.canPurchase &&
                _balance!.packPurchaseEnabled &&
                _balance!.chargingEnabled &&
                _balance!.billingMode != 'shadow')
              for (final pack in _balance!.packs)
                OutlinedButton(
                  onPressed: _purchasing ? null : () => _purchase(pack.id),
                  child: Text(
                    '${formatAiMinor(pack.unitsMinor)} единиц за ${formatAiMinor(pack.amountMinor)} ₽',
                  ),
                ),
          ],
        ],
      ),
    ),
  );
}
