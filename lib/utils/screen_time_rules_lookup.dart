
Map<String, dynamic>? resolveChildRuleEntry({
  required Map<String, dynamic>? childrenData,
  required String parentUid,
  required String childId,
  required String displayName,
}) {
  if (childrenData == null || childrenData.isEmpty) return null;

  final byId = _asStringKeyedMap(childrenData[childId]);
  if (byId != null) return byId;

  if (displayName.isEmpty) return null;

  final byName = _asStringKeyedMap(childrenData[displayName]);
  if (byName != null) {
    _logFallbackResolved(
      parentUid: parentUid,
      childId: childId,
      displayName: displayName,
    );
    return byName;
  }

  return null;
}


void _logFallbackResolved({
  required String parentUid,
  required String childId,
  required String displayName,
}) {
  print(
    'ScreenTimeRulesLookup: resolved children[displayName] fallback '
    '(children[childId] entry not found yet) — parentUid: $parentUid, '
    'childId: $childId, displayName: $displayName',
  );
}

Map<String, dynamic>? _asStringKeyedMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    try {
      return Map<String, dynamic>.from(value);
    } catch (_) {
      return null;
    }
  }
  return null;
}
