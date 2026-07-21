/// Fetches the current user's ID-token claims (forcing a refresh).
typedef ClaimsFetcher = Future<Map<String, dynamic>> Function();

/// Polls [fetchClaims] until [expectedTeamId] appears in the `teams` claim
/// (set by the membership callables) or [maxAttempts] is reached. Returns
/// true if the claim arrived.
///
/// The callable sets the claim before returning, so the first refresh
/// normally already has it — the bounded poll is a cheap safety net against
/// token-refresh lag. [sleep] is injectable for tests.
Future<bool> waitForTeamClaim({
  required ClaimsFetcher fetchClaims,
  required String expectedTeamId,
  int maxAttempts = 6,
  Duration delay = const Duration(milliseconds: 500),
  Future<void> Function(Duration)? sleep,
}) async {
  final wait = sleep ?? Future<void>.delayed;
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    final claims = await fetchClaims();
    final teams = (claims['teams'] as Map?) ?? const {};
    if (teams.containsKey(expectedTeamId)) return true;
    if (attempt < maxAttempts - 1) await wait(delay);
  }
  return false;
}
