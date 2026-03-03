// user_context.dart
enum UserContext {
  field,   // Работает на объекте (прораб, рабочий). Фокус на скан QR, заявки, факты
  office,  // Руководитель, наблюдатель. Фокус на статистику, отчеты, контроль
}

extension UserContextX on UserContext {
  static UserContext fromSlug(String slug) {
    // В поле работают только прорабы и рабочие (базовые роли)
    if (slug == 'foreman' || slug == 'worker') {
      return UserContext.field;
    }
    // Все остальные роли (owner, admin, manager, observer, custom etc)
    // считаем управляющими/наблюдающими (office)
    return UserContext.office;
  }
}
