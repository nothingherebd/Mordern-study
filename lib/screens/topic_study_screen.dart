import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../storage.dart';
import '../scheduler.dart';
import '../main.dart' show kAmber;

/// The black countdown study screen. Opens for a single topic. Start/Stop
/// plays a system click and haptic each time, and the revision-progress
/// bar shows how far the topic has climbed the spaced-repetition ladder
/// so it's never forgotten.
class TopicStudyScreen extends StatefulWidget {
  final Map topic;
  final Map subject;
  const TopicStudyScreen({super.key, required this.topic, required this.subject});

  @override
  State<TopicStudyScreen> createState() => _TopicStudyScreenState();
}

class _TopicStudyScreenState extends State<TopicStudyScreen> {
  late Map topic;
  late Map config;
  Timer? _ticker;
  bool running = false;
  int totalSeconds = 25 * 60;
  int remainingSeconds = 25 * 60;

  @override
  void initState() {
    super.initState();
    topic = Map.from(widget.topic);
    config = Storage.getConfig();
    final minutes = (config['defaultTimerMinutes'] ?? 25) as int;
    totalSeconds = minutes * 60;
    remainingSeconds = totalSeconds;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _adjustMinutes(int deltaMinutes) {
    if (running) return;
    setState(() {
      final newTotal = (totalSeconds + deltaMinutes * 60).clamp(5 * 60, 180 * 60);
      totalSeconds = newTotal;
      remainingSeconds = newTotal;
    });
  }

  void _toggleStartStop() {
    if (running) {
      _ticker?.cancel();
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.lightImpact();
      setState(() => running = false);
    } else {
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.lightImpact();
      setState(() => running = true);
      _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
        if (remainingSeconds <= 1) {
          t.cancel();
          setState(() {
            remainingSeconds = 0;
            running = false;
          });
          SystemSound.play(SystemSoundType.alert);
          HapticFeedback.mediumImpact();
          _showCompleteDialog();
        } else {
          setState(() => remainingSeconds--);
        }
      });
    }
  }

  void _reset() {
    _ticker?.cancel();
    setState(() {
      running = false;
      remainingSeconds = totalSeconds;
    });
  }

  Future<void> _showCompleteDialog() async {
    if (!mounted) return;
    final markReviewed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurfaceDialog,
        title: const Text('Session complete', style: TextStyle(color: Colors.white)),
        content: Text(
          'Mark "${topic['name']}" as reviewed and schedule the next revision?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not yet')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Mark reviewed')),
        ],
      ),
    );
    if (markReviewed == true) _markReviewed();
  }

  Future<void> _markReviewed() async {
    final updated = Scheduler.applyReview(topic, config);
    await Storage.saveTopic(updated);
    setState(() => topic = updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Next review: ${Scheduler.dueLabel(topic)}')),
    );
  }

  String _fmt(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  static const kSurfaceDialog = Color(0xFF15171F);

  @override
  Widget build(BuildContext context) {
    final progress = totalSeconds == 0 ? 0.0 : (totalSeconds - remainingSeconds) / totalSeconds;
    final stageProgress = Scheduler.stageProgress(topic, config);
    final ivs = Scheduler.intervals(config);
    final stage = ((topic['stage'] ?? -1) as int);
    final subjColor = Color(widget.subject['color'] as int);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: subjColor, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(widget.subject['name'], style: const TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 0.5)),
                          ],
                        ),
                        Text(
                          topic['name'] ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const Spacer(),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 260,
                    height: 260,
                    child: CircularProgressIndicator(
                      value: progress.clamp(0, 1),
                      strokeWidth: 10,
                      backgroundColor: const Color(0xFF1C1C1C),
                      valueColor: const AlwaysStoppedAnimation(kAmber),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _fmt(remainingSeconds),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 52,
                          fontWeight: FontWeight.w800,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        running ? 'Studying…' : (remainingSeconds == totalSeconds ? 'Ready' : 'Paused'),
                        style: const TextStyle(color: Colors.white38, fontSize: 13, letterSpacing: 1),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (!running)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _minuteAdjustButton(Icons.remove, () => _adjustMinutes(-5)),
                    const SizedBox(width: 20),
                    Text('${totalSeconds ~/ 60} min', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                    const SizedBox(width: 20),
                    _minuteAdjustButton(Icons.add, () => _adjustMinutes(5)),
                  ],
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.replay, color: Colors.white38, size: 26),
                    onPressed: _reset,
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: _toggleStartStop,
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: running ? const Color(0xFFCC4B4B) : kAmber,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        running ? Icons.stop_rounded : Icons.play_arrow_rounded,
                        color: Colors.black,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20 + 26 + 20),
                ],
              ),
              const Spacer(),
              _RevisionProgressCard(
                stage: stage,
                totalStages: ivs.length,
                stageProgress: stageProgress,
                dueLabel: Scheduler.dueLabel(topic),
                totalReviews: (topic['totalReviews'] ?? 0) as int,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Mark as reviewed & schedule next'),
                  onPressed: _markReviewed,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _minuteAdjustButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white70, size: 18),
      ),
    );
  }
}

class _RevisionProgressCard extends StatelessWidget {
  final int stage;
  final int totalStages;
  final double stageProgress;
  final String dueLabel;
  final int totalReviews;

  const _RevisionProgressCard({
    required this.stage,
    required this.totalStages,
    required this.stageProgress,
    required this.dueLabel,
    required this.totalReviews,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Revision progress', style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 0.4)),
              Text(dueLabel, style: const TextStyle(color: kAmber, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: stageProgress.clamp(0, 1),
              minHeight: 8,
              backgroundColor: const Color(0xFF262626),
              valueColor: const AlwaysStoppedAnimation(kAmber),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            stage < 0
                ? 'Not started yet · $totalReviews reviews so far'
                : 'Stage ${stage + 1} of $totalStages · $totalReviews reviews so far',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
