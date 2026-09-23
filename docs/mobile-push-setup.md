# Настройка RuStore Push в мобильном приложении МОСТ

Android получает push-токен через RuStore Push SDK. Секреты отправки хранятся только на backend.

1. Скопируйте `.env.example` в `.env` либо задайте `RUSTORE_PROJECT_ID` в этом файле.
2. Проектный ID публичен и передаётся Gradle как Android manifest placeholder. Не добавляйте в приложение service credentials.
3. Package name приложения: `ru.prohelper.prohelpers_mobile`. В RuStore Push проекте должны совпадать package name и fingerprint сертификата подписи сборки.
4. Устройство должно иметь RuStore или доступный RuStore distributor. Android 13+ запрашивает системное разрешение уведомлений.

Клиент передаёт `installation_id`, `platform=android`, `provider=rustore` и `token` в `POST /api/v1/mobile/notifications/devices`. При logout клиент удаляет регистрацию устройства и передаёт `installation_id` в `/auth/logout` как серверный резервный шаг.

Tap по notification открывает её detail screen, если payload содержит `notification_id`; иначе открывается inbox. Foreground push обновляет inbox и счётчик непрочитанных уведомлений.
