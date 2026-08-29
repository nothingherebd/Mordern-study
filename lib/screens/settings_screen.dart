_SectionCard(
          title: 'Sound',
          subtitle: 'Chime on start/stop and when a countdown finishes.',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: config['soundEnabled'] as bool,
            activeColor: kAmber,
            title: const Text('Sound enabled', style: TextStyle(color: Colors.white)),
            onChanged: (v) {
              setState(() => config['soundEnabled'] = v);
              _save();
            },
          ),
        ),
