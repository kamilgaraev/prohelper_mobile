# МОСТ Mobile Continuation Prompt

Скопируй этот промпт в новый чат Codex.

```text
Ты работаешь в C:\Users\kamilgaraev\Desktop\prohelper_full.

Цель: довести Flutter-мобильное приложение МОСТ (`prohelpers_mobile`) до уровня 10/10 по UI/UX и функциональной надежности: строгий B2B-интерфейс для строительных/производственных операций, чистая светлая тема, плотная но читаемая иерархия карточек, без визуального "полотна", без лишних runtime-ошибок в нормальном пользовательском сценарии.

Обязательные инструкции:
- Отвечай на русском.
- Используй Superpowers. Сначала прочитай и применяй `superpowers:using-superpowers`, затем для продолжения текущего плана используй `superpowers:executing-plans`; для новых крупных задач используй `superpowers:writing-plans`; для багов используй `superpowers:systematic-debugging`; перед завершением используй `superpowers:verification-before-completion`.
- Используй project skill `prohelper-mobile-patterns` для всех правок Flutter/Dart.
- Если затрагиваешь API-контракты mobile/backend, используй `prohelper-api-contracts`; если меняешь Laravel backend, используй `prohelper-backend-standards`.
- По AGENTS.md используй Context7 почти всегда, когда есть риск устаревшей информации о Flutter, Dart, Android, Laravel, пакетах, SDK или API.
- Не запускай миграции, local DB/artisan/tinker и команды, открывающие локальную БД. Backend PHPUnit не запускать без явного разрешения пользователя, если он открывает БД.
- Не сохраняй пароль тестового аккаунта в файлы/репозиторий. Если нужна авторизация в эмуляторе, используй уже открытую сессию или попроси пользователя войти/дать данные заново.
- Работай через TDD для исправлений: сначала воспроизвести/доказать дефект, затем узкий failing test, затем правка, затем targeted tests, analyzer, full suite, emulator smoke.
- Не считай цель завершенной, пока нет финального emulator-аудита: login/session, Overview, Work, Actions, More, Notifications, Knowledge Hub, Project selection, Workflow list/detail, один складской/полевой сценарий, плюс отсутствие критичных runtime-ошибок.

Текущее состояние:
- Главный Superpowers-план: `prohelpers_mobile/docs/superpowers/plans/2026-07-02-mobile-ux-hardening.md`.
- Последний внесенный шаг: Task 5AN, Knowledge Hub search accessibility boundaries.
- На момент handoff мобильная проверка прошла:
  - `flutter analyze`: No issues found
  - `flutter test --reporter compact`: 414 tests passed
  - `flutter build apk --debug`: success
  - `adb install -r build\app\outputs\flutter-apk\app-debug.apk`: Success
  - Emulator smoke: `Ещё -> База знаний` показывает отдельный EditText и отдельную кнопку `Искать по базе знаний`.
- Важное: ранее пользователь уточнил, что проблема не в тексте ошибки, а в самой ошибке. Поэтому если видишь карточки вроде `Сводка недоступна`, `Не удалось обновить состояние объекта`, `Не удалось выполнить вход`, не ограничивайся копирайтом: найди источник сбоя в цепочке mobile -> API -> backend и убери нормальный сценарий появления ошибки.

Что уже сделано крупно:
- Починен dashboard/Overview resilience: backend `/mobile/dashboard` больше не должен падать целиком из-за одного widget; mobile сохраняет last good dashboard data при refresh failure; Overview не показывает старую большую карточку `Не удалось обновить состояние объекта` в штатном сценарии.
- Починен Android startup splash: брендированная native-заставка, Android 12+ splash resources, no extra exit animation.
- Укреплены login/profile auth, светлая тема, bottom navigation, Overview project/notification/work-summary cards, search/filter surfaces, workflow actions, notifications, project selection, warehouse/task accessibility, Knowledge Hub search semantics.
- Исправлены русская локализация date picker, формат сумм `ru_RU`, mojibake guards и user-facing error sanitization.
- Много runtime evidence лежит в `prohelpers_mobile/build/qa/*.png` и `*.xml`.

Что делать дальше:
1. Открой и прочитай `prohelpers_mobile/docs/superpowers/plans/2026-07-02-mobile-ux-hardening.md`, особенно `Execution Status`, Task 5AL-5AN и критерии completion audit.
2. Проверь фактическое состояние git отдельно:
   - `git -C prohelpers_mobile status --short`
   - `git -C prohelper status --short`
   Корневой `prohelper_full` не является git-репозиторием.
3. Не трогай unrelated backend EstimateGeneration изменения в `prohelper`, если задача не требует: они были в dirty tree до handoff.
4. Сделай свежий emulator-аудит ключевого пользовательского пути. Ищи не только UI-косметику, а реальные сбои: ошибочные карточки, пустые состояния при наличии данных, NAF/unlabeled controls, merged accessibility nodes, перекрытия, низкий контраст, неработающие actions.
5. Следующий дефект выбирай по приоритету:
   - runtime error в нормальном сценарии;
   - блокирующий UX/action defect;
   - доступность/семантика, из-за которой Android видит неправильные controls;
   - визуальная иерархия светлой темы.
6. Для каждого исправления:
   - воспроизведи на emulator или через точный unit/widget evidence;
   - добавь узкий regression test;
   - внеси минимальную правку в существующем стиле проекта;
   - прогони targeted tests;
   - прогони `C:\flutter\bin\flutter.bat analyze`;
   - прогони `C:\flutter\bin\flutter.bat test --reporter compact`;
   - если менял backend PHP, прогони `php -l` и PHPStan по затронутым файлам;
   - собери/установи debug APK и проверь affected screen на emulator;
   - обнови `prohelpers_mobile/docs/superpowers/plans/2026-07-02-mobile-ux-hardening.md` новым Task 5AO/5AP/etc. с evidence.

Команды, которые уже хорошо работали:
- `C:\flutter\bin\flutter.bat analyze`
- `C:\flutter\bin\flutter.bat test --reporter compact`
- `C:\flutter\bin\flutter.bat build apk --debug`
- `adb install -r build\app\outputs\flutter-apk\app-debug.apk`
- `adb shell uiautomator dump /sdcard/window.xml`
- `adb pull /sdcard/window.xml build\qa\<name>.xml`
- `adb shell screencap -p /sdcard/<name>.png`
- `adb pull /sdcard/<name>.png build\qa\<name>.png`

Не завершай цель "10/10", пока не проведен финальный строгий audit и не осталось известных severe runtime/UI/UX дефектов.
```
