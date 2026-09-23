# Настройка RuStore Push в мобильном приложении МОСТ

Android получает push-токен через RuStore Push SDK. Секреты отправки хранятся только на backend.

1. Скопируйте `.env.example` в `.env` либо задайте `RUSTORE_PROJECT_ID` как process environment variable.
2. Проектный ID публичен и передаётся Gradle как Android manifest placeholder. Не добавляйте в приложение service credentials.
3. Package name приложения: `ru.prohelper.prohelpers_mobile`. В RuStore Push проекте должны совпадать package name и fingerprint сертификата подписи сборки.
4. Release-сборка требует непустой `RUSTORE_PROJECT_ID` из `.env` или process environment. Debug-сборка работает без ID.
5. Устройство должно иметь RuStore или доступный RuStore distributor. Android 13+ запрашивает системное разрешение уведомлений. После включения разрешения в Android Settings приложение повторно регистрирует push при возврате.

Клиент передаёт `installation_id`, `platform=android`, `provider=rustore` и `token` в `POST /api/v1/mobile/notifications/devices`. При logout клиент удаляет регистрацию устройства и передаёт `installation_id` в `/auth/logout` как серверный резервный шаг.

После выбора доступной организации и объекта нажатие открывает запись прямо для известных `target_type`: заявки, записи журнала, графика работ и складской задачи. Перед переходом приложение проверяет доступ к записи через API. Если payload неполный, тип неизвестен, запись недоступна или запрос завершился ошибкой, открывается уведомление по `notification_id`, а без него — inbox. Если выбор объекта ещё загружается или ожидает действия пользователя, push остаётся ожидающим.

Foreground push обновляет inbox и счётчик непрочитанных уведомлений.
