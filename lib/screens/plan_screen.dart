import 'package:flutter/material.dart';
import '../storage.dart';
import '../notification_service.dart';
import '../scheduler.dart';
import '../revision_alerts.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});
  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  int offset = 1; // opens on tomorrow by default

  String get dateKey {
    final d = DateTime.now().add(Duration(days: offset));
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  DateTime get viewedDate => DateTime.now().add(Duration(days: offset));

  String get relLabel {
    if (offset == 0) return 'TODAY';
    if (offset == 1) return 'TOMORROW';
    if (offset == -1) return 'YESTERDAY';
    return offset < 0 ? '${offset.abs()} DAY(S) AGO' : 'IN $offset DAY(S)';
  }

  List<Map> get tasks {
    var list = Storage.tasksForDate(dateKey);
    if (list.isEmpty && offset >= 0) {
      // seed from template on first visit to a future/today date
      for (final t in defaultTemplate) {
        final task = {
          'id': Storage.newId(),
          'dateKey': dateKey,
          'title': t,
          'start': '',
          'end': '',
          'subjectId': '',
          'done': false,
          'notifyAtStart': false,
        };
        Storage.saveTask(task);
      }
      list = Storage.tasksForDate(dateKey);
    }
    return list;
  }

  Map? subjectFor(String? id) {
    if (id == null || id.isEmpty) return null;
    final s = Storage.allSubjects().where((s) => s['id'] == id);
    return s.isEmpty ? null : s.first;
  }

  /// Marking a task done is "I studied/read this." If it has a subject,
  /// this feeds Study's spaced-repetition engine directly: first time
  /// creates the topic (carrying over the task's scheduled time as its
  /// "usual read time"), every time after that counts as a review and
  /// advances it up the interval ladder. Either way, a revision alarm
  /// gets (re)scheduled ahead of the next due date.
  Future<void> _recordRevisionProgress(Map task) async {
    final subjectId = (task['subjectId'] ?? '') as String;
    final title = ((task['title'] ?? '') as String).trim();
    if (subjectId.isEmpty || title.isEmpty) return;

    final config = Storage.getConfig();
    final subject = subjectFor(subjectId);
    final preferredTime = (task['start'] ?? '') as String;

    final matches = Storage.allTopics().where(
      (t) => t['subjectId'] == subjectId && (t['name'] as String).toLowerCase() == title.toLowerCase(),
    );

    Map topic;
    if (matches.isEmpty) {
      final now = DateTime.now();
      topic = {
        'id': Storage.newId(),
        'subjectId': subjectId,
        'subjectName': subject?['name'] ?? '',
        'name': title,
        'preferredTime': preferredTime,
        'createdAt': now.toIso8601String(),
        'lastReviewedAt': null,
        'stage': -1,
        'nextDueAt': Scheduler.computeInitialDue(now, config).toIso8601String(),
        'manualPriority': 3,
        'totalReviews': 0,
      };
    } else {
      topic = Scheduler.applyReview(Map.from(matches.first), config);
      if (preferredTime.isNotEmpty) topic['preferredTime'] = preferredTime;
      topic['subjectName'] = subject?['name'] ?? topic['subjectName'] ?? '';
    }
    await Storage.saveTopic(topic);
    await RevisionAlerts.schedule(topic, config);
  }

  Future<void> _toggleDone(Map t, bool? v) async {
    final wasDone = t['done'] == true;
    t['done'] = v;
    await Storage.saveTask(Map.from(t));
    if (v == true && !wasDone) {
      await _recordRevisionProgress(t);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final list = tasks;
    final done = list.where((t) => t['done'] == true).length;
    final pct = list.isEmpty ? 0.0 : done / list.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => offset--),
              ),
              Column(
                children: [
                  Text(
                    '${_weekday(viewedDate.weekday)}, ${_month(viewedDate.month)} ${viewedDate.day}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Text(relLabel,
                      style: TextStyle(fontSize: 10, letterSpacing: 1, color: Colors.grey[600])),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() => offset++),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: pct, minHeight: 6),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('Nothing planned — add a task below.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final t = list[i];
                    final subj = subjectFor(t['subjectId']);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Checkbox(
                          value: t['done'] == true,
                          onChanged: (v) => _toggleDone(t, v),
                        ),
                        title: Text(
                          t['title'],
                          style: t['done'] == true
                              ? const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)
                              : null,
                        ),
                        subtitle: (t['start'] != '' || subj != null)
                            ? Row(children: [
                                if (t['start'] != '')
                                  Text('${t['start']}${t['end'] != '' ? ' – ${t['end']}' : ''}  ',
                                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                                if (subj != null) ...[
                                  Container(width: 8, height: 8, margin: const EdgeInsets.only(right: 4),
                                      decoration: BoxDecoration(color: Color(subj['color']), shape: BoxShape.circle)),
                                  Text(subj['name'], style: const TextStyle(fontSize: 11)),
                                ]
                              ])
                            : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            NotificationService.cancelOnce(t['id']);
                            Storage.deleteTask(t['id']);
                            setState(() {});
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add task'),
            onPressed: () => _showAddTaskSheet(context),
          ),
        ),
      ],
    );
  }

  void _showAddTaskSheet(BuildContext context) {
    final titleCtrl = TextEditingController();
    TimeOfDay? start;
    TimeOfDay? end;
    String? subjectId;
    bool notify = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          final subjects = Storage.allSubjects();
          return Padding(
            padding: EdgeInsets.only(
                left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('New task', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Task')),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
                        if (t != null) setSheet(() => start = t);
                      },
                      child: Text(start == null ? 'Start time' : start!.format(ctx)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
                        if (t != null) setSheet(() => end = t);
                      },
                      child: Text(end == null ? 'End time' : end!.format(ctx)),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: subjectId,
                  decoration: const InputDecoration(labelText: 'Subject'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('— none —')),
                    ...subjects.map((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name']))),
                  ],
                  onChanged: (v) => setSheet(() => subjectId = v),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: notify,
                  title: const Text('Notify me when this starts', style: TextStyle(fontSize: 13)),
                  onChanged: (v) => setSheet(() => notify = v ?? true),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () async {
                    final title = titleCtrl.text.trim();
                    if (title.isEmpty) return;
                    final id = Storage.newId();
                    final task = {
                      'id': id,
                      'dateKey': dateKey,
                      'title': title,
                      'start': start == null ? '' : _fmt(start!),
                      'end': end == null ? '' : _fmt(end!),
                      'subjectId': subjectId ?? '',
                      'done': false,
                      'notifyAtStart': notify && start != null,
                    };
                    await Storage.saveTask(task);
                    if (task['notifyAtStart'] == true) {
                      final when = DateTime(viewedDate.year, viewedDate.month, viewedDate.day,
                          start!.hour, start!.minute);
                      await NotificationService.scheduleOnce(
                        baseId: id,
                        title: '📘 $title',
                        body: end == null ? 'Starts now' : 'Scheduled ${_fmt(start!)} – ${_fmt(end!)}',
                        when: when,
                      );
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    setState(() {});
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _weekday(int w) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][w - 1];
  String _month(int m) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m - 1];
}
