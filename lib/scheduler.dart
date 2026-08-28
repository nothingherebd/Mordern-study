/// The spaced-repetition engine.
///
/// Every topic climbs a ladder of intervals (in days), fully configurable
/// from Settings. When a topic is reviewed it moves to the next rung; the
/// gap between reviews grows, matching how memory consolidation works
/// scientifically (short gaps early, long gaps once it has stuck).
///
/// A topic's "urgency" is how overdue it is *relative to its own current
/// interval* — a topic that's 2 days late on a 1-day rung is far more
/// urgent than one that's 2 days late on a 365-day rung. That's what makes
/// the priority queue on the Study home page keep resurfacing the things
/// you're actually forgetting, instead of just the oldest ones.
class Scheduler {
  static List<int> intervals(Map config) => (config['intervals'] as List).cast<int>();

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _addDays(DateTime d, int days) => _dateOnly(d).add(Duration(days: days));

  /// First due date for a brand-new topic — the first rung of the ladder.
  static DateTime computeInitialDue(DateTime createdAt, Map config) {
    final ivs = intervals(config);
    final first = ivs.isNotEmpty ? ivs.first : 1;
    return _addDays(createdAt, first);
  }

  /// Call when the user marks a topic as reviewed. Advances it one rung
  /// (capped at the last rung, so it keeps repeating at the longest
  /// interval once fully learned) and recomputes the next due date.
  static Map applyReview(Map topic, Map config) {
    final ivs = intervals(config);
    int stage = (topic['stage'] ?? -1) as int;
    stage = (stage + 1).clamp(0, ivs.isEmpty ? 0 : ivs.length - 1);
    final now = DateTime.now();
    final updated = Map.from(topic);
    updated['stage'] = stage;
    updated['lastReviewedAt'] = now.toIso8601String();
    updated['totalReviews'] = ((topic['totalReviews'] ?? 0) as int) + 1;
    updated['nextDueAt'] = _addDays(now, ivs.isEmpty ? 1 : ivs[stage]).toIso8601String();
    return updated;
  }

  /// How urgent a topic is, normalized by its own current interval so
  /// short-interval and long-interval topics compete fairly for priority.
  static double urgency(Map topic) {
    final due = DateTime.tryParse(topic['nextDueAt']?.toString() ?? '');
    if (due == null) return 0;
    final overdueDays = _dateOnly(DateTime.now()).difference(_dateOnly(due)).inDays;
    final stage = ((topic['stage'] ?? 0) as int).clamp(0, 1000);
    final normalized = overdueDays / (stage + 1);
    final manual = ((topic['manualPriority'] ?? 3) as int) * 0.15;
    return normalized + manual;
  }

  static bool isDue(Map topic) {
    final due = DateTime.tryParse(topic['nextDueAt']?.toString() ?? '');
    if (due == null) return false;
    return !_dateOnly(due).isAfter(_dateOnly(DateTime.now()));
  }

  static bool isRevisionDayToday(Map config) {
    final weekday = (config['revisionWeekday'] ?? DateTime.friday) as int;
    return DateTime.now().weekday == weekday;
  }

  /// On the weekly revision day, pull in anything touched within the
  /// configured window too — a "catch everything from this stretch" sweep,
  /// on top of whatever is individually due.
  static bool inRevisionWindow(Map topic, Map config) {
    final windowDays = (config['revisionWindowDays'] ?? 6) as int;
    final created = DateTime.tryParse(topic['createdAt']?.toString() ?? '');
    final lastRev = DateTime.tryParse(topic['lastReviewedAt']?.toString() ?? '');
    final anchor = lastRev ?? created;
    if (anchor == null) return false;
    final diff = _dateOnly(DateTime.now()).difference(_dateOnly(anchor)).inDays;
    return diff >= 0 && diff <= windowDays;
  }

  /// The priority-sorted revision queue shown on the Study home page.
  static List<Map> dueQueue(List<Map> topics, Map config) {
    final revisionDay = isRevisionDayToday(config);
    final due = topics
        .where((t) => isDue(t) || (revisionDay && inRevisionWindow(t, config)))
        .toList();
    due.sort((a, b) => urgency(b).compareTo(urgency(a)));
    return due;
  }

  /// 0.0–1.0 progress through the interval ladder, for the progress ring.
  static double stageProgress(Map topic, Map config) {
    final ivs = intervals(config);
    if (ivs.isEmpty) return 0;
    final stage = ((topic['stage'] ?? -1) as int).clamp(-1, ivs.length - 1);
    return (stage + 1) / ivs.length;
  }

  static String dueLabel(Map topic) {
    final due = DateTime.tryParse(topic['nextDueAt']?.toString() ?? '');
    if (due == null) return 'Not scheduled';
    final days = _dateOnly(due).difference(_dateOnly(DateTime.now())).inDays;
    if (days < 0) return '${-days}d overdue';
    if (days == 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    return 'Due in ${days}d';
  }
}
