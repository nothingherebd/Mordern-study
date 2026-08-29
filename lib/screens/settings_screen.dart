import 'package:flutter/material.dart';
import '../storage.dart';
import '../main.dart' show kAmber, kSurfaceHigh;

const _weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/// Everything the priority/revision engine uses is editable here:
/// the interval ladder (days between reviews), the weekly revision day,
/// the catch-up window, default timer length, and the alarm behavior.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Map<String, dynamic> config;
  late List<int> intervals;

  @override
  void initState() {
    super.initState();
    config = Storage.getConfig();
    intervals = List<int>.from(config['intervals'] as List);
  }

  Future<void> _save() async {
    intervals.sort();
    config['intervals'] = intervals;
    await Storage.saveConfig(config);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
    }
  }

  void _addInterval() async {
    final ctrl = TextEditingController();
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurfaceHigh,
        title: const Text('Add interval (days)', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. 21'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text.trim())),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (value != null && value > 0 && !intervals.contains(value)) {
      setState(() => intervals.add(value));
      _save();
    }
  }

  void _resetIntervals() {
    setState(() => intervals = List<int>.from(Storage.defaultConfig['intervals'] as List));
    _save();
  }

  Future<void> _pickFallbackTime() async {
    final hour = (config['revisionReminderHour'] ?? 18) as int;
    final minute = (config['revisionReminderMinute'] ?? 0) as int;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: minute),
    );
    if (picked != null) {
      setState(() {
        config['revisionReminderHour'] = picked.hour;
        config['revisionReminderMinute'] = picked.minute;
      });
      _save();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fallbackHour = (config['revisionReminderHour'] ?? 18) as int;
    final fallbackMinute = (config['revisionReminderMinute'] ?? 0) as int;
    final fallbackLabel =
        '${fallbackHour.toString().padLeft(2, '0')}:${fallbackMinute.toString().padLeft(2, '0')}';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          title: 'Revision alerts',
          subtitle: 'An alarm fires ahead of a topic\'s usual read time (carried over from Plan), so you get a heads-up before it\'s due.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Alert lead time:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Slider(
                      value: (config['revisionLeadMinutes'] as int).toDouble(),
                      min: 0,
                      max: 120,
                      divisions: 24,
                      activeColor: kAmber,
                      label: '${config['revisionLeadMinutes']} min',
                      onChanged: (v) => setState(() => config['revisionLeadMinutes'] = v.round()),
                      onChangeEnd: (_) => _save(),
                    ),
                  ),
                  Text('${config['revisionLeadMinutes']}m', style: const TextStyle(color: Colors.white)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('Fallback alert time:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const Spacer(),
                  OutlinedButton(onPressed: _pickFallbackTime, child: Text(fallbackLabel)),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Used when a topic has no scheduled time from Plan.',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
        _SectionCard(
          title: 'Revision intervals',
          subtitle: 'Days between reviews as a topic climbs the ladder — the science of spaced repetition. Fully editable.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: intervals.map((d) {
                  return InputChip(
                    label: Text('${d}d'),
                    onDeleted: intervals.length > 1
                        ? () {
                            setState(() => intervals.remove(d));
                            _save();
                          }
                        : null,
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _addInterval,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add interval'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(onPressed: _resetIntervals, child: const Text('Reset to default')),
                ],
              ),
            ],
          ),
        ),
        _SectionCard(
          title: 'Weekly revision day',
          subtitle: 'On this day, everything touched within the catch-up window below is pulled into the queue too.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(7, (i) {
                  final wd = i + 1;
                  final selected = config['revisionWeekday'] == wd;
                  return ChoiceChip(
                    label: Text(_weekdayNames[i]),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => config['revisionWeekday'] = wd);
                      _save();
                    },
                  );
                }),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text('Catch-up window:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Slider(
                      value: (config['revisionWindowDays'] as int).toDouble(),
                      min: 1,
                      max: 30,
                      divisions: 29,
                      activeColor: kAmber,
                      label: '${config['revisionWindowDays']} days',
                      onChanged: (v) => setState(() => config['revisionWindowDays'] = v.round()),
                      onChangeEnd: (_) => _save(),
                    ),
                  ),
                  Text('${config['revisionWindowDays']}d', style: const TextStyle(color: Colors.white)),
                ],
              ),
            ],
          ),
        ),
        _SectionCard(
          title: 'Study timer',
          subtitle: 'Default countdown length on the black study screen (adjustable per-session too).',
          child: Row(
            children: [
              const Text('Default length:', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(width: 10),
              Expanded(
                child: Slider(
                  value: (config['defaultTimerMinutes'] as int).toDouble(),
                  min: 5,
                  max: 90,
                  divisions: 17,
                  activeColor: kAmber,
                  label: '${config['defaultTimerMinutes']} min',
                  onChanged: (v) => setState(() => config['defaultTimerMinutes'] = v.round()),
                  onChangeEnd: (_) => _save(),
                ),
              ),
              Text('${config['defaultTimerMinutes']}m', style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _SectionCard({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
