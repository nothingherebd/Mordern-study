import 'package:flutter/material.dart';
import '../storage.dart';
import '../scheduler.dart';
import 'topic_study_screen.dart';

/// The "beside page" — pushed on top of Study home when a subject
/// (e.g. "English") is tapped. Topics here are populated automatically
/// from Plan: checking off a task with this subject creates or reviews
/// the matching topic. Tapping a topic opens the black countdown screen.
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
                  'No topics under ${widget.subject['name']} yet.\n\nCheck off a task with this subject in Plan — it\'ll show up here and start being scheduled for revision.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
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
                      tooltip: 'Remove from revision tracking',
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
    );
  }
}
