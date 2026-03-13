enum UserContext {
  field,
  office,
}

extension UserContextX on UserContext {
  static UserContext fromSlug(String slug) {
    if (slug == 'foreman' || slug == 'worker') {
      return UserContext.field;
    }

    return UserContext.office;
  }

  static UserContext fromRoles(Iterable<String> roles) {
    for (final role in roles) {
      if (fromSlug(role) == UserContext.field) {
        return UserContext.field;
      }
    }

    return UserContext.office;
  }
}
