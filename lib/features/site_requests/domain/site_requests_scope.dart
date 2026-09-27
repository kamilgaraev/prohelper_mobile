enum SiteRequestsScope {
  all('all'),
  own('own'),
  approvals('approvals');

  const SiteRequestsScope(this.value);

  final String value;
}
