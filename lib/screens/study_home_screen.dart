import 'package:flutter/material.dart';
import '../storage.dart';
import '../scheduler.dart';
import '../main.dart' show kAmber, kSurfaceHigh;
import 'subject_detail_screen.dart';
import 'topic_study_screen.dart';

/// The single Study home page. Subjects (e.g. "English") are listed as
/// topics-under-a-subject; tapping one slides in the subject's detail
/// page ("beside page") on top of this one. A priority-sorted revision
/// queue sits above the subject list so nothing gets forgotten.
class StudyHomeScreen extends StatefulWidget {
  const StudyHomeScreen({super.key});
  @override
  State<StudyHomeScreen> createState() => _StudyHomeScreenState();
}

class _StudyHomeScreenState extends State<StudyHomeScreen> {
  @override
  Widget build(BuildContext context) {
    final config = Storage.getConfig();
    final subjects = Storage.allSubjects();
    final allTopics = Storage.allTopics();
    final queue = Scheduler.dueQueue(allTopics, config);
    final revisionDay = Scheduler.isRevisionDayToday(config);

    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (revisionDay) _RevisionDayBanner(count: queue.length),
          if (queue.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10, top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Due for revision', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  Text('${queue.length}', style: const TextStyle(color: kAmber, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            SizedBox(
              height: 128,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: queue.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final t = queue[i];
                  final subj = _subjectFor(subjects, t['subjectId']);
                  if (subj == null) return const SizedBox.shrink();
                  return _RevisionCard(
                    topic: t,
                    subject: subj,
                    config: config,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => TopicStudyScreen(topic: t, subject: subj)),
                      );
                      setState(() {});
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 22),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subjects', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              TextButton.icon(
                onPressed: () => _showAddSubjectSheet(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          subjects.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(child: Text('No subjects yet — add one to get started.', style: TextStyle(color: Colors.white54))),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: subjects.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.25,
                  ),
                  itemBuilder: (context, i) {
                    final s = subjects[i];
                    final topics = allTopics.where((t) => t['subjectId'] == s['id']).toList();
                    final due = topics.where(Scheduler.isDue).length;
                    return _SubjectCard(
                      subject: s,
                      topicCount: topics.length,
                      dueCount: due,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => SubjectDetailScreen(subject: s)),
                        );
                        setState(() {});
                      },
                    );
                  },
                ),
        ],
      ),
    );
  }

  Map? _subjectFor(List<Map> subjects, String? id) {
    if (id == null) return null;
    final matches = subjects.where((s) => s['id'] == id);
    return matches.isEmpty ? null : matches.first;
  }

  void _showAddSubjectSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    int color = presetColors.first;

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
                const Text('New subject', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                TextField(controller: nameCtrl, autofocus: true, decoration: const InputDecoration(labelText: 'Name (e.g. English)')),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: presetColors.map((c) {
                    return GestureDetector(
                      onTap: () => setSheet(() => color = c),
                      child: CircleAvatar(
                        backgroundColor: Color(c),
                        radius: 14,
                        child: color == c ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    final subject = {
                      'id': Storage.newId(),
                      'name': name,
                      'color': color,
                      'start': '',
                      'end': '',
                      'days': [1, 2, 3, 4, 5, 6, 7],
                      'notify': false,
                    };
                    await Storage.saveSubject(subject);
                    if (ctx.mounted) Navigator.pop(ctx);
                    setState(() {});
                  },
                  child: const Text('Add subject'),
                ),
              ],
            ),
          );
        });
      },
    );
  }
}

class _RevisionDayBanner extends StatelessWidget {
  final int count;
  const _RevisionDayBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF3A2E12), Color(0xFF241C0B)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kAmber.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_repeat, color: kAmber),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Weekly revision day', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                Text('Everything from the last stretch is pulled in — $count to review.',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RevisionCard extends StatelessWidget {
  final Map topic;
  final Map subject;
  final Map config;
  final VoidCallback onTap;
  const _RevisionCard({required this.topic, required this.subject, required this.config, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Color(subject['color'] as int);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kSurfaceHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(subject['name'], style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
            Text(
              topic['name'] ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            Text(Scheduler.dueLabel(topic), style: const TextStyle(color: Color(0xFFE07A7A), fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final Map subject;
  final int topicCount;
  final int dueCount;
  final VoidCallback onTap;
  const _SubjectCard({required this.subject, required this.topicCount, required this.dueCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Color(subject['color'] as int);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kSurfaceHigh,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(width: 30, height: 30,
                    decoration: BoxDecoration(color: color.withOpacity(0.18), shape: BoxShape.circle),
                    child: Icon(Icons.menu_book_rounded, color: color, size: 16)),
                if (dueCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFCC4B4B), borderRadius: BorderRadius.circular(10)),
                    child: Text('$dueCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            const Spacer(),
            Text(subject['name'], style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('$topicCount topic${topicCount == 1 ? '' : 's'}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
