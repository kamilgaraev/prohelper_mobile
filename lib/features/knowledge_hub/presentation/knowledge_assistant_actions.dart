import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_destination.dart';
import 'package:prohelpers_mobile/core/providers/module_provider.dart';
import 'package:prohelpers_mobile/features/actions/presentation/mobile_action_search.dart';
import '../data/knowledge_assistant_repository.dart';

final knowledgeAssistantDestinationsProvider =
    Provider<List<MobileModuleDestination>>((ref) {
      return visibleMobileDestinations(
        ref.watch(supportedMobileModulesProvider),
      );
    });

class KnowledgeAssistantActions extends ConsumerWidget {
  const KnowledgeAssistantActions({super.key, required this.answer});

  final KnowledgeAssistantAnswer answer;

  static const _routes = {
    'site-requests-overview': 'site_requests',
    'create-site-request': 'site_requests',
    'mobile-foreman-workflow': 'site_requests',
    'materials-from-request-to-receipt': 'warehouse',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!answer.answered || answer.needsClarification) {
      return const SizedBox.shrink();
    }
    final routes =
        answer.sources
            .map((source) => _routes[source.slug])
            .whereType<String>()
            .toSet();
    if (routes.isEmpty) {
      return const SizedBox.shrink();
    }
    final available = ref.watch(knowledgeAssistantDestinationsProvider);
    final destinations = <String, MobileModuleDestination>{};
    for (final destination in available) {
      if (routes.contains(destination.route)) {
        destinations[destination.route] = destination;
      }
    }
    if (destinations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final destination in destinations.values)
            OutlinedButton.icon(
              onPressed:
                  () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute<void>(builder: destination.builder)),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(
                destination.route == 'warehouse'
                    ? 'Открыть склад'
                    : 'Открыть заявки',
              ),
            ),
        ],
      ),
    );
  }
}
