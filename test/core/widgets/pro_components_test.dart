import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/design/pro_status.dart';
import 'package:prohelpers_mobile/core/theme/pro_theme.dart';
import 'package:prohelpers_mobile/core/widgets/pro_action_tile.dart';
import 'package:prohelpers_mobile/core/widgets/pro_bottom_sheet.dart';
import 'package:prohelpers_mobile/core/widgets/pro_metric_tile.dart';
import 'package:prohelpers_mobile/core/widgets/pro_page_scaffold.dart';
import 'package:prohelpers_mobile/core/widgets/pro_search_filter_bar.dart';
import 'package:prohelpers_mobile/core/widgets/pro_section.dart';
import 'package:prohelpers_mobile/core/widgets/pro_status_banner.dart';
import 'package:prohelpers_mobile/core/widgets/pro_surface.dart';

void main() {
  testWidgets('pro components render under light theme', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ProHelperTheme.lightTheme,
        home: ProPageScaffold(
          title: 'Сегодня на объекте',
          subtitle: 'Дом 300м Царево',
          body: Column(
            children: [
              const ProStatusBanner(
                title: 'Требует внимания',
                description: 'Есть задачи, которые ждут решения.',
                tone: ProStatusTone.warning,
              ),
              const SizedBox(height: 12),
              const ProMetricTile(
                label: 'Открыто',
                value: '4',
                icon: Icons.assignment_outlined,
              ),
              const SizedBox(height: 12),
              ProActionTile(
                title: 'Создать заявку',
                subtitle: 'Передать задачу снабжению или исполнителю',
                icon: Icons.add_task_rounded,
                onTap: () {},
              ),
              const SizedBox(height: 12),
              ProSearchFilterBar<String>(
                controller: controller,
                hintText: 'Найти',
                options: const [
                  ProFilterOption(value: 'all', label: 'Все'),
                  ProFilterOption(value: 'urgent', label: 'Срочные'),
                ],
                selectedValue: 'all',
                onFilterChanged: (_) {},
                resultLabel: 'Найдено: 2',
              ),
              const SizedBox(height: 12),
              const ProSectionHeader(
                title: 'Рабочая сводка',
                subtitle: 'Коротко по ключевым зонам',
              ),
              const ProSurface(child: Text('Поверхность')),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Сегодня на объекте'), findsOneWidget);
    expect(find.text('Требует внимания'), findsOneWidget);
    expect(find.text('Создать заявку'), findsOneWidget);
    expect(find.text('Найти'), findsOneWidget);
    expect(find.text('Рабочая сводка'), findsOneWidget);
  });

  testWidgets('pro bottom sheet renders title content and actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ProHelperTheme.darkTheme,
        home: Scaffold(
          body: ProBottomSheet(
            title: 'Новое замечание',
            description: 'Заполните основные поля.',
            actions: [
              FilledButton(onPressed: () {}, child: const Text('Создать')),
            ],
            child: const Text('Форма'),
          ),
        ),
      ),
    );

    expect(find.text('Новое замечание'), findsOneWidget);
    expect(find.text('Форма'), findsOneWidget);
    expect(find.text('Создать'), findsOneWidget);
  });
}
