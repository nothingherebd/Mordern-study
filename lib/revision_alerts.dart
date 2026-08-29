import 'notification_service.dart';

/// Schedules a real alarm ahead of when a topic comes due for revision —
/// using the "usual read time" carried over from the Plan task that
/// created it, minus a configurable lead time. Falls back to a fixed
/// daily reminder time if the topic never had a scheduled time.
class RevisionAlerts {
  static String _baseId(String topicId) => 'revision-$topicId';

  static Future<void> schedule(Map topic, Map config) async {
    final topicId = topic['id'] as String;
    await cancel(topicId);

    final dueStr = topic['nextDueAt']?.toString();
    if (dueStr == null) return;
    final due = DateTime.tryParse(dueStr);
    if (due == null) return;

    final preferredTime = topic['preferredTime']?.toString();
    DateTime fireAt;

    if (preferredTime != null && preferredTime.isNotEmpty && preferredTime.contains(':')) {
      final parts = preferredTime.split(':');
      final hour = int.tryParse(parts[0]) ?? 18;
      final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      final leadMinutes = (config['revisionLeadMinutes'] ?? 15) as int;
      final scheduledStart = DateTime(due.year, due.month, due.day, hour, minute);
      fireAt = scheduledStart.subtract(Duration(minutes: leadMinutes));
    } else {
      final hour = (config['revisionReminderHour'] ?? 18) as int;
      final minute = (config['revisionReminderMinute'] ?? 0) as int;
      fireAt = DateTime(due.year, due.month, due.day, hour, minute);
    }

    if (fireAt.isBefore(DateTime.now())) return;

    final subjectLabel = topic['subjectName']?.toString();
    await NotificationService.scheduleOnce(
      baseId: _baseId(topicId),
      title: '⏰ Revision coming up',
      body: subjectLabel == null || subjectLabel.isEmpty
          ? '${topic['name']} is due for revision soon'
          : '${topic['name']} ($subjectLabel) is due for revision soon',
      when: fireAt,
    );
  }

  static Future<void> cancel(String topicId) async {
    await NotificationService.cancelOnce(_baseId(topicId));
  }
}
