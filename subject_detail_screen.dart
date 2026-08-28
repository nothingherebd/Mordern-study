import 'package:flutter/material.dart';
import '../storage.dart';
import '../scheduler.dart';
import 'topic_study_screen.dart';

/// The "beside page" — pushed on top of the Study home page when a
/// subject (e.g. "English") is tapped. Lists every topic under that
/// subject with its revision status, and opens the black countdown
/// screen when a topic is tapped.
class SubjectDetailScreen extends StatefulWidget {
  final Map subject;
  const SubjectDetailScreen({super.key, required this.subject});

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final config = Storage.getConfig();
    final topics = Storage.topicsForSubject(widget.subject['id'])
      ..sort((a, b) => Scheduler.urgency(b).compareTo(Scheduler.urgency(a)));
    final color = Color(widget.subject['color'] as int);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(width: 10, height: 10, margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            Text(widget.subject['name']),
          ],
        ),
      ),
      body: topics.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No topics under ${widget.subject['name']} yet.\nAdd your first topic below.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 90),
              itemCount: topics.length,
              itemBuilder: (context, i) {
                final t = topics[i];
                final due = Scheduler.isDue(t);
                final progress = Scheduler.stageProgress(t, config);
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    leading: SizedBox(
                      width: 40,
                      height: 40,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: progress.clamp(0, 1),
                            strokeWidth: 4,
                            backgroundColor: const Color(0xFF262A36),
                            valueColor: AlwaysStoppedAnimation(due ? const Color(0xFFCC4B4B) : color),
                          ),
                          Icon(Icons.menu_book_rounded, size: 16, color: color),
                        ],
                      ),
                    ),
                    title: Text(t['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      Scheduler.dueLabel(t),
                      style: TextStyle(
                        fontSize: 12,
                        color: due ? const Color(0xFFE07A7A) : Colors.white54,
                        fontWeight: due ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () async {
                        await Storage.deleteTopic(t['id']);
                        setState(() {});
                      },
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TopicStudyScreen(topic: t, subject: widget.subject),
                        ),
                      );
                      setState(() {});
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTopicSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Add topic'),
      ),
    );
  }

  void _showAddTopicSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    int manualPriority = 3;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          return Padding(
            padding: EdgeInsets.only(
                left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('New topic', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Topic name'),
                ),
                const SizedBox(height: 14),
                const Text('Priority', style: TextStyle(fontSize: 12, color: Colors.white54)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: List.generate(5, (i) {
                    final v = i + 1;
                    return ChoiceChip(
                      label: Text('$v'),
                      selected: manualPriority == v,
                      onSelected: (_) => setSheet(() => manualPriority = v),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    final config = Storage.getConfig();
                    final now = DateTime.now();
                    final topic = {
                      'id': Storage.newId(),
                      'subjectId': widget.subject['id'],
                      'name': name,
                      'createdAt': now.toIso8601String(),
                      'lastReviewedAt': null,
                      'stage': -1,
                      'nextDueAt': Scheduler.computeInitialDue(now, config).toIso8601String(),
                      'manualPriority': manualPriority,
                      'totalReviews': 0,
                    };
                    await Storage.saveTopic(topic);
                    if (ctx.mounted) Navigator.pop(ctx);
                    setState(() {});
                  },
                  child: const Text('Add topic'),
                ),
              ],
            ),
          );
        });
      },
    );
  }
}
