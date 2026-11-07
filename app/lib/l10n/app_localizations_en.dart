// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'TimeTrack';

  @override
  String get navToday => 'Today';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get navProjects => 'Projects';

  @override
  String get navSettings => 'Settings';

  @override
  String get clockIn => 'Clock in';

  @override
  String get clockOut => 'Clock out';

  @override
  String get startBreak => 'Break';

  @override
  String get endBreak => 'End break';

  @override
  String get notClockedIn => 'Not clocked in';

  @override
  String clockedInSince(String time) {
    return 'Clocked in since $time';
  }

  @override
  String onBreakSince(String time) {
    return 'On break since $time';
  }

  @override
  String get locationOffice => 'Office';

  @override
  String get locationHome => 'Home office';

  @override
  String get locationOnSite => 'On site';

  @override
  String get locationTravel => 'Travel';

  @override
  String get location => 'Location';

  @override
  String get worked => 'Worked';

  @override
  String get target => 'Target';

  @override
  String get credited => 'Credited';

  @override
  String get difference => 'Difference';

  @override
  String get balance => 'Overtime balance';

  @override
  String get balanceToday => 'incl. today';

  @override
  String get unassigned => 'Without project';

  @override
  String get chooseProject => 'Choose project';

  @override
  String get stopProject => 'Stop project';

  @override
  String get noProjectRunning => 'No project running';

  @override
  String homeOfficeWeek(String used, String allowed, String left) {
    return 'Home office this week: $used of $allowed days, $left left';
  }

  @override
  String homeOfficeMonth(String used, String allowed, String left) {
    return 'Home office this month: $used of $allowed days, $left left';
  }

  @override
  String get setupHint =>
      'Set your federal state and work schedule in the settings, so targets and balances are right.';

  @override
  String get openSettings => 'Open settings';

  @override
  String get startTrip => 'Start trip';

  @override
  String get endTrip => 'End trip';

  @override
  String onTripTo(String destination) {
    return 'On a trip to $destination';
  }

  @override
  String get onTrip => 'On a trip';

  @override
  String get startTripQuestion => 'Start a business trip?';

  @override
  String get endTripQuestion => 'Has the trip ended?';

  @override
  String get notNow => 'Not now';

  @override
  String get destination => 'Destination';

  @override
  String get country => 'Country code';

  @override
  String get overnight => 'With overnight stay';

  @override
  String get depart => 'Departure';

  @override
  String get returnTime => 'Return';

  @override
  String get notices => 'Notices';

  @override
  String warnBreakMissing(String minutes) {
    return '$minutes break missing (ArbZG §4)';
  }

  @override
  String get warnOver6h => 'More than 6 h without a break (ArbZG §4)';

  @override
  String get warnOver10h => 'More than 10 h worked (ArbZG §3)';

  @override
  String warnRest(String minutes) {
    return 'Only $minutes rest since the previous day (ArbZG §5)';
  }

  @override
  String get warnSunday => 'Work on a Sunday or public holiday';

  @override
  String get warnOpenSession =>
      'Clocked in for a long time – forgot to clock out?';

  @override
  String get warnOverlapSessions => 'Overlapping working times';

  @override
  String get warnOverlapProjects => 'Overlapping project times';

  @override
  String warnProjectOutside(String minutes) {
    return '$minutes project time outside working time';
  }

  @override
  String get warnQuota => 'Another home-office day would exceed your quota';

  @override
  String weekNumber(String number) {
    return 'Week $number';
  }

  @override
  String get weekTotal => 'Week';

  @override
  String get sessions => 'Working times';

  @override
  String get breaks => 'Breaks';

  @override
  String get projectEntries => 'Project times';

  @override
  String get add => 'Add';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get start => 'Start';

  @override
  String get end => 'End';

  @override
  String get running => 'running';

  @override
  String get absence => 'Absence';

  @override
  String get absences => 'Absences';

  @override
  String get absenceVacation => 'Vacation';

  @override
  String get absenceSick => 'Sick';

  @override
  String get absenceSpecialLeave => 'Special leave';

  @override
  String get absenceCompTime => 'Time off in lieu';

  @override
  String get absenceExtraHoliday => 'Day off';

  @override
  String get halfDay => 'Half day';

  @override
  String get addAbsence => 'Add absence';

  @override
  String get trips => 'Trips';

  @override
  String get newTrip => 'New trip';

  @override
  String get holiday => 'Public holiday';

  @override
  String get tripDay => 'Trip';

  @override
  String get newProject => 'New project';

  @override
  String get editProject => 'Edit project';

  @override
  String get projectName => 'Name';

  @override
  String get projectNumber => 'Project number';

  @override
  String get orderNumber => 'Order number';

  @override
  String get client => 'Client';

  @override
  String get favorite => 'Favorite';

  @override
  String get archived => 'Archived';

  @override
  String get searchProjects => 'Name, project or order number';

  @override
  String get showArchived => 'Show archived';

  @override
  String createProjectNamed(String name) {
    return 'Create project “$name”';
  }

  @override
  String get noProjects => 'No projects yet';

  @override
  String get federalState => 'Federal state';

  @override
  String get notSet => 'Not set';

  @override
  String get schedules => 'Work schedules';

  @override
  String get newSchedule => 'New schedule';

  @override
  String get validFrom => 'Valid from';

  @override
  String get hoursPerWeekday => 'Hours per weekday (h:mm)';

  @override
  String get vacationDays => 'Vacation days per year';

  @override
  String perWeekSummary(String hours, String days) {
    return '$hours per week, $days vacation days';
  }

  @override
  String get breakRule => 'Missing breaks';

  @override
  String get breakWarn => 'Warn only';

  @override
  String get breakDeduct => 'Deduct automatically';

  @override
  String get startingBalance => 'Starting balance (h:mm, may be negative)';

  @override
  String get balanceStart => 'Balance counted from';

  @override
  String get homeOfficeRules => 'Home-office rules';

  @override
  String get newRule => 'New rule';

  @override
  String get perWeek => 'per week';

  @override
  String get perMonth => 'per month';

  @override
  String get maxPercent => 'Max. share in %';

  @override
  String get basisWorked => 'of days worked';

  @override
  String get basisScheduled => 'of scheduled workdays';

  @override
  String ruleSummary(String percent, String period, String basis) {
    return '$percent % $period $basis';
  }

  @override
  String get travelRules => 'Travel rules';

  @override
  String get saturdayCap => 'Saturday on a trip: max. hours';

  @override
  String get autoClockIn => 'Clock in automatically when a project starts';

  @override
  String get resumeAfterBreak => 'Resume the project after a break';

  @override
  String get general => 'General';

  @override
  String vacationLeft(String year, String remaining, String total) {
    return 'Vacation $year: $remaining of $total days left';
  }

  @override
  String vacationTakenPlanned(String taken, String planned) {
    return '$taken taken, $planned planned';
  }

  @override
  String get deleteQuestion => 'Delete this entry?';

  @override
  String get endBeforeStart => 'The end must be after the start';

  @override
  String get required => 'Required';

  @override
  String get invalidValue => 'Invalid value';

  @override
  String get nothingRecorded => 'Nothing recorded';

  @override
  String get previousWeek => 'Previous week';

  @override
  String get nextWeek => 'Next week';

  @override
  String get thisWeek => 'This week';

  @override
  String get from => 'From';

  @override
  String get to => 'To';
}
