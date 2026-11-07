// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'TimeTrack';

  @override
  String get navToday => 'Heute';

  @override
  String get navCalendar => 'Kalender';

  @override
  String get navProjects => 'Projekte';

  @override
  String get navSettings => 'Einstellungen';

  @override
  String get clockIn => 'Einstempeln';

  @override
  String get clockOut => 'Ausstempeln';

  @override
  String get startBreak => 'Pause';

  @override
  String get endBreak => 'Pause beenden';

  @override
  String get notClockedIn => 'Nicht eingestempelt';

  @override
  String clockedInSince(String time) {
    return 'Eingestempelt seit $time';
  }

  @override
  String onBreakSince(String time) {
    return 'Pause seit $time';
  }

  @override
  String get locationOffice => 'Büro';

  @override
  String get locationHome => 'Homeoffice';

  @override
  String get locationOnSite => 'Vor Ort';

  @override
  String get locationTravel => 'Unterwegs';

  @override
  String get location => 'Ort';

  @override
  String get worked => 'Gearbeitet';

  @override
  String get target => 'Soll';

  @override
  String get credited => 'Angerechnet';

  @override
  String get difference => 'Differenz';

  @override
  String get balance => 'Überstundensaldo';

  @override
  String get balanceToday => 'inkl. heute';

  @override
  String get unassigned => 'Ohne Projekt';

  @override
  String get chooseProject => 'Projekt wählen';

  @override
  String get stopProject => 'Projekt stoppen';

  @override
  String get noProjectRunning => 'Kein Projekt aktiv';

  @override
  String homeOfficeWeek(String used, String allowed, String left) {
    return 'Homeoffice diese Woche: $used von $allowed Tagen, noch $left';
  }

  @override
  String homeOfficeMonth(String used, String allowed, String left) {
    return 'Homeoffice diesen Monat: $used von $allowed Tagen, noch $left';
  }

  @override
  String get setupHint =>
      'Lege in den Einstellungen Bundesland und Arbeitszeitmodell fest, damit Soll und Saldo stimmen.';

  @override
  String get openSettings => 'Einstellungen öffnen';

  @override
  String get startTrip => 'Reise beginnen';

  @override
  String get endTrip => 'Reise beenden';

  @override
  String onTripTo(String destination) {
    return 'Auf Reise nach $destination';
  }

  @override
  String get onTrip => 'Auf Reise';

  @override
  String get startTripQuestion => 'Dienstreise beginnen?';

  @override
  String get endTripQuestion => 'Ist die Reise beendet?';

  @override
  String get notNow => 'Nicht jetzt';

  @override
  String get destination => 'Reiseziel';

  @override
  String get country => 'Ländercode';

  @override
  String get overnight => 'Mit Übernachtung';

  @override
  String get depart => 'Abreise';

  @override
  String get returnTime => 'Rückkehr';

  @override
  String get notices => 'Hinweise';

  @override
  String warnBreakMissing(String minutes) {
    return '$minutes Pause fehlen (ArbZG §4)';
  }

  @override
  String get warnOver6h => 'Mehr als 6 Std. ohne Pause (ArbZG §4)';

  @override
  String get warnOver10h => 'Mehr als 10 Std. gearbeitet (ArbZG §3)';

  @override
  String warnRest(String minutes) {
    return 'Nur $minutes Ruhezeit seit dem Vortag (ArbZG §5)';
  }

  @override
  String get warnSunday => 'Arbeit an Sonn- oder Feiertag';

  @override
  String get warnOpenSession => 'Lange eingestempelt – Ausstempeln vergessen?';

  @override
  String get warnOverlapSessions => 'Überlappende Arbeitszeiten';

  @override
  String get warnOverlapProjects => 'Überlappende Projektzeiten';

  @override
  String warnProjectOutside(String minutes) {
    return '$minutes Projektzeit außerhalb der Arbeitszeit';
  }

  @override
  String get warnQuota =>
      'Ein weiterer Homeoffice-Tag würde das Kontingent überschreiten';

  @override
  String weekNumber(String number) {
    return 'KW $number';
  }

  @override
  String get weekTotal => 'Woche';

  @override
  String get sessions => 'Arbeitszeiten';

  @override
  String get breaks => 'Pausen';

  @override
  String get projectEntries => 'Projektzeiten';

  @override
  String get add => 'Hinzufügen';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get delete => 'Löschen';

  @override
  String get save => 'Speichern';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get start => 'Beginn';

  @override
  String get end => 'Ende';

  @override
  String get running => 'läuft';

  @override
  String get absence => 'Abwesenheit';

  @override
  String get absences => 'Abwesenheiten';

  @override
  String get absenceVacation => 'Urlaub';

  @override
  String get absenceSick => 'Krank';

  @override
  String get absenceSpecialLeave => 'Sonderurlaub';

  @override
  String get absenceCompTime => 'Überstundenabbau';

  @override
  String get absenceExtraHoliday => 'Freier Tag';

  @override
  String get halfDay => 'Halber Tag';

  @override
  String get addAbsence => 'Abwesenheit eintragen';

  @override
  String get trips => 'Reisen';

  @override
  String get newTrip => 'Neue Reise';

  @override
  String get holiday => 'Feiertag';

  @override
  String get tripDay => 'Reise';

  @override
  String get newProject => 'Neues Projekt';

  @override
  String get editProject => 'Projekt bearbeiten';

  @override
  String get projectName => 'Name';

  @override
  String get projectNumber => 'Projektnummer';

  @override
  String get orderNumber => 'Auftragsnummer';

  @override
  String get client => 'Kunde';

  @override
  String get favorite => 'Favorit';

  @override
  String get archived => 'Archiviert';

  @override
  String get searchProjects => 'Name, Projekt- oder Auftragsnummer';

  @override
  String get showArchived => 'Archivierte anzeigen';

  @override
  String createProjectNamed(String name) {
    return 'Projekt „$name“ anlegen';
  }

  @override
  String get noProjects => 'Noch keine Projekte';

  @override
  String get federalState => 'Bundesland';

  @override
  String get notSet => 'Nicht festgelegt';

  @override
  String get schedules => 'Arbeitszeitmodelle';

  @override
  String get newSchedule => 'Neues Modell';

  @override
  String get validFrom => 'Gültig ab';

  @override
  String get hoursPerWeekday => 'Stunden je Wochentag (Std:Min)';

  @override
  String get vacationDays => 'Urlaubstage pro Jahr';

  @override
  String perWeekSummary(String hours, String days) {
    return '$hours pro Woche, $days Urlaubstage';
  }

  @override
  String get breakRule => 'Fehlende Pausen';

  @override
  String get breakWarn => 'Nur warnen';

  @override
  String get breakDeduct => 'Automatisch abziehen';

  @override
  String get startingBalance => 'Übertrag (Std:Min, auch negativ)';

  @override
  String get balanceStart => 'Saldo zählt ab';

  @override
  String get homeOfficeRules => 'Homeoffice-Regeln';

  @override
  String get newRule => 'Neue Regel';

  @override
  String get perWeek => 'pro Woche';

  @override
  String get perMonth => 'pro Monat';

  @override
  String get maxPercent => 'Max. Anteil in %';

  @override
  String get basisWorked => 'der gearbeiteten Tage';

  @override
  String get basisScheduled => 'der Soll-Arbeitstage';

  @override
  String ruleSummary(String percent, String period, String basis) {
    return '$percent % $period $basis';
  }

  @override
  String get travelRules => 'Reiseregeln';

  @override
  String get saturdayCap => 'Samstag auf Reise: max. Stunden';

  @override
  String get autoClockIn => 'Beim Projektstart automatisch einstempeln';

  @override
  String get resumeAfterBreak => 'Nach der Pause Projekt fortsetzen';

  @override
  String get general => 'Allgemein';

  @override
  String vacationLeft(String year, String remaining, String total) {
    return 'Urlaub $year: noch $remaining von $total Tagen';
  }

  @override
  String vacationTakenPlanned(String taken, String planned) {
    return '$taken genommen, $planned geplant';
  }

  @override
  String get deleteQuestion => 'Diesen Eintrag löschen?';

  @override
  String get endBeforeStart => 'Das Ende muss nach dem Beginn liegen';

  @override
  String get required => 'Pflichtfeld';

  @override
  String get invalidValue => 'Ungültiger Wert';

  @override
  String get nothingRecorded => 'Nichts erfasst';

  @override
  String get previousWeek => 'Vorherige Woche';

  @override
  String get nextWeek => 'Nächste Woche';

  @override
  String get thisWeek => 'Diese Woche';

  @override
  String get from => 'Von';

  @override
  String get to => 'Bis';
}
