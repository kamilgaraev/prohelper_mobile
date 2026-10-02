import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/ai_assistant/data/ai_assistant_models.dart';
import 'package:prohelpers_mobile/features/ai_assistant/data/ai_assistant_repository.dart';
import 'package:prohelpers_mobile/features/ai_assistant/domain/ai_assistant_provider.dart';

const usage = AiUsageModel(
  monthlyLimit: 5000,
  used: 0,
  remaining: 5000,
  percentageUsed: 0,
);
AiConversationModel conversation(int id) => AiConversationModel(
  id: id,
  title: 'Chat $id',
  createdAt: null,
  updatedAt: null,
);
void main() {
  test('older refresh cannot replace newer conversations', () async {
    final repository = _Repository();
    final notifier = AiAssistantHomeNotifier(repository);
    final refresh = notifier.load();
    repository.loads[1].complete(
      AiAssistantHomeModel(usage: usage, conversations: [conversation(2)]),
    );
    await refresh;
    repository.loads[0].complete(
      AiAssistantHomeModel(usage: usage, conversations: [conversation(1)]),
    );
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.home!.conversations.single.id, 2);
    notifier.dispose();
  });
  test(
    'next conversation page preserves previous rows and removes duplicates',
    () async {
      final repository = _Repository();
      final notifier = AiAssistantHomeNotifier(repository);
      repository.loads[0].complete(
        AiAssistantHomeModel(
          usage: usage,
          conversations: [conversation(1)],
          nextPage: 2,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await notifier.loadMore();
      expect(repository.requestedPage, 2);
      expect(notifier.state.home!.conversations.map((row) => row.id), [1, 2]);
      expect(notifier.state.home!.nextPage, isNull);
      notifier.dispose();
    },
  );
}

class _Repository extends AiAssistantRepository {
  _Repository() : super(Dio());
  final loads = <Completer<AiAssistantHomeModel>>[];
  int? requestedPage;
  @override
  Future<AiAssistantHomeModel> fetchHome() {
    final load = Completer<AiAssistantHomeModel>();
    loads.add(load);
    return load.future;
  }

  @override
  Future<AiAssistantPage<AiConversationModel>> fetchConversations({
    int page = 1,
  }) async {
    requestedPage = page;
    return AiAssistantPage(items: [conversation(1), conversation(2)]);
  }
}
