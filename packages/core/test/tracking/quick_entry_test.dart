// spec: calculations.md §17
import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

void main() {
  test('§17 range, break, location, project words and note', () {
    final e = parseQuickEntry('8-16:30 p30 @home bosch 014: Zeichnungen')!;
    expect(
      (e.start, e.end, e.breakMinutes, e.location),
      (480, 990, 30, WorkLocation.home),
    );
    expect((e.projectQuery, e.note), ('bosch 014', 'Zeichnungen'));
    expect(e.rangeMinutes, 480);
  });

  test('§17 spellings: en dash, spaces, dots, "pause 45"', () {
    final e = parseQuickEntry('08.15 – 12 pause 45 Werk')!;
    expect(
      (e.start, e.end, e.breakMinutes, e.projectQuery),
      (495, 720, 45, 'Werk'),
    );
    expect(parseQuickEntry('7-15 p0:30')!.breakMinutes, 30);
  });

  test('§17 a duration without times books project time', () {
    expect(parseQuickEntry('1:30 Werk Süd')!.duration, 90);
    expect(parseQuickEntry('1,5h Werk')!.duration, 90);
    expect(parseQuickEntry('45m Werk')!.duration, 45);
    expect(parseQuickEntry('2h')!.projectQuery, '');
  });

  test('§17 nothing to record, or impossible times', () {
    expect(parseQuickEntry('bosch 014'), isNull);
    expect(parseQuickEntry(''), isNull);
    expect(parseQuickEntry('8-25'), isNull);
  });

  test('§17 as a template: break centred, project over the range', () {
    final t = parseQuickEntry('8-16 p30 x')!.toTemplate(projectId: 'p');
    expect(
      [for (final i in t.items) (i.kind, i.start, i.end)],
      [
        (TemplateItemKind.session, 480, 960),
        (TemplateItemKind.breakTime, 705, 735),
        (TemplateItemKind.entry, 480, 960),
      ],
    );
    final night = parseQuickEntry('22-6')!;
    expect(night.rangeMinutes, 480);
  });
}
