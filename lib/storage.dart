import 'package:hive_flutter/hive_flutter.dart';

/// Plain Map<String,dynamic> records are used throughout instead of
/// generated Hive TypeAdapters, so no build_runner / code generation
/// step is needed — this keeps the GitHub Actions build simple.
class Storage {
  static late Box tasksBox;
  static late Box subjectsBox;
  static late Box topicsBox;
  static late Box alarmsBox;
  static late Box settingsBox;

  static Future<void> init() async {
    await Hive.initFlutter();
    tasksBox = await Hive.openBox('tasks');
    subjectsBox = await Hive.openBox('subjects');
    topicsBox = await Hive.openBox('topics');
    alarmsBox = await Hive.openBox('alarms');
    settingsBox = await Hive.openBox('settings');

    if (subjectsBox.isEmpty) {
      for (final s in defaultSubjects) {
        await subjectsBox.put(s['id'], s);
      }
    }
  }

  static String newId() =>
      DateTime.now().microsecondsSinceEpoch.toString() +
      (100 + DateTime.now().millisecond).toString();

  // ---- Tasks ----
  static List<Map> tasksForDate(String dateKey) {
    return tasksBox.values
        .cast<Map>()
        .where((t) => t['dateKey'] == dateKey)
        .toList()
      ..sort((a, b) => (a['start'] ?? '99:99')
          .toString()
          .compareTo((b['start'] ?? '99:99').toString()));
  }

  static Future<void> saveTask(Map task) async {
    await tasksBox.put(task['id'], task);
  }

  static Future<void> deleteTask(String id) async => tasksBox.delete(id);

  // ---- Subjects ----
  static List<Map> allSubjects() => subjectsBox.values.cast<Map>().toList();

  static Future<void> saveSubject(Map s) async => subjectsBox.put(s['id'], s);

  static Future<void> deleteSubject(String id) async {
    await subjectsBox.delete(id);
    final topics = topicsBox.values.cast<Map>().where((t) => t['subjectId'] == id).toList();
    for (final t in topics) {
      await topicsBox.delete(t['id']);
    }
  }

  // ---- Topics (study items under a subject, spaced-repetition scheduled) ----
  static List<Map> topicsForSubject(String subjectId) =>
      topicsBox.values.cast<Map>().where((t) => t['subjectId'] == subjectId).toList();

  static List<Map> allTopics() => topicsBox.values.cast<Map>().toList();

  static Future<void> saveTopic(Map t) async => topicsBox.put(t['id'], t);

  static Future<void> deleteTopic(String id) async => topicsBox.delete(id);

  // ---- Alarms ----
  static List<Map> allAlarms() {
    final list = alarmsBox.values.cast<Map>().toList();
    list.sort((a, b) => a['time'].toString().compareTo(b['time'].toString()));
    return list;
  }

  static Future<void> saveAlarm(Map a) async => alarmsBox.put(a['id'], a);

  static Future<void> deleteAlarm(String id) async => alarmsBox.delete(id);

  // ---- Settings (revision engine configuration — everything user-tunable) ----
  static const Map<String, dynamic> defaultConfig = {
    // Spaced-repetition ladder, in days. Fully editable from Settings.
    'intervals': [1, 4, 30, 45, 60, 90, 150, 200, 280, 365],
    // Weekly "catch-up" revision day (Dart weekday: Mon=1 ... Sun=7). Default Friday.
    'revisionWeekday': 5,
    // On the revision day, pull in anything touched within this many days too.
    'revisionWindowDays': 6,
    'soundEnabled': true,
    'defaultTimerMinutes': 25,
  };

  static Map<String, dynamic> getConfig() {
    final raw = settingsBox.get('config');
    final merged = Map<String, dynamic>.from(defaultConfig);
    if (raw is Map) {
      raw.forEach((k, v) => merged[k as String] = v);
    }
    merged['intervals'] = (merged['intervals'] as List).cast<int>();
    return merged;
  }

  static Future<void> saveConfig(Map<String, dynamic> config) async {
    await settingsBox.put('config', config);
  }
}

const List<String> defaultTemplate = [
  'Bangla — grammar & literature',
  'English — grammar & comprehension',
  'Bangladesh Affairs',
  'International Affairs',
  'General Science',
  'Computer & ICT',
  'Math & Mental Ability',
  'Ethics, Values & Good Governance',
  'Current Affairs — newspaper review',
  'Revision + MCQ practice',
];

final List<Map<String, dynamic>> defaultSubjects = [
  {'id': 'subj-bangla', 'name': 'Bangla', 'color': 0xFFB8863B, 'start': '', 'end': '', 'days': [1, 2, 3, 4, 5, 6, 7], 'notify': false},
  {'id': 'subj-english', 'name': 'English', 'color': 0xFF6366F1, 'start': '', 'end': '', 'days': [1, 2, 3, 4, 5, 6, 7], 'notify': false},
  {'id': 'subj-math', 'name': 'Math & Mental Ability', 'color': 0xFFF59E0B, 'start': '', 'end': '', 'days': [1, 2, 3, 4, 5, 6, 7], 'notify': false},
  {'id': 'subj-science', 'name': 'Science & Tech', 'color': 0xFFEC4899, 'start': '', 'end': '', 'days': [1, 2, 3, 4, 5, 6, 7], 'notify': false},
];

const List<int> presetColors = [
  0xFFB8863B, 0xFF6366F1, 0xFFF59E0B, 0xFFEC4899,
  0xFF4C7A5E, 0xFFA8462F, 0xFF3B82F6, 0xFF10B981,
];
