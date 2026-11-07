// Fills a TimeTrack database with a realistic sample week (2–6 Nov 2026) for
// screenshots and manual checks. Usage (from packages/core):
//   dart run tool/seed_demo.dart <path/to/timetrack.sqlite>
// The file is replaced. Never point it at real data.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:timetrack_core/timetrack_core.dart';

/// Writes the sample week into the database file given as the only argument.
Future<void> main(List<String> args) async {
  final file = File(args.single);
  if (file.existsSync()) file.deleteSync();
  file.parent.createSync(recursive: true);
  final db = TimeTrackDatabase(NativeDatabase(file));
  final repo = await SyncedRepository.open(
    DriftSyncStore(db),
    await loadOrCreateDeviceId(db),
  );
  final zone = HomeTimeZone();
  String at(String date, String hm) {
    final p = hm.split(':');
    return isoMinute(
      zone.instantAt(LocalDate.parse(date), int.parse(p[0]), int.parse(p[1])),
    );
  }

  await saveSetting(repo, SettingKeys.federalState, 'NW');
  await saveSetting(repo, SettingKeys.startingBalance, 135);
  await repo.write('work_schedules', repo.newId(), {
    'valid_from': '2026-01-01',
    for (final d in ['mon', 'tue', 'wed', 'thu', 'fri']) 'minutes_$d': 480,
    'vacation_days': 30,
  });
  await saveSetting(repo, SettingKeys.balanceStartDate, '2026-11-02');
  await repo.write('home_office_rules', repo.newId(), {
    'valid_from': '2026-01-01',
    'period': 'month',
    'max_percent': 40,
    'basis': 'worked',
  });
  await repo.write('projects', 'werk', {
    'name': 'Werk Süd Umbau',
    'project_number': 'P-2026/014',
    'order_number': 'A-778812',
    'client': 'Bosch',
    'favorite': true,
  });
  await repo.write('projects', 'logistik', {
    'name': 'Müller Logistik',
    'project_number': 'P-2025/140',
    'order_number': 'A-120014',
    'client': 'Müller GmbH',
    'favorite': true,
  });
  await repo.write('projects', 'intern', {'name': 'Interne Schulung'});

  Future<void> day(
    String date,
    String loc,
    String from,
    String to, {
    String? project,
  }) async {
    await repo.write('work_sessions', repo.newId(), {
      'start_utc': at(date, from),
      'end_utc': at(date, to),
      'location': loc,
    });
    await repo.write('breaks', repo.newId(), {
      'start_utc': at(date, '12:00'),
      'end_utc': at(date, '12:30'),
    });
    if (project != null) {
      await repo.write('project_entries', repo.newId(), {
        'project_id': project,
        'start_utc': at(date, from),
        'end_utc': at(date, '12:00'),
      });
      await repo.write('project_entries', repo.newId(), {
        'project_id': 'logistik',
        'start_utc': at(date, '12:30'),
        'end_utc': at(date, '15:00'),
      });
    }
  }

  await day('2026-11-02', 'home', '07:45', '16:45', project: 'werk');
  await day('2026-11-03', 'office', '08:00', '16:00', project: 'werk');
  await repo.write('absences', repo.newId(), {
    'date': '2026-11-04',
    'kind': 'vacation',
    'fraction': 1,
  });
  await repo.write('trips', repo.newId(), {
    'depart_utc': at('2026-11-05', '06:30'),
    'return_utc': at('2026-11-06', '19:00'),
    'destination': 'Stuttgart',
    'country': 'DE',
    'overnight': true,
  });
  await repo.write('work_sessions', repo.newId(), {
    'start_utc': at('2026-11-05', '06:30'),
    'end_utc': at('2026-11-05', '09:30'),
    'location': 'travel',
  });
  await repo.write('work_sessions', repo.newId(), {
    'start_utc': at('2026-11-05', '09:30'),
    'end_utc': at('2026-11-05', '18:00'),
    'location': 'on_site',
  });
  await repo.write('work_sessions', repo.newId(), {
    'start_utc': at('2026-11-06', '08:00'),
    'end_utc': at('2026-11-06', '15:00'),
    'location': 'on_site',
  });
  await repo.write('work_sessions', repo.newId(), {
    'start_utc': at('2026-11-06', '15:00'),
    'end_utc': at('2026-11-06', '19:00'),
    'location': 'travel',
  });
  await db.close();
  stdout.writeln('seeded ${file.path}');
}
