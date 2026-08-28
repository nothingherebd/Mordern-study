import 'package:flutter/material.dart';
import '../storage.dart';
import '../notification_service.dart';

const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class AlarmsScreen extends StatefulWidget {
  const AlarmsScreen({super.key});
  @override
  State<AlarmsScreen> createState() => _AlarmsScreenState();
}

class _AlarmsScreenState extends State<AlarmsScreen> {
  @override
  Widget build(BuildContext context) {
    final alarms = Storage.allAlarms();
    return Column(
      children: [
        AppBar(
          title: const Text('Alarms'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_active_outlined),
              tooltip: 'Send test notification now',
              onPressed: () async {
                await NotificationService.testNotificationNow();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Test notification sent — check your shade')),
                  );
                }
              },
            ),
          ],
        ),
        Expanded(
          child: alarms.isEmpty
              ? const Center(child: Text('No alarms yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: alarms.length,
                  itemBuilder: (context, i) {
                    final a = alarms[i];
                    final days = (a['days'] as List).cast<int>();
                    final everyDay = days.length == 7;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(a['time'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${a['label'] ?? 'Study alarm'} · ${everyDay ? "Everyday" : days.map((d) => _dayLabels[d - 1]).join(", ")}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: a['on'] == true,
                              onChanged: (v) async {
                                a['on'] = v;
                                await Storage.saveAlarm(Map.from(a));
                                if (v) {
                                  final parts = (a['time'] as String).split(':');
                                  await NotificationService.scheduleWeekly(
                                    baseId: 'alarm-${a['id']}',
                                    title: '⏰ ${a['label'] ?? 'Study alarm'}',
                                    body: 'Time to study — BCS Prep Planner',
                                    hour: int.parse(parts[0]),
                                    minute: int.parse(parts[1]),
                                    weekdays: (a['days'] as List).cast<int>(),
                                  );
                                } else {
                                  await NotificationService.cancelWeekly('alarm-${a['id']}');
                                }
                                setState(() {});
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () async {
                                await NotificationService.cancelWeekly('alarm-${a['id']}');
                                await Storage.deleteAlarm(a['id']);
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            icon: const Icon(Icons.add_alarm),
            label: const Text('Set alarm'),
            onPressed: () => _showAddAlarmSheet(context),
          ),
        ),
      ],
    );
  }

  void _showAddAlarmSheet(BuildContext context) {
    final labelCtrl = TextEditingController();
    TimeOfDay time = TimeOfDay.now();
    List<int> days = [1, 2, 3, 4, 5, 6, 7];

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
                const Text('New alarm', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () async {
                    final t = await showTimePicker(context: ctx, initialTime: time);
                    if (t != null) setSheet(() => time = t);
                  },
                  child: Text(time.format(ctx), style: const TextStyle(fontSize: 18)),
                ),
                const SizedBox(height: 10),
                TextField(controller: labelCtrl, decoration: const InputDecoration(labelText: 'Label')),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: List.generate(7, (i) {
                    final wd = i + 1;
                    final on = days.contains(wd);
                    return ChoiceChip(
                      label: Text(_dayLabels[i]),
                      selected: on,
                      onSelected: (v) => setSheet(() {
                        if (v) {
                          days.add(wd);
                        } else {
                          days.remove(wd);
                        }
                      }),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    if (days.isEmpty) return;
                    final id = Storage.newId();
                    final alarm = {
                      'id': id,
                      'time': _fmt(time),
                      'label': labelCtrl.text.trim(),
                      'days': days,
                      'on': true,
                    };
                    await Storage.saveAlarm(alarm);
                    await NotificationService.scheduleWeekly(
                      baseId: 'alarm-$id',
                      title: '⏰ ${alarm['label'] == '' ? 'Study alarm' : alarm['label']}',
                      body: 'Time to study — BCS Prep Planner',
                      hour: time.hour,
                      minute: time.minute,
                      weekdays: days,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    setState(() {});
                  },
                  child: const Text('Set alarm'),
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
}
