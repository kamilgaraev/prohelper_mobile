import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/construction_journal/data/construction_journal_models.dart';
import 'package:prohelpers_mobile/features/construction_journal/data/construction_journal_repository.dart';
import 'package:prohelpers_mobile/features/construction_journal/domain/construction_journal_provider.dart';

class _FakeConstructionJournalRepository extends ConstructionJournalRepository {
  _FakeConstructionJournalRepository({this.error}) : super(Dio());

  final Object? error;

  @override
  Future<ConstructionJournalListPayload> fetchJournals({
    required int projectId,
    int page = 1,
    int perPage = 20,
  }) async {
    final failure = error;
    if (failure != null) {
      throw failure;
    }

    return const ConstructionJournalListPayload(
      items: [],
      meta: JournalPaginationMeta(
        currentPage: 1,
        perPage: 20,
        lastPage: 1,
        total: 0,
      ),
      summary: ConstructionJournalSummary(
        totalJournals: 0,
        activeJournals: 0,
        archivedJournals: 0,
        closedJournals: 0,
      ),
      availableActions: [
        ConstructionJournalActionModel(
          action: ConstructionJournalActionKeys.create,
          label: 'Создать журнал',
        ),
      ],
      project: ConstructionJournalProjectRef(id: 15, name: 'Дом 300м Царево'),
    );
  }
}

void main() {
  test('marks journal list as permission denied on 403', () async {
    final notifier = ConstructionJournalNotifier(
      _FakeConstructionJournalRepository(
        error: const ApiException('Недостаточно прав', statusCode: 403),
      ),
    );

    await notifier.load(projectId: 15);

    expect(notifier.state.permissionDenied, isTrue);
    expect(notifier.state.error, 'Недостаточно прав');
  });

  test('normalizes malformed journal contract error', () async {
    final notifier = ConstructionJournalNotifier(
      _FakeConstructionJournalRepository(
        error: const FormatException('available_actions'),
      ),
    );

    await notifier.load(projectId: 15);

    expect(notifier.state.permissionDenied, isFalse);
    expect(
      notifier.state.error,
      'Данные журнала работ пришли неполными. Обновите экран и повторите попытку.',
    );
  });
}
