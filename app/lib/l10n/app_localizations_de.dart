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
  String get worked => 'Geleistet';

  @override
  String get target => 'Soll';

  @override
  String get credited => 'Angerechnet';

  @override
  String get difference => 'Saldo ±';

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
  String get absenceSpecialLeave => 'Feier-/Trauertag';

  @override
  String get absenceCompTime => 'Gleitzeit';

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
    return 'Neues Projekt „$name“ anlegen';
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
  String get travelRules => 'Anrechnung auf Reisen';

  @override
  String get autoClockIn => 'Beim Projektstart automatisch einstempeln';

  @override
  String get resumeAfterBreak => 'Nach der Pause Projekt fortsetzen';

  @override
  String get askStampTime => 'Uhrzeit beim Stempeln abfragen';

  @override
  String get askStampTimeHint =>
      'Beim Ein- und Ausstempeln und bei Pausen; vorgeschlagen ist die aktuelle Uhrzeit';

  @override
  String get stampTimeFuture => 'Die Uhrzeit liegt in der Zukunft.';

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

  @override
  String get sync => 'Synchronisation';

  @override
  String get syncIntro =>
      'Synchronisiere dieses Gerät über deine Nextcloud mit deinen anderen Geräten. Alle Daten werden vor dem Hochladen mit einer Sync-Passphrase Ende-zu-Ende-verschlüsselt.';

  @override
  String get syncServer => 'Nextcloud-Adresse';

  @override
  String get syncManual => 'Login-Namen und App-Passwort selbst eingeben';

  @override
  String get syncLoginName => 'Login-Name';

  @override
  String get syncAppPassword => 'App-Passwort';

  @override
  String get syncConnect => 'Verbinden';

  @override
  String get syncWaitingForLogin =>
      'Bitte bestätige die Anmeldung im Browser und kehre dann zu TimeTrack zurück …';

  @override
  String get syncLoginTimeout =>
      'Die Anmeldung wurde nicht rechtzeitig bestätigt.';

  @override
  String get syncDerivingKey =>
      'Schlüssel wird berechnet … das kann einige Sekunden dauern.';

  @override
  String get syncWrongPassphrase => 'Falsche Sync-Passphrase.';

  @override
  String get syncPassphrase => 'Sync-Passphrase';

  @override
  String get syncPassphraseNew =>
      'Wähle eine Passphrase. Du brauchst sie einmal auf jedem weiteren Gerät. Ohne sie sind die Daten in der Nextcloud nicht lesbar.';

  @override
  String get syncPassphraseJoin =>
      'Gib die Passphrase ein, die du auf deinem ersten Gerät gewählt hast.';

  @override
  String get syncPassphraseRepeat => 'Passphrase wiederholen';

  @override
  String get syncPassphraseShort => 'Mindestens 8 Zeichen';

  @override
  String get syncPassphraseMismatch => 'Die Passphrasen stimmen nicht überein';

  @override
  String syncLastSuccess(String time) {
    return 'Zuletzt synchronisiert um $time';
  }

  @override
  String get syncNow => 'Jetzt synchronisieren';

  @override
  String get syncDisconnect => 'Verbindung trennen';

  @override
  String get syncNotConnected => 'Nicht verbunden';

  @override
  String get syncError => 'Synchronisation fehlgeschlagen';

  @override
  String get syncProxy => 'Proxy für dieses Gerät (optional, Host:Port)';

  @override
  String get navReports => 'Berichte';

  @override
  String get timesheet => 'Stundenzettel';

  @override
  String get orderReport => 'Auftragsbericht';

  @override
  String get travelReport => 'Reisebericht';

  @override
  String get statistics => 'Statistik';

  @override
  String get backupJson => 'Sicherung aller Daten (JSON)';

  @override
  String savedTo(String path) {
    return 'Gespeichert: $path';
  }

  @override
  String get colDate => 'Datum';

  @override
  String get colBreak => 'Pause';

  @override
  String get colNotes => 'Hinweise';

  @override
  String get balanceBefore => 'Saldo Monatsanfang';

  @override
  String get balanceAfter => 'Saldo Monatsende';

  @override
  String get homeOfficeDays => 'Homeoffice-Tage';

  @override
  String get vacationDaysTaken => 'Urlaubstage';

  @override
  String get workedDays => 'Arbeitstage';

  @override
  String get signature => 'Datum, Unterschrift';

  @override
  String get perDiem => 'Verpflegungsmehraufwand';

  @override
  String get perDiemPartial => 'An-/Abreise bzw. > 8 Std.';

  @override
  String get perDiemFull => 'ganzer Tag';

  @override
  String get perDiemNone => 'keine Pauschale';

  @override
  String get mealsProvided => 'Gestellte Mahlzeiten';

  @override
  String get breakfast => 'Frühstück';

  @override
  String get lunch => 'Mittagessen';

  @override
  String get dinner => 'Abendessen';

  @override
  String get hoursAway => 'Abwesenheit';

  @override
  String get amount => 'Betrag';

  @override
  String get total => 'Summe';

  @override
  String get noTrips => 'Keine Reisen in diesem Monat';

  @override
  String get noBookings => 'Keine Projektzeiten in diesem Monat';

  @override
  String rateMissing(String country) {
    return 'Kein Satz für $country';
  }

  @override
  String get hoursByProject => 'Stunden nach Projekt';

  @override
  String get weeks => 'Wochen';

  @override
  String get previousMonth => 'Vorheriger Monat';

  @override
  String get nextMonth => 'Nächster Monat';

  @override
  String generatedBy(String date) {
    return 'Erstellt mit TimeTrack am $date';
  }

  @override
  String get addProjectTime => 'Projektzeit eintragen';

  @override
  String get durationHours => 'Dauer (Std:Min)';

  @override
  String get withClockTime => 'Startzeit angeben';

  @override
  String get withClockTimeHint =>
      'Optional – ohne Startzeit zählt nur die Dauer';

  @override
  String get summary => 'Zusammenfassung';

  @override
  String get summaryHint => 'Was hast du gemacht?';

  @override
  String summaryQuestion(String project) {
    return 'Was hast du für $project gemacht?';
  }

  @override
  String get skip => 'Überspringen';

  @override
  String get activity => 'Tätigkeit';

  @override
  String warnProjectOverWork(String minutes) {
    return '$minutes mehr Projektzeit als Arbeitszeit';
  }

  @override
  String get switchProject => 'Projekt wechseln';

  @override
  String get quickWorking => 'Bei der Arbeit';

  @override
  String get quickOnBreak => 'In der Pause';

  @override
  String get quickToday => 'Heute';

  @override
  String get travelSunday => 'Sonntage';

  @override
  String get travelSundayHoursHint =>
      'Arbeit und Reise zählen als Sonn-/Feiertagsstunden für die Personalabteilung (Monatsbericht), nicht als Überstunden.';

  @override
  String get travelSundayWorkOnlyHint =>
      'Arbeit zählt als Überstunden, Reisezeit zählt nicht.';

  @override
  String get sundayHours => 'Sonn-/Feiertagsstunden';

  @override
  String get sundayWorkOnly => 'Nur Arbeit';

  @override
  String get sundayCap => 'Sonn-/Feiertagsstunden: max. pro Tag';

  @override
  String get travelHoliday => 'Feiertage';

  @override
  String get likeSunday => 'Wie Sonntag';

  @override
  String get likeSaturday => 'Wie Samstag';

  @override
  String get weekendRules => 'Wochenende und Feiertage';

  @override
  String breakDeducted(String minutes) {
    return 'Fehlende Pause abgezogen: $minutes';
  }

  @override
  String get timesheetLegend =>
      'Geleistet: tatsächlich gearbeitete Zeit. Angerechnet: Zeit, die ins Stundenkonto eingeht; auf Reisen, am Wochenende und an Feiertagen nach den Regeln in den Einstellungen (Arbeit an Sonn- und Feiertagen steht gesondert als Sonn-/Feiertagsstunden). Saldo ± = Angerechnet − Soll.';

  @override
  String get tripProjectNone => 'Kein Projekt (optional)';

  @override
  String get colProject => 'Projekt';

  @override
  String get preview => 'Vorschau und Download';

  @override
  String get tripNoProject => 'Reise ohne Projekt';

  @override
  String tripBookedTo(String project) {
    return 'Gebucht auf $project';
  }

  @override
  String get tripDays => 'Reisetage';

  @override
  String get dayBusinessTrip => 'Dienstreise';

  @override
  String get absenceChildSick => 'Kinderkrankentag';

  @override
  String get absenceShortTime => 'Kurzarbeit';

  @override
  String get dayType => 'Tagesart';

  @override
  String tripDayLocked(String trip) {
    return 'Dieser Tag gehört zur Reise $trip. Um ihn als Büro- oder Homeoffice-Tag zu führen, passe zuerst die Reise an.';
  }

  @override
  String get editTrip => 'Reise bearbeiten';

  @override
  String tripTimes(String travel, String onSite) {
    return 'Unterwegs $travel · Vor Ort $onSite';
  }

  @override
  String get absenceWorkHint =>
      'Arbeitszeit an diesem Tag wird als Überstunden gutgeschrieben.';

  @override
  String get goToToday => 'Zu heute springen';

  @override
  String assignedTo(String minutes, String project) {
    return '$minutes auf $project gebucht';
  }

  @override
  String get back => 'Zurück';

  @override
  String get chooseDayType => 'Tagesart';

  @override
  String get commandPalette => 'Suche und Aktionen';

  @override
  String get commandPaletteHint => 'Aktion, Ansicht oder Projekt …';

  @override
  String get copiedPreviousDay => 'Vortag kopiert';

  @override
  String get copyPreviousDay => 'Vortag kopieren';

  @override
  String get deleted => 'Gelöscht';

  @override
  String get done => 'Fertig';

  @override
  String get editDay => 'Tag bearbeiten';

  @override
  String get explainAbsenceCredit => 'Gutschrift Abwesenheit';

  @override
  String get explainBreakDeducted => 'Pause abgezogen';

  @override
  String get explainBreakDeductedHint =>
      'Die vorgeschriebene Pause fehlte (ArbZG §4).';

  @override
  String get explainDeltaMinus =>
      'Weniger als das Soll: das senkt dein Stundenkonto.';

  @override
  String get explainDeltaPlus =>
      'Mehr als das Soll: das zählt als Überstunden.';

  @override
  String get explainDeltaZero =>
      'Genau das Soll: keine Überstunden, kein Minus.';

  @override
  String get explainHow => 'Wie wird das berechnet?';

  @override
  String get explainRule => 'Regel für diesen Tag';

  @override
  String get explainSaturday =>
      'Samstag: die Arbeitszeit zählt als Überstunden.';

  @override
  String explainSaturdayCapped(String cap, String rest) {
    return 'Samstag: höchstens $cap zählen, $rest werden nicht angerechnet.';
  }

  @override
  String get explainSundayCounted =>
      'Sonn-/Feiertagsregel: Arbeit vor Ort zählt normal.';

  @override
  String get explainSundayHours =>
      'Werden an die Personalabteilung gemeldet (Zuschlag), nicht Teil des Stundenkontos.';

  @override
  String explainSundayNotCounted(String rest) {
    return 'Sonn-/Feiertagsregel: $rest zählen nicht ins Stundenkonto.';
  }

  @override
  String get explainTargetDayOff =>
      'An diesem Tag ist keine Arbeit vorgesehen.';

  @override
  String explainTargetHoliday(String name) {
    return 'Feiertag $name: kein Soll.';
  }

  @override
  String get explainTargetReduced =>
      'Gesenkt durch Kurzarbeit oder einen zusätzlichen freien Tag.';

  @override
  String get explainTargetSchedule => 'Aus deiner Arbeitszeitregelung.';

  @override
  String explainTitle(String date) {
    return 'So wird $date gezählt';
  }

  @override
  String explainTripWorkday(String credit) {
    return 'Serviceeinsatz an einem Werktag: zählt als normaler Arbeitstag ($credit), egal wie lange.';
  }

  @override
  String get fixAddBreak => 'Pause eintragen';

  @override
  String get fixAssign => 'Zuordnen';

  @override
  String get fixSetEnd => 'Ende setzen';

  @override
  String homeOfficeLimit(String percent) {
    return 'Grenze: $percent % pro Monat';
  }

  @override
  String homeOfficeOfWorked(String home, String worked) {
    return '$home von $worked Arbeitstagen zu Hause';
  }

  @override
  String get month => 'Monat';

  @override
  String get more => 'Mehr';

  @override
  String get next => 'Weiter';

  @override
  String get noLimit => 'Keine Grenze';

  @override
  String ofTarget(String target) {
    return 'von $target';
  }

  @override
  String get openDay => 'Tag öffnen';

  @override
  String percentPerMonth(String percent) {
    return '$percent % pro Monat';
  }

  @override
  String perDaySummary(String minutes) {
    return 'Das sind $minutes pro Arbeitstag.';
  }

  @override
  String get quickEntry => 'Schnell erfassen';

  @override
  String get quickEntryHelp =>
      'Zeiten, Pause (p30), Ort (@home), Projekt, Notiz nach \": \"';

  @override
  String get quickEntryInvalid =>
      'Zeiten wie 8-16:30 oder eine Dauer wie 1:30 angeben';

  @override
  String quickEntryNoProject(String query) {
    return 'kein Projekt passt zu „$query“';
  }

  @override
  String get quickEntrySaved => 'Eingetragen';

  @override
  String get saveAsTemplate => 'Tag als Vorlage speichern';

  @override
  String get searchSettings => 'Einstellungen durchsuchen';

  @override
  String get setupAgainHint =>
      'Bundesland, Arbeitszeit, Konto und Homeoffice in vier Schritten';

  @override
  String get setupBalanceHint =>
      'Ab welchem Tag zählt das Stundenkonto, und was bringst du mit?';

  @override
  String get setupConnectSync => 'Nextcloud verbinden';

  @override
  String get setupDone => 'Fertig eingerichtet';

  @override
  String get setupDoneHint =>
      'Du kannst alles später in den Einstellungen ändern. Verbinde Nextcloud, um deine Geräte abzugleichen.';

  @override
  String get setupHomeOfficeHint =>
      'Wie viel Homeoffice erlaubt dein Arbeitgeber?';

  @override
  String get setupScheduleHint =>
      'Deine vertragliche Arbeitszeit und dein Urlaub.';

  @override
  String get setupStart => 'Einrichten';

  @override
  String get setupStateHint => 'Für die Feiertage.';

  @override
  String get setupTitle => 'Einrichtung';

  @override
  String get startingBalanceHint =>
      'Übertrag aus dem bisherigen Stundenkonto, z. B. 12:30 oder -2:00';

  @override
  String startProjectNamed(String project) {
    return '$project starten';
  }

  @override
  String get syncing => 'Synchronisiere …';

  @override
  String templateApplied(String name) {
    return 'Vorlage „$name“ eingetragen';
  }

  @override
  String get templateName => 'Name';

  @override
  String get timeline => 'Zeitleiste';

  @override
  String get timelineHint =>
      'Ränder ziehen zum Anpassen, schraffierte Lücke antippen zum Zuordnen.';

  @override
  String get tripStillOpen => 'Reise läuft noch';

  @override
  String tripStillOpenTo(String destination) {
    return 'Reise nach $destination läuft noch';
  }

  @override
  String get undo => 'Rückgängig';

  @override
  String get vacationCarryOver => 'Resturlaub aus dem Vorjahr (Tage)';

  @override
  String get vacationDaysPerYear => 'Urlaubstage pro Jahr';

  @override
  String warnUnassigned(String minutes) {
    return '$minutes ohne Projekt';
  }

  @override
  String get week => 'Woche';

  @override
  String get weeklyHours => 'Stunden pro Woche';

  @override
  String get workdaysPerWeek => 'Arbeitstage pro Woche';

  @override
  String get showLess => 'Weniger anzeigen';

  @override
  String moreNotices(String count) {
    return '$count weitere Hinweise';
  }

  @override
  String get noticeUnassignedFrom => '„Ohne Projekt“ ab';

  @override
  String get noticeUnassignedHint =>
      'Tage mit weniger Zeit ohne Projekt bekommen keinen Hinweis.';

  @override
  String get noticeCatUnassigned => 'Zeit ohne Projekt';

  @override
  String get noticeCatBreaks => 'Fehlende Pause (ArbZG §4)';

  @override
  String get noticeCatLongDay => 'Mehr als 10 Stunden (ArbZG §3)';

  @override
  String get noticeCatRest => 'Ruhezeit unter 11 Stunden (ArbZG §5)';

  @override
  String get noticeCatSunday => 'Arbeit an Sonn- und Feiertagen';

  @override
  String get noticeCatOpenSession => 'Vergessenes Ausstempeln';

  @override
  String get noticeCatOverlaps => 'Überlappende Einträge';

  @override
  String get noticeCatProjectTime =>
      'Projektzeit außerhalb oder über der Arbeitszeit';

  @override
  String get noticeCatQuota => 'Homeoffice-Grenze';

  @override
  String get noticeCatOpenTrip => 'Reise läuft noch';

  @override
  String get restoreNotices => 'Weggeklickte Hinweise wieder anzeigen';

  @override
  String dismissedCount(String count) {
    return '$count weggeklickt';
  }

  @override
  String get noticeDismissed =>
      'Hinweis ausgeblendet, im Kalender bleibt ein kleiner Marker';

  @override
  String hiddenNotices(String count) {
    return '$count ausgeblendete Hinweise';
  }

  @override
  String get noticeCategoryOff => 'In den Einstellungen ausgeschaltet';

  @override
  String get showAgain => 'Wieder anzeigen';

  @override
  String get hasNotices => 'Hat Hinweise';

  @override
  String get bookProjectTime => 'Projektzeit buchen';

  @override
  String get editProjectTime => 'Projektzeit bearbeiten';

  @override
  String get projectSearchHint => 'Projekt: Name, Nummer, Auftrag, Kunde …';

  @override
  String get recentlyUsed => 'Zuletzt verwendet';

  @override
  String get changeProject => 'Projekt ändern';

  @override
  String get duration => 'Dauer';

  @override
  String restOfDay(String minutes) {
    return 'Rest des Tages $minutes';
  }

  @override
  String get whatWasDone => 'Was wurde gemacht?';

  @override
  String get book => 'Buchen';

  @override
  String get legOutbound => 'Anfahrt';

  @override
  String get legOnSite => 'Beim Kunden';

  @override
  String get legInbound => 'Rückfahrt';

  @override
  String get creditedAccount => 'Angerechnet (Konto)';

  @override
  String get travelRecord => 'Reisenachweis';

  @override
  String get travelRecordEmpty =>
      'Noch keine Zeiten für Anfahrt, beim Kunden oder Rückfahrt.';

  @override
  String accountCredits(String minutes) {
    return 'Arbeitszeitkonto: $minutes angerechnet';
  }

  @override
  String get accountSection => 'Arbeitszeitkonto';

  @override
  String get stepStartOutbound => 'Anfahrt starten';

  @override
  String get stepArriveOnSite => 'Beim Kunden angekommen';

  @override
  String get stepEndOutbound => 'Anfahrt beenden';

  @override
  String get stepStartOnSite => 'Beim Kunden beginnen';

  @override
  String get stepEndOnSite => 'Beim Kunden fertig';

  @override
  String get stepStartInbound => 'Rückfahrt starten';

  @override
  String get stepEndInbound => 'Rückfahrt beenden';

  @override
  String get travelRulesHint =>
      'Nur fürs Arbeitszeitkonto. Im Reisenachweis stehen immer die genauen Zeiten von Anfahrt, beim Kunden und Rückfahrt.';

  @override
  String get weekendRulesHint =>
      'Für jeden Samstag, Sonntag und Feiertag, ob auf Reise oder nicht. Nur fürs Arbeitszeitkonto.';

  @override
  String get backAgainToLeave => 'Zum Verlassen nochmal zurück';

  @override
  String get perDiemRates => 'Tagespauschalen';

  @override
  String get perDiemRatesHint =>
      'Die BMF-Sätze aller Länder und Städte ab 2026 sind eingebaut; die Suche zeigt sie. Jeder Reisetag nutzt den neuesten Satz seines Orts, der an dem Tag gilt; eigene Sätze ersetzen die eingebauten. Gestellte Mahlzeiten mindern ihn: Frühstück um 20 %, Mittag- und Abendessen um je 40 % des Satzes für den ganzen Tag.';

  @override
  String perDiemRatesSummary(String count) {
    return '$count Länder';
  }

  @override
  String get partialDayRate => 'Teiltag (mehr als 8 h, An- oder Abreise)';

  @override
  String get fullDayRate => 'Ganzer Tag (24 h)';

  @override
  String get newRate => 'Neuer Satz';

  @override
  String get countryIso => 'Land (ISO-Code, z. B. AT)';

  @override
  String get builtInRate => 'Voreinstellung';

  @override
  String get rateInUse => 'gilt heute';

  @override
  String rateAmounts(String partial, String full) {
    return '$partial Teiltag · $full ganzer Tag';
  }

  @override
  String get restoreBackup => 'Sicherung laden';

  @override
  String get restoreBackupHint =>
      'Aus einer JSON-Sicherung wiederherstellen; du wählst, wie';

  @override
  String get notABackup =>
      'Diese Datei ist keine TimeTrack-Sicherung, die diese Version lesen kann.';

  @override
  String restoreFrom(String date, String count) {
    return 'Sicherung vom $date · $count Einträge';
  }

  @override
  String get restoreChoose => 'Wie soll die Sicherung geladen werden?';

  @override
  String get restoreMerge => 'Zusammenführen';

  @override
  String get restoreMergeHint =>
      'Wie ein Sync: Was fehlt, kommt aus der Sicherung zurück; alles später Geänderte bleibt erhalten.';

  @override
  String get restoreReplace => 'Ersetzen';

  @override
  String get restoreReplaceHint =>
      'Deine Daten werden genau zur Sicherung – auf allen Geräten. Alles, was nach der Sicherung eingetragen oder geändert wurde, geht verloren.';

  @override
  String restoreCounts(String added, String changed, String deleted) {
    return '$added zurück · $changed geändert · $deleted gelöscht';
  }

  @override
  String get restoreNoChange => 'keine Änderungen';

  @override
  String get restoreSyncFailed =>
      'Sync fehlgeschlagen: Einträge anderer Geräte, die noch nicht angekommen sind, werden nicht berücksichtigt.';

  @override
  String get restoreTip => 'Tipp: Speichere vorher eine aktuelle Sicherung.';

  @override
  String restoreDone(String counts) {
    return 'Sicherung geladen: $counts';
  }

  @override
  String get syncLog => 'Sync-Protokoll';

  @override
  String get syncLogHint => 'Nur auf diesem Gerät, die letzten 100 Läufe';

  @override
  String get syncLogEmpty => 'Noch keine Sync-Läufe.';

  @override
  String get syncLogIdle => 'Nichts zu synchronisieren';

  @override
  String get syncLogFailed => 'Fehlgeschlagen';

  @override
  String syncLogUp(String count) {
    return '↑ $count Änderungen gesendet';
  }

  @override
  String syncLogDown(String count) {
    return '↓ $count Änderungen empfangen';
  }

  @override
  String syncLogResolved(String count) {
    return '$count Einträge korrigiert';
  }

  @override
  String get syncLogBackground => 'im Hintergrund';

  @override
  String get syncLogClear => 'Protokoll leeren';

  @override
  String syncLogTimes(String count) {
    return '$count×';
  }

  @override
  String get syncLogNetwork => 'nach Netzwechsel';

  @override
  String updateAvailable(String version) {
    return 'TimeTrack $version ist verfügbar';
  }

  @override
  String get updateNotificationText =>
      'Tippen, um die Neuerungen zu sehen und zu aktualisieren.';

  @override
  String get updatesChannel => 'Updates';

  @override
  String get updateNow => 'Aktualisieren';

  @override
  String get updateWhatsNew => 'Was ist neu';

  @override
  String get updateLater => 'Später';

  @override
  String get updateSkip => 'Diese Version überspringen';

  @override
  String updateDownloading(String version, String percent) {
    return 'Lade TimeTrack $version … $percent';
  }

  @override
  String updateReady(String version) {
    return 'TimeTrack $version ist installiert. Starte neu, um es zu verwenden.';
  }

  @override
  String get updateRestart => 'Neu starten';

  @override
  String updateFailed(String error) {
    return 'Update fehlgeschlagen: $error';
  }

  @override
  String get updateRetry => 'Erneut versuchen';

  @override
  String get updateNeedsPermission =>
      'Erlaube TimeTrack „Unbekannte Apps installieren“ und tippe dann erneut auf „Aktualisieren“.';

  @override
  String get updateNoNotes => 'Keine Versionshinweise.';

  @override
  String get checkForUpdates => 'Nach Updates suchen';

  @override
  String installedVersion(String version) {
    return 'Installiert: $version';
  }

  @override
  String lastChecked(String when) {
    return 'zuletzt geprüft $when';
  }

  @override
  String get autoUpdateCheck => 'Automatisch nach Updates suchen';

  @override
  String get autoUpdateCheckHint =>
      'Höchstens einmal am Tag. Installiert wird nur nach Rückfrage.';

  @override
  String get upToDate => 'TimeTrack ist aktuell.';

  @override
  String get updateCheckFailed => 'Keine Verbindung zu GitHub.';

  @override
  String get releasePage => 'Alle Versionen auf GitHub';

  @override
  String get workPc => 'Arbeits-PC';

  @override
  String get workPcHint =>
      'Fragt nach dem Anmelden an Windows, ob das Tracking für heute starten soll (schaltet „Mit Windows starten“ mit ein).';

  @override
  String get workPcFailed => 'Der Windows-Autostart ließ sich nicht ändern.';

  @override
  String get startTrackingTitle => 'Tracking für heute starten?';

  @override
  String get startTrackingText => 'Heute ist noch keine Arbeitszeit erfasst.';

  @override
  String get startTrackingStart => 'Starten';

  @override
  String get startTrackingNotToday => 'Nicht heute';

  @override
  String get appearance => 'Design';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get wallpaperColors => 'Farben vom Hintergrundbild';

  @override
  String get wallpaperColorsHint => 'Aus: die Farben von TimeTrack.';

  @override
  String get keyboardShortcuts => 'Tastenkürzel';

  @override
  String get keysClock => 'Ein- oder ausstempeln';

  @override
  String get keysBreak => 'Pause starten oder beenden';

  @override
  String get keysTabs => 'Heute, Kalender, Projekte, Berichte';

  @override
  String get keysPrevNext => 'Vorherige oder nächste Woche, Monat oder Tag';

  @override
  String get keysWeekMonth => 'Zwischen Woche und Monat wechseln';

  @override
  String get keysHelp => 'Diese Übersicht';

  @override
  String forecastTarget(String time) {
    return 'Soll erreicht um $time';
  }

  @override
  String forecastBreak(int minutes) {
    return 'inkl. $minutes min Pause';
  }

  @override
  String forecastLimit(String time) {
    return '10 Std. um $time';
  }

  @override
  String get reminders => 'Erinnerungen';

  @override
  String get remindBreak => 'Pause fällig';

  @override
  String get remindBreakHint => 'Nach 5:45 Std. ohne Pause';

  @override
  String get remindLongDay => 'Langer Tag';

  @override
  String get remindLongDayHint => 'Bei 9:45 Std., bevor 10 Std. erreicht sind';

  @override
  String get reminderBreakTitle => 'Pause fällig';

  @override
  String get reminderBreakText =>
      'Seit 5:45 Std. ohne Pause – nach 6 Std. ist eine Pause Pflicht.';

  @override
  String get reminderLongDayTitle => 'Gleich 10 Stunden';

  @override
  String get reminderLongDayText =>
      'Noch eingestempelt? Mehr als 10 Std. Arbeit am Tag sind nicht erlaubt.';

  @override
  String get forgottenTitle => 'Noch eingestempelt?';

  @override
  String forgottenText(String since) {
    return 'Eingestempelt seit $since. Wann war Feierabend?';
  }

  @override
  String yesterdayAt(String time) {
    return 'gestern, $time';
  }

  @override
  String get suggestLastActivity => 'Letzte Aktivität';

  @override
  String get suggestTarget => 'Soll erreicht';

  @override
  String get suggestUsualEnd => 'Üblicher Feierabend';

  @override
  String get otherTime => 'Andere Zeit…';

  @override
  String get stillWorking => 'Ich arbeite noch';

  @override
  String forgottenTimeInvalid(String from) {
    return 'Bitte eine Zeit zwischen $from und jetzt wählen.';
  }

  @override
  String clockedOutAt(String time) {
    return 'Ausgestempelt um $time';
  }

  @override
  String get weekCheck => 'Woche prüfen';

  @override
  String get monthCheck => 'Monat prüfen';

  @override
  String noticeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Hinweise',
      one: '1 Hinweis',
    );
    return '$_temp0';
  }

  @override
  String noticeDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'an $count Tagen',
      one: 'an 1 Tag',
    );
    return '$_temp0';
  }

  @override
  String get weekComplete => 'Woche vollständig';

  @override
  String get monthComplete => 'Monat vollständig';

  @override
  String reviewStep(int index, int total) {
    return '$index von $total';
  }

  @override
  String get hideNotice => 'Ausblenden';

  @override
  String get allDone => 'Alles erledigt';

  @override
  String skippedCount(int count) {
    return '$count übersprungen';
  }

  @override
  String get projectBudget => 'Budget (Stunden)';

  @override
  String get projectBudgetHint => 'Leer: kein Budget';

  @override
  String get invalidHours => 'Stunden wie 40, 37,5 oder 37:30';

  @override
  String get noticeCatBudget => 'Projektbudget';

  @override
  String warnBudgetNear(String project, String budget) {
    return '$project: 80 % des Budgets ($budget) erreicht';
  }

  @override
  String warnBudgetOver(String project, String budget) {
    return '$project: Budget ($budget) überschritten';
  }

  @override
  String get openProject => 'Projekt öffnen';

  @override
  String get thisMonth => 'Dieser Monat';

  @override
  String get thisYear => 'Dieses Jahr';

  @override
  String budgetUsed(String used, String budget, int percent) {
    return '$used von $budget ($percent %)';
  }

  @override
  String budgetLeft(String left) {
    return 'noch $left';
  }

  @override
  String budgetOverBy(String over) {
    return '$over drüber';
  }

  @override
  String get projectHistory => 'Verlauf';

  @override
  String get lastTwelveWeeks => 'Letzte Wochen';

  @override
  String get startTimer => 'Timer starten';

  @override
  String get projectRunning => 'Läuft';

  @override
  String get noTimeBooked => 'Noch keine Zeit gebucht';

  @override
  String showAllDays(int count) {
    return 'Alle $count Tage zeigen';
  }

  @override
  String get archive => 'Archivieren';

  @override
  String get unarchive => 'Aus dem Archiv holen';

  @override
  String get budget => 'Budget';

  @override
  String get vacationPlanner => 'Urlaubsplaner';

  @override
  String get bridgeDays => 'Brückentage';

  @override
  String bridgeTitle(int count, int free) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Urlaubstage',
      one: '1 Urlaubstag',
    );
    return '$_temp0 → $free Tage frei';
  }

  @override
  String get bridgeBook => 'Eintragen';

  @override
  String get bridgeBooked => 'Urlaub eingetragen';

  @override
  String noBridges(int year) {
    return 'Keine Brückentage mehr in $year';
  }

  @override
  String absencesOfYear(int year) {
    return 'Abwesenheiten $year';
  }

  @override
  String get bridgeDay => 'Brückentag';

  @override
  String get otherAbsence => 'Andere Abwesenheit';

  @override
  String get trayOpen => 'TimeTrack öffnen';

  @override
  String get trayQuit => 'Beenden';

  @override
  String get closeToTray => 'Im Infobereich weiterlaufen';

  @override
  String get closeToTrayHint =>
      'Schließen blendet das Fenster aus; Beenden steht im Menü des Symbols.';

  @override
  String get defaultBreakStart => 'Übliche Pause: Beginn';

  @override
  String get defaultBreakLength => 'Übliche Pause: Dauer';

  @override
  String get defaultBreakHint => 'Vorschlag beim Eintragen einer Pause';

  @override
  String beforeBalanceStart(String date) {
    return 'Vor Beginn des Überstundensaldos ($date): kein Soll, keine Überstunden';
  }

  @override
  String get autostart => 'Mit Windows starten';

  @override
  String get autostartHint =>
      'Startet TimeTrack beim Anmelden an Windows (nur für diesen Benutzer).';

  @override
  String get removeDayType => 'Tagesart entfernen';

  @override
  String get dayTypeRemoved => 'Tagesart entfernt';

  @override
  String tripDayRemove(String trip) {
    return 'Dieser Tag gehört zur Reise $trip. Um ihn zu entfernen, passe die Reise an.';
  }

  @override
  String get bookingTransfer => 'An Buchungssystem übertragen';

  @override
  String get bookingSystem => 'Buchungssystem';

  @override
  String get bookingUrl => 'Buchungssystem (Adresse)';

  @override
  String get bookingUrlHint =>
      'Seite für Wochen-Projektzeiten; nur auf diesem PC gespeichert';

  @override
  String bookingPreviewTitle(String week) {
    return 'KW $week übertragen';
  }

  @override
  String get bookingOpen => 'Im Buchungssystem öffnen';

  @override
  String get bookingNoRows =>
      'Keine Projektzeit mit Projektnummer in dieser Woche.';

  @override
  String get bookingRunningTimer =>
      'Ein Projekt-Timer läuft noch; seine Zeit zählt bis jetzt.';

  @override
  String bookingUnassigned(String day, String time) {
    return '$day: $time ohne Projekt, wird nicht übertragen';
  }

  @override
  String bookingRounding(String rounded, String exact) {
    return 'Auf halbe Stunden gerundet: $rounded statt $exact';
  }

  @override
  String bookingSkipped(String name, String time) {
    return '$name ($time) hat keine Projektnummer und wird nicht übertragen';
  }

  @override
  String get bookingSum => 'Summe';

  @override
  String bookingTransferredOn(String date) {
    return 'Übertragen am $date';
  }

  @override
  String bookingChangedSince(String date) {
    return 'Seit der Übertragung am $date geändert';
  }

  @override
  String get bookingNotTransferred => 'Noch nicht übertragen';

  @override
  String get bookingLoading => 'Buchungsseite wird geöffnet…';

  @override
  String get bookingFilling => 'Wird ausgefüllt…';

  @override
  String bookingFilled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Zeilen',
      one: '1 Zeile',
    );
    return '$_temp0 ausgefüllt. Kostengruppe und Position ergänzen, Stunden prüfen, dann Buchen klicken.';
  }

  @override
  String bookingUnknownProjects(String projects) {
    return 'Im Buchungssystem unbekannt, nicht ausgefüllt: $projects';
  }

  @override
  String bookingLockedDays(String days) {
    return 'Buchungsperiode gesperrt, nicht ausgefüllt: $days';
  }

  @override
  String get bookingReplaceTitle => 'Einträge ersetzen?';

  @override
  String get bookingReplaceBody =>
      'Das Formular enthält schon Einträge. Durch diese Woche ersetzen?';

  @override
  String get bookingReplace => 'Ersetzen';

  @override
  String get bookingKept => 'Formular unverändert gelassen.';

  @override
  String get bookingBooked =>
      'Buchung gestartet; die Woche ist als übertragen markiert.';

  @override
  String get bookingAskBooked => 'Wurde die Woche gebucht?';

  @override
  String get bookingAskBookedBody =>
      'Wenn du auf Buchen geklickt hast, markiert TimeTrack die Woche als übertragen.';

  @override
  String get bookingWasBooked => 'Ja, gebucht';

  @override
  String get bookingNotBooked => 'Nein';

  @override
  String get bookingErrorTimeout =>
      'Die Buchungsseite wurde nicht innerhalb von 30 s bereit. Adresse und Firmennetz prüfen.';

  @override
  String bookingErrorPage(String detail) {
    return 'Die Seite sieht anders aus als erwartet ($detail); nichts ausgefüllt.';
  }

  @override
  String bookingErrorFill(String detail) {
    return 'Ausfüllen fehlgeschlagen: $detail';
  }

  @override
  String bookingErrorLoad(String detail) {
    return 'Die Seite konnte nicht geladen werden ($detail).';
  }

  @override
  String get bookingNoRuntime =>
      'Die Microsoft Edge WebView2 Runtime fehlt; bitte installieren.';

  @override
  String get bookingClose => 'Schließen';

  @override
  String get serviceTrip => 'Serviceeinsatz / Inbetriebnahme';

  @override
  String get serviceTripHint =>
      'Arbeit auf einer Baustelle: Werktage zählen das Soll, Samstage höchstens 8 Std.; die Mehrarbeit wird mit dem Zuschlag bezahlt. Aus bei Messe, Schulung oder Besprechung: Es zählt die tatsächliche Zeit, höchstens 10 Std.';

  @override
  String get serviceSaturdayCap => 'Samstag im Serviceeinsatz: max. Stunden';

  @override
  String get serviceSaturdayCapHint =>
      'Werktage eines Serviceeinsatzes zählen immer das Soll, Samstage die tatsächliche Zeit bis zu dieser Grenze.';

  @override
  String get dayCap => 'Andere Reisen und Samstage: max. Stunden';

  @override
  String get dayCapHint =>
      'Dienstreisen ohne Serviceeinsatz und Samstage ohne Reise: die tatsächliche Zeit, Reise eingeschlossen, höchstens bis zu dieser Grenze.';

  @override
  String get servicePayDays => 'Tage mit Reisezuschlag';

  @override
  String explainOtherTripWorkday(String cap) {
    return 'Dienstreise ohne Serviceeinsatz: Es zählt die tatsächliche Zeit, Reise eingeschlossen, höchstens $cap.';
  }

  @override
  String get copy => 'Kopieren';

  @override
  String get copied => 'Kopiert';

  @override
  String monthReportTitle(String month) {
    return 'Überstundenkonto für $month melden';
  }

  @override
  String monthReportText(String date, String balance) {
    return 'Stand zum $date: $balance. Bitte im Firmensystem eintragen.';
  }

  @override
  String get monthReportReminder => 'Erinnerung: Überstunden melden';

  @override
  String get monthReportReminderHint =>
      'Erinnert nach dem Monatswechsel an den Kontostand zum Monatsende';

  @override
  String get noticeCatBalanceZone => 'Zeitkonto-Ampel';

  @override
  String warnBalanceYellow(String balance) {
    return 'Zeitkonto im gelben Bereich ($balance)';
  }

  @override
  String warnBalanceRed(String balance) {
    return 'Zeitkonto im roten Bereich ($balance)';
  }

  @override
  String warnBalanceOverLimit(String balance) {
    return 'Zeitkonto über der Höchstgrenze ($balance)';
  }

  @override
  String get zoneGreen => 'Grüner Bereich';

  @override
  String get zoneYellow => 'Gelber Bereich';

  @override
  String get zoneRed => 'Roter Bereich';

  @override
  String get zoneOverLimit => 'Über der Höchstgrenze';

  @override
  String get zoneYellowFrom => 'Gelb ab';

  @override
  String get zoneRedFrom => 'Rot ab';

  @override
  String get zoneMax => 'Grenze';

  @override
  String get zonePlus => 'Plus';

  @override
  String get zoneMinus => 'Minus';

  @override
  String get balanceZones => 'Zeitkonto-Ampel';

  @override
  String get balanceZonesHint =>
      'Aus · Grenzen deines Arbeitgebers für Grün/Gelb/Rot';

  @override
  String get balanceZonesDialogHint =>
      'Ganze Stunden über (Plus) bzw. unter (Minus) dem Soll. Leer: keine Grenze.';

  @override
  String get vacationCarryDeadline => 'Resturlaub nehmen bis';

  @override
  String get vacationCarryDeadlineHint =>
      'Zeigt auf Heute, wie viele Tage davon noch nicht verplant sind';

  @override
  String get deadlineOff => 'Aus';

  @override
  String deadlineEndOf(String month) {
    return 'Ende $month';
  }

  @override
  String vacationCarryTitle(String year) {
    return 'Resturlaub aus $year';
  }

  @override
  String vacationCarryText(String days, String date) {
    return 'Noch $days Tage bis $date nehmen oder verplanen.';
  }

  @override
  String vacationCarryOverInto(String year) {
    return 'Resturlaub-Übertrag nach $year';
  }

  @override
  String get sectionAccount => 'Arbeitszeit & Konto';

  @override
  String get sectionClocking => 'Stempeln & Pausen';

  @override
  String get sectionTravel => 'Reisen & Zuschläge';

  @override
  String get sectionApp => 'Darstellung & Updates';

  @override
  String get groupTarget => 'Sollzeit';

  @override
  String get groupVacation => 'Urlaub';

  @override
  String get groupClocking => 'Stempeln';

  @override
  String get groupBreaks => 'Pausen';

  @override
  String get groupExpenses => 'Spesen';

  @override
  String get groupDisplay => 'Darstellung';

  @override
  String get groupUpdates => 'Updates';

  @override
  String noticesActive(String on, String all) {
    return '$on von $all aktiv';
  }

  @override
  String get workPcSummary =>
      'Autostart, Infobereich, Monatserinnerung, Buchung';

  @override
  String get specialHolidayHours => 'Stunden an besonderen Feiertagen';

  @override
  String get nightHours => 'Nachtstunden';

  @override
  String get specialDays => 'Besondere Feiertage';

  @override
  String get specialDaysHint =>
      'Ihre Stunden werden getrennt von den Sonn-/Feiertagsstunden ausgewiesen, z. B. für einen höheren Zuschlag';

  @override
  String get specialDaysNone => 'Keine';

  @override
  String get specialDayNewYear => 'Neujahr';

  @override
  String get specialDayEasterSunday => 'Ostersonntag';

  @override
  String get specialDayEasterMonday => 'Ostermontag';

  @override
  String get specialDayMayDay => '1. Mai';

  @override
  String get specialDayWhitSunday => 'Pfingstsonntag';

  @override
  String get specialDayWhitMonday => 'Pfingstmontag';

  @override
  String get specialDayChristmasDay => '1. Weihnachtstag';

  @override
  String get specialDayBoxingDay => '2. Weihnachtstag';

  @override
  String get groupNightWork => 'Nachtarbeit';

  @override
  String get nightWorkCredit => 'Nachtstunden (23–6 Uhr, ab 2 Std.)';

  @override
  String get nightCount => 'Im Konto';

  @override
  String get nightExclude => 'Nicht im Konto';

  @override
  String get nightCountHint => 'Werden ausgewiesen und normal angerechnet.';

  @override
  String get nightExcludeHint =>
      'Werden ausgezahlt: ausgewiesen, aber nicht aufs Arbeitszeitkonto angerechnet. Werktage im Serviceeinsatz behalten ihr Soll.';

  @override
  String get explainNightExcluded =>
      'Werden ausgezahlt, nicht aufs Arbeitszeitkonto angerechnet.';

  @override
  String get explainNightCounted =>
      'Arbeit zwischen 23 und 6 Uhr in einer Nacht ab 2 Std.; wird für den Zuschlag gemeldet.';

  @override
  String get explainSpecialHolidayHours =>
      'Werden getrennt von den Sonn-/Feiertagsstunden gemeldet (höherer Zuschlag), nicht Teil des Stundenkontos.';

  @override
  String monthReportSupplements(String items) {
    return 'Zuschläge: $items.';
  }

  @override
  String get columnSpecialHours => 'Bes. FT';

  @override
  String get columnNightHours => 'Nacht';

  @override
  String get searchCountry => 'Land oder Stadt suchen';

  @override
  String get restOfCountry => 'Übriges Land';

  @override
  String get placeHint => 'Bestimmt Tages- und Übernachtungspauschale';

  @override
  String get otherPlaces => 'Weitere Orte';

  @override
  String placeFrom(String date) {
    return 'Ab $date';
  }

  @override
  String get changePlace => 'Ort wechseln';

  @override
  String get changePlaceFrom => 'Ab welchem Tag?';

  @override
  String get lodging => 'Übernachtung';

  @override
  String get lodgingCompany => 'Firma';

  @override
  String get lodgingFlat => 'Pauschale';

  @override
  String get lodgingReceipt => 'Beleg';

  @override
  String get lodgingReceiptTotal => 'Belege gesamt';

  @override
  String get lodgingFlatHint =>
      'Keine Pauschale für Nächte im Flugzeug, Zug oder Schiff.';

  @override
  String get lodgingRate => 'Übernachtung je Nacht (optional)';

  @override
  String get carKm => 'Privat-Pkw';

  @override
  String get markClaimed => 'Abgerechnet';

  @override
  String claimedOn(String date) {
    return 'Abgerechnet am $date';
  }

  @override
  String claimTitle(String trip, String date) {
    return 'Reisekosten $trip abrechnen bis $date';
  }

  @override
  String get tripExpenses => 'Reiseabrechnung';

  @override
  String get place => 'Ort';

  @override
  String get siteAllowance => 'Baustellenzulage';

  @override
  String get siteAllowanceHint =>
      'Die Baustellenzulage wird mit dem Gehalt gezahlt (zu versteuern), nicht mit der Reisekostenabrechnung.';

  @override
  String get siteAllowanceRatesHint =>
      'Je Baustellentag eines Serviceeinsatzes, vom ersten bis zum letzten Baustellentag, sobald genug aufeinanderfolgen. Land * gilt für alle übrigen.';

  @override
  String siteAllowanceSummary(String days) {
    return 'Ab $days Baustellentagen in Folge';
  }

  @override
  String get siteAllowanceMinDays =>
      'Baustellenzulage ab … Baustellentagen in Folge';

  @override
  String get siteAllowanceCountryHint =>
      'ISO-Code, oder * für alle übrigen Länder';

  @override
  String get allOtherCountries => 'Alle übrigen Länder';

  @override
  String get perSiteDay => 'Je Baustellentag';

  @override
  String get mileageRate => 'Kilometergeld (Privat-Pkw)';

  @override
  String get mileage => 'Kilometergeld';

  @override
  String get laundryAfterDays => 'Wäschereinigung bei Reisen von';

  @override
  String get laundryHint =>
      'Für diese Reise kann die Wäschereinigung abgerechnet werden.';

  @override
  String moreThanDays(String days) {
    return 'mehr als $days Tagen';
  }

  @override
  String get claimDeadlineMonths => 'Reisekosten abrechnen innerhalb';

  @override
  String get claimDeadlineHint =>
      'Heute erinnert nach jeder Reise, bis sie als abgerechnet markiert ist';

  @override
  String get claimDeadline => 'Abrechnen bis';

  @override
  String monthsCount(String count) {
    return '$count Monaten';
  }

  @override
  String get claimTotal => 'Erstattung gesamt';

  @override
  String nightsCount(String count) {
    return '$count Nächte';
  }

  @override
  String daysCount(String count) {
    return '$count Tage';
  }

  @override
  String get cityOptional => 'Stadt (optional)';

  @override
  String get noticeCatWeekLimit => 'Wochengrenzen';

  @override
  String warnWeekOverMax(String minutes) {
    return 'Woche mit $minutes Arbeit: über der Wochenhöchstgrenze';
  }

  @override
  String warnWeekAverage(String minutes) {
    return 'Wochenschnitt $minutes: über der Grenze';
  }

  @override
  String weekWorkedOfMax(String worked, String max) {
    return 'Gearbeitet $worked von max. $max';
  }

  @override
  String weekAverageOf(String weeks, String average, String limit) {
    return 'Schnitt $weeks Wochen $average (Grenze $limit)';
  }

  @override
  String get groupWeekLimits => 'Wochengrenzen';

  @override
  String get weekMaxSetting => 'Höchstens pro Woche';

  @override
  String weekAverageSetting(String weeks) {
    return 'Schnitt über $weeks Wochen höchstens';
  }

  @override
  String get weekLimitsHint =>
      'Alle erfasste Arbeit inklusive Reisezeit, ohne Pausen (§ 3 ArbZG). 0 schaltet ab.';

  @override
  String get addWorkTime => 'Arbeitszeit eintragen';
}
