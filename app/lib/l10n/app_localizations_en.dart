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
  String get difference => 'Balance ±';

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
  String get absenceSpecialLeave => 'Celebration/bereavement';

  @override
  String get absenceCompTime => 'Flexitime';

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
    return 'New project \"$name\"';
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
  String get travelRules => 'Crediting on trips';

  @override
  String get saturdayCap => 'Saturday: max. hours';

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

  @override
  String get sync => 'Sync';

  @override
  String get syncIntro =>
      'Sync this device with your other devices through your Nextcloud. All data is end-to-end encrypted with a sync passphrase before it is uploaded.';

  @override
  String get syncServer => 'Nextcloud address';

  @override
  String get syncManual => 'Enter login name and app password manually';

  @override
  String get syncLoginName => 'Login name';

  @override
  String get syncAppPassword => 'App password';

  @override
  String get syncConnect => 'Connect';

  @override
  String get syncWaitingForLogin =>
      'Please confirm the login in the browser, then return to TimeTrack…';

  @override
  String get syncLoginTimeout => 'The login was not confirmed in time.';

  @override
  String get syncDerivingKey =>
      'Deriving the key… this can take a few seconds.';

  @override
  String get syncWrongPassphrase => 'Wrong sync passphrase.';

  @override
  String get syncPassphrase => 'Sync passphrase';

  @override
  String get syncPassphraseNew =>
      'Choose a passphrase. You\'ll need it once on every further device. Without it, the data on Nextcloud can\'t be read.';

  @override
  String get syncPassphraseJoin =>
      'Enter the passphrase you chose on your first device.';

  @override
  String get syncPassphraseRepeat => 'Repeat passphrase';

  @override
  String get syncPassphraseShort => 'At least 8 characters';

  @override
  String get syncPassphraseMismatch => 'The passphrases don\'t match';

  @override
  String syncLastSuccess(String time) {
    return 'Last synced at $time';
  }

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncDisconnect => 'Disconnect';

  @override
  String get syncNotConnected => 'Not connected';

  @override
  String get syncError => 'Sync failed';

  @override
  String get syncProxy => 'Proxy for this device (optional, host:port)';

  @override
  String get navReports => 'Reports';

  @override
  String get timesheet => 'Timesheet';

  @override
  String get orderReport => 'Order report';

  @override
  String get travelReport => 'Travel report';

  @override
  String get statistics => 'Statistics';

  @override
  String get backupJson => 'Backup of all data (JSON)';

  @override
  String savedTo(String path) {
    return 'Saved: $path';
  }

  @override
  String get colDate => 'Date';

  @override
  String get colBreak => 'Break';

  @override
  String get colNotes => 'Notes';

  @override
  String get balanceBefore => 'Balance at start of month';

  @override
  String get balanceAfter => 'Balance at end';

  @override
  String get homeOfficeDays => 'Home-office days';

  @override
  String get vacationDaysTaken => 'Vacation days';

  @override
  String get workedDays => 'Days worked';

  @override
  String get signature => 'Date, signature';

  @override
  String get perDiem => 'Meal allowance';

  @override
  String get perDiemPartial => 'partial day';

  @override
  String get perDiemFull => 'full day';

  @override
  String get perDiemNone => 'no allowance';

  @override
  String get mealsProvided => 'Meals provided';

  @override
  String get breakfast => 'Breakfast';

  @override
  String get lunch => 'Lunch';

  @override
  String get dinner => 'Dinner';

  @override
  String get hoursAway => 'Hours away';

  @override
  String get amount => 'Amount';

  @override
  String get total => 'Total';

  @override
  String get noTrips => 'No trips in this month';

  @override
  String get noBookings => 'No project times in this month';

  @override
  String rateMissing(String country) {
    return 'No rate for $country';
  }

  @override
  String get hoursByProject => 'Hours by project';

  @override
  String get weeks => 'Weeks';

  @override
  String get previousMonth => 'Previous month';

  @override
  String get nextMonth => 'Next month';

  @override
  String generatedBy(String date) {
    return 'Created with TimeTrack on $date';
  }

  @override
  String get addProjectTime => 'Add project time';

  @override
  String get durationHours => 'Duration (h:mm)';

  @override
  String get withClockTime => 'Set a start time';

  @override
  String get withClockTimeHint =>
      'Optional; without it only the duration counts';

  @override
  String get summary => 'Summary';

  @override
  String get summaryHint => 'What did you do?';

  @override
  String summaryQuestion(String project) {
    return 'What did you do for $project?';
  }

  @override
  String get skip => 'Skip';

  @override
  String get activity => 'Activity';

  @override
  String warnProjectOverWork(String minutes) {
    return '$minutes more project time than working time';
  }

  @override
  String get switchProject => 'Switch project';

  @override
  String get quickWorking => 'Working';

  @override
  String get quickOnBreak => 'On a break';

  @override
  String get quickToday => 'Today';

  @override
  String get travelWorkday => 'Workdays on a trip';

  @override
  String get travelWorkdayHint =>
      'Target: the account gets your target (e.g. 8:00) however long travel and work took. Actual time: what you worked counts.';

  @override
  String get travelWorkdayTarget => 'Target hours';

  @override
  String get travelWorkdayActual => 'Actual time';

  @override
  String get travelSaturdayHint =>
      'Work and travel count as overtime, up to this cap.';

  @override
  String get saturdayCapScope => 'Saturday cap covers';

  @override
  String get capTotal => 'Travel + work';

  @override
  String get capTravelOnly => 'Travel only';

  @override
  String get travelSunday => 'Sundays';

  @override
  String get travelSundayHoursHint =>
      'Work and travel count as Sunday/holiday hours for HR (monthly timesheet), not as overtime.';

  @override
  String get travelSundayWorkOnlyHint =>
      'Work counts as overtime, travel time doesn\'t count.';

  @override
  String get sundayHours => 'Sunday/holiday hours';

  @override
  String get sundayWorkOnly => 'Work only';

  @override
  String get sundayCap => 'Sunday/holiday hours: max. per day';

  @override
  String get travelHoliday => 'Public holidays';

  @override
  String get likeSunday => 'Like Sunday';

  @override
  String get likeSaturday => 'Like Saturday';

  @override
  String get weekendRules => 'Weekends and public holidays';

  @override
  String breakDeducted(String minutes) {
    return 'Missing break deducted: $minutes';
  }

  @override
  String get timesheetLegend =>
      'Worked: the time actually worked. Credited: the time that goes into the overtime account; on trips, weekends and public holidays it follows the rules in the settings (Sunday and holiday work is listed separately as Sunday/holiday hours). Balance ± = credited − target.';

  @override
  String get tripProjectNone => 'No project (optional)';

  @override
  String get colProject => 'Project';

  @override
  String get preview => 'Preview and download';

  @override
  String get tripNoProject => 'Trip without a project';

  @override
  String tripBookedTo(String project) {
    return 'Booked to $project';
  }

  @override
  String get tripDays => 'Trip days';

  @override
  String get dayBusinessTrip => 'Business trip';

  @override
  String get absenceChildSick => 'Child sick day';

  @override
  String get absenceShortTime => 'Short-time work';

  @override
  String get dayType => 'Type of day';

  @override
  String tripDayLocked(String trip) {
    return 'This day belongs to the trip $trip. To make it an office or home-office day, change the trip first.';
  }

  @override
  String get editTrip => 'Edit trip';

  @override
  String tripTimes(String travel, String onSite) {
    return 'Travel $travel · On site $onSite';
  }

  @override
  String get absenceWorkHint =>
      'Working time recorded on this day is credited as overtime.';

  @override
  String get goToToday => 'Go to today';

  @override
  String assignedTo(String minutes, String project) {
    return '$minutes booked to $project';
  }

  @override
  String get back => 'Back';

  @override
  String get chooseDayType => 'Day type';

  @override
  String get commandPalette => 'Search and actions';

  @override
  String get commandPaletteHint => 'Action, screen or project …';

  @override
  String get copiedPreviousDay => 'Previous day copied';

  @override
  String get copyPreviousDay => 'Copy previous day';

  @override
  String get deleted => 'Deleted';

  @override
  String get done => 'Done';

  @override
  String get editDay => 'Edit day';

  @override
  String get explainAbsenceCredit => 'Absence credit';

  @override
  String get explainBreakDeducted => 'Break deducted';

  @override
  String get explainBreakDeductedHint =>
      'The required break was missing (ArbZG §4).';

  @override
  String get explainDeltaMinus =>
      'Less than the target: this lowers your balance.';

  @override
  String get explainDeltaPlus =>
      'More than the target: this counts as overtime.';

  @override
  String get explainDeltaZero => 'Exactly the target: no overtime, no minus.';

  @override
  String get explainHow => 'How is this calculated?';

  @override
  String get explainRule => 'Rule for this day';

  @override
  String get explainSaturday => 'Saturday: worked time counts as overtime.';

  @override
  String explainSaturdayCapped(String cap, String rest) {
    return 'Saturday: at most $cap count, $rest not counted.';
  }

  @override
  String get explainSundayCounted =>
      'Sunday/holiday rule: work on site counts as usual.';

  @override
  String get explainSundayHours =>
      'Reported to HR for extra pay, not part of the balance.';

  @override
  String explainSundayNotCounted(String rest) {
    return 'Sunday/holiday rule: $rest not counted towards the balance.';
  }

  @override
  String get explainTargetDayOff => 'No scheduled work on this day.';

  @override
  String explainTargetHoliday(String name) {
    return 'Public holiday $name: no target.';
  }

  @override
  String get explainTargetReduced =>
      'Lowered by short-time work or an extra day off.';

  @override
  String get explainTargetSchedule => 'From your work schedule.';

  @override
  String explainTitle(String date) {
    return 'How $date is counted';
  }

  @override
  String explainTripWorkday(String credit) {
    return 'Trip on a workday: credited as a normal day ($credit), however long it was.';
  }

  @override
  String get fixAddBreak => 'Add break';

  @override
  String get fixAssign => 'Assign';

  @override
  String get fixSetEnd => 'Set end';

  @override
  String homeOfficeLimit(String percent) {
    return 'Limit: $percent % per month';
  }

  @override
  String homeOfficeOfWorked(String home, String worked) {
    return '$home of $worked days worked at home';
  }

  @override
  String get month => 'Month';

  @override
  String get more => 'More';

  @override
  String get next => 'Next';

  @override
  String get noLimit => 'No limit';

  @override
  String ofTarget(String target) {
    return 'of $target';
  }

  @override
  String get openDay => 'Open day';

  @override
  String percentPerMonth(String percent) {
    return '$percent % per month';
  }

  @override
  String perDaySummary(String minutes) {
    return 'That is $minutes per workday.';
  }

  @override
  String get quickEntry => 'Quick entry';

  @override
  String get quickEntryHelp =>
      'Times, break (p30), place (@home), project, note after \": \"';

  @override
  String get quickEntryInvalid =>
      'Add times like 8-16:30 or a duration like 1:30';

  @override
  String quickEntryNoProject(String query) {
    return 'no project matches \"$query\"';
  }

  @override
  String get quickEntrySaved => 'Entered';

  @override
  String get saveAsTemplate => 'Save day as template';

  @override
  String get searchSettings => 'Search settings';

  @override
  String get setupAgainHint =>
      'State, working time, balance and home office in four steps';

  @override
  String get setupBalanceHint =>
      'From which day should the balance count, and what did you bring along?';

  @override
  String get setupConnectSync => 'Connect Nextcloud';

  @override
  String get setupDone => 'All set';

  @override
  String get setupDoneHint =>
      'You can change everything later in the settings. Connect Nextcloud to sync your devices.';

  @override
  String get setupHomeOfficeHint =>
      'How much home office does your employer allow?';

  @override
  String get setupScheduleHint => 'Your contractual working time and vacation.';

  @override
  String get setupStart => 'Set up';

  @override
  String get setupStateHint => 'For public holidays.';

  @override
  String get setupTitle => 'Setup';

  @override
  String get startingBalanceHint =>
      'Overtime carried over, e.g. 12:30 or -2:00';

  @override
  String startProjectNamed(String project) {
    return 'Start $project';
  }

  @override
  String get syncing => 'Syncing …';

  @override
  String templateApplied(String name) {
    return 'Template \"$name\" applied';
  }

  @override
  String get templateName => 'Name';

  @override
  String get timeline => 'Timeline';

  @override
  String get timelineHint =>
      'Drag the edges to adjust, tap a hatched gap to assign it.';

  @override
  String get tripStillOpen => 'Trip still open';

  @override
  String tripStillOpenTo(String destination) {
    return 'Trip to $destination still open';
  }

  @override
  String get undo => 'Undo';

  @override
  String get vacationCarryOver => 'Vacation days carried over';

  @override
  String get vacationDaysPerYear => 'Vacation days per year';

  @override
  String warnUnassigned(String minutes) {
    return '$minutes without a project';
  }

  @override
  String get week => 'Week';

  @override
  String get weeklyHours => 'Hours per week';

  @override
  String get workdaysPerWeek => 'Workdays per week';

  @override
  String get showLess => 'Show less';

  @override
  String moreNotices(String count) {
    return '$count more notices';
  }

  @override
  String get noticeUnassignedFrom => '\"Without a project\" from';

  @override
  String get noticeUnassignedHint =>
      'Days with less unassigned time get no notice.';

  @override
  String get noticeCatUnassigned => 'Time without a project';

  @override
  String get noticeCatBreaks => 'Missing break (ArbZG §4)';

  @override
  String get noticeCatLongDay => 'More than 10 hours (ArbZG §3)';

  @override
  String get noticeCatRest => 'Rest under 11 hours (ArbZG §5)';

  @override
  String get noticeCatSunday => 'Work on Sundays and holidays';

  @override
  String get noticeCatOpenSession => 'Forgotten clock-out';

  @override
  String get noticeCatOverlaps => 'Overlapping entries';

  @override
  String get noticeCatProjectTime =>
      'Project time outside or above working time';

  @override
  String get noticeCatQuota => 'Home-office limit';

  @override
  String get noticeCatOpenTrip => 'Trip still open';

  @override
  String get restoreNotices => 'Show dismissed notices again';

  @override
  String dismissedCount(String count) {
    return '$count dismissed';
  }

  @override
  String get noticeDismissed =>
      'Notice hidden; the calendar keeps a small marker';

  @override
  String hiddenNotices(String count) {
    return '$count hidden notices';
  }

  @override
  String get noticeCategoryOff => 'Switched off in the settings';

  @override
  String get showAgain => 'Show again';

  @override
  String get hasNotices => 'Has notices';

  @override
  String get bookProjectTime => 'Book project time';

  @override
  String get editProjectTime => 'Edit project time';

  @override
  String get projectSearchHint => 'Project: name, number, order, client …';

  @override
  String get recentlyUsed => 'Recently used';

  @override
  String get changeProject => 'Change project';

  @override
  String get duration => 'Duration';

  @override
  String restOfDay(String minutes) {
    return 'Rest of the day $minutes';
  }

  @override
  String get whatWasDone => 'What was done?';

  @override
  String get book => 'Book';

  @override
  String get legOutbound => 'Outbound';

  @override
  String get legOnSite => 'At the customer';

  @override
  String get legInbound => 'Return';

  @override
  String get creditedAccount => 'Credited (account)';

  @override
  String get travelRecord => 'Travel record';

  @override
  String get travelRecordEmpty => 'No outbound, on-site or return times yet.';

  @override
  String accountCredits(String minutes) {
    return 'Overtime account: $minutes credited';
  }

  @override
  String get accountSection => 'Overtime account';

  @override
  String get stepStartOutbound => 'Start travelling there';

  @override
  String get stepArriveOnSite => 'Arrived at the customer';

  @override
  String get stepEndOutbound => 'End travel there';

  @override
  String get stepStartOnSite => 'Start at the customer';

  @override
  String get stepEndOnSite => 'Done at the customer';

  @override
  String get stepStartInbound => 'Start travelling back';

  @override
  String get stepEndInbound => 'Back – end travel';

  @override
  String get accountSectionHint =>
      'What your overtime account is credited. The real times (project time, travel and time at the customer) are recorded separately and go into the reports.';

  @override
  String get travelRulesHint =>
      'Only for the overtime account. The travel record always shows the exact outbound, customer and return times.';

  @override
  String get weekendRulesHint =>
      'For every Saturday, Sunday and holiday, on a trip or not. Only for the overtime account.';

  @override
  String get recordsSection => 'Records';

  @override
  String get recordsSectionHint =>
      'Recorded to the minute as it happened, independent of what the account credits.';

  @override
  String get travelRecordHint =>
      'Outbound, at the customer and return with times, hours away and per-diem';

  @override
  String get projectTimesRecord => 'Project times';

  @override
  String get projectTimesRecordHint =>
      'In 15-minute steps per order; timesheet and order report';

  @override
  String get backAgainToLeave => 'Press back again to leave';

  @override
  String get perDiemRates => 'Per-diem rates';

  @override
  String get perDiemRatesHint =>
      'For the travel report. Each trip day uses the newest rate of the trip\'s country that is valid on that day. Meals provided reduce it: breakfast by 20 %, lunch and dinner by 40 % each of the full-day rate.';

  @override
  String perDiemRatesSummary(String count) {
    return '$count countries';
  }

  @override
  String get partialDayRate =>
      'Partial day (more than 8 h, arrival or departure)';

  @override
  String get fullDayRate => 'Full day (24 h)';

  @override
  String get newRate => 'New rate';

  @override
  String get countryIso => 'Country (ISO code, e.g. AT)';

  @override
  String get builtInRate => 'Built-in';

  @override
  String get rateInUse => 'in use today';

  @override
  String rateAmounts(String partial, String full) {
    return '$partial partial · $full full';
  }

  @override
  String get restoreBackup => 'Load backup';

  @override
  String get restoreBackupHint => 'Restore from a JSON backup; you choose how';

  @override
  String get notABackup =>
      'This file isn\'t a TimeTrack backup that this version can read.';

  @override
  String restoreFrom(String date, String count) {
    return 'Backup from $date · $count entries';
  }

  @override
  String get restoreChoose => 'How should the backup be loaded?';

  @override
  String get restoreMerge => 'Merge';

  @override
  String get restoreMergeHint =>
      'Like a sync: whatever is missing comes back from the backup, everything changed later stays.';

  @override
  String get restoreReplace => 'Replace';

  @override
  String get restoreReplaceHint =>
      'Your data becomes exactly the backup, on all devices. Everything entered or changed after the backup is lost.';

  @override
  String restoreCounts(String added, String changed, String deleted) {
    return '$added back · $changed changed · $deleted deleted';
  }

  @override
  String get restoreNoChange => 'no changes';

  @override
  String get restoreSyncFailed =>
      'Sync failed: entries from other devices that haven\'t arrived yet are not taken into account.';

  @override
  String get restoreTip => 'Tip: save a current backup first.';

  @override
  String restoreDone(String counts) {
    return 'Backup loaded: $counts';
  }

  @override
  String get syncLog => 'Sync log';

  @override
  String get syncLogHint => 'Only on this device, the last 100 cycles';

  @override
  String get syncLogEmpty => 'No sync cycles yet.';

  @override
  String get syncLogIdle => 'Nothing to sync';

  @override
  String get syncLogFailed => 'Failed';

  @override
  String syncLogUp(String count) {
    return '↑ $count changes sent';
  }

  @override
  String syncLogDown(String count) {
    return '↓ $count changes received';
  }

  @override
  String syncLogResolved(String count) {
    return '$count entries corrected';
  }

  @override
  String get syncLogBackground => 'in the background';

  @override
  String get syncLogClear => 'Clear log';

  @override
  String syncLogTimes(String count) {
    return '$count×';
  }

  @override
  String get syncLogNetwork => 'after a network change';

  @override
  String updateAvailable(String version) {
    return 'TimeTrack $version is available';
  }

  @override
  String get updateNotificationText => 'Tap to see what\'s new and update.';

  @override
  String get updatesChannel => 'Updates';

  @override
  String get updateNow => 'Update';

  @override
  String get updateWhatsNew => 'What\'s new';

  @override
  String get updateLater => 'Later';

  @override
  String get updateSkip => 'Skip this version';

  @override
  String updateDownloading(String version, String percent) {
    return 'Downloading TimeTrack $version … $percent';
  }

  @override
  String updateReady(String version) {
    return 'TimeTrack $version is installed. Restart to use it.';
  }

  @override
  String get updateRestart => 'Restart';

  @override
  String updateFailed(String error) {
    return 'Update failed: $error';
  }

  @override
  String get updateRetry => 'Try again';

  @override
  String get updateNeedsPermission =>
      'Allow TimeTrack to install unknown apps, then tap Update again.';

  @override
  String get updateNoNotes => 'No release notes.';

  @override
  String get appSection => 'App';

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String installedVersion(String version) {
    return 'Installed: $version';
  }

  @override
  String lastChecked(String when) {
    return 'last checked $when';
  }

  @override
  String get autoUpdateCheck => 'Check for updates automatically';

  @override
  String get autoUpdateCheckHint =>
      'At most once a day. Nothing is installed without asking.';

  @override
  String get upToDate => 'TimeTrack is up to date.';

  @override
  String get updateCheckFailed => 'Couldn\'t reach GitHub.';

  @override
  String get releasePage => 'All versions on GitHub';

  @override
  String get workPc => 'Work PC';

  @override
  String get workPcHint =>
      'Asks after you sign in to Windows whether to start tracking for today (turns on “Start with Windows” too).';

  @override
  String get workPcFailed => 'Couldn\'t change the Windows autostart.';

  @override
  String get startTrackingTitle => 'Start tracking for today?';

  @override
  String get startTrackingText => 'No working time recorded today yet.';

  @override
  String get startTrackingStart => 'Start';

  @override
  String get startTrackingNotToday => 'Not today';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get wallpaperColors => 'Wallpaper colours';

  @override
  String get wallpaperColorsHint => 'Off: TimeTrack\'s own colours.';

  @override
  String get keyboardShortcuts => 'Keyboard shortcuts';

  @override
  String get keysClock => 'Clock in or out';

  @override
  String get keysBreak => 'Start or end a break';

  @override
  String get keysTabs => 'Today, Calendar, Projects, Reports';

  @override
  String get keysPrevNext => 'Previous or next week, month or day';

  @override
  String get keysWeekMonth => 'Switch between week and month';

  @override
  String get keysHelp => 'This overview';

  @override
  String forecastTarget(String time) {
    return 'Target reached at $time';
  }

  @override
  String forecastBreak(int minutes) {
    return 'incl. $minutes min break';
  }

  @override
  String forecastLimit(String time) {
    return '10 h at $time';
  }

  @override
  String get reminders => 'Reminders';

  @override
  String get remindBreak => 'Break due';

  @override
  String get remindBreakHint => 'After 5:45 h without a break';

  @override
  String get remindLongDay => 'Long day';

  @override
  String get remindLongDayHint => 'At 9:45 h, before reaching 10 h';

  @override
  String get reminderBreakTitle => 'Time for a break';

  @override
  String get reminderBreakText =>
      '5:45 h without a break – after 6 h a break is required.';

  @override
  String get reminderLongDayTitle => 'Almost 10 hours';

  @override
  String get reminderLongDayText =>
      'Still clocked in? More than 10 hours of work a day aren\'t allowed.';

  @override
  String get forgottenTitle => 'Still clocked in?';

  @override
  String forgottenText(String since) {
    return 'Clocked in since $since. When did you finish?';
  }

  @override
  String yesterdayAt(String time) {
    return 'yesterday, $time';
  }

  @override
  String get suggestLastActivity => 'Last activity';

  @override
  String get suggestTarget => 'Target reached';

  @override
  String get suggestUsualEnd => 'Usual finish';

  @override
  String get otherTime => 'Other time…';

  @override
  String get stillWorking => 'Still working';

  @override
  String forgottenTimeInvalid(String from) {
    return 'Pick a time between $from and now.';
  }

  @override
  String clockedOutAt(String time) {
    return 'Clocked out at $time';
  }

  @override
  String get weekCheck => 'Check week';

  @override
  String get monthCheck => 'Check month';

  @override
  String noticeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notices',
      one: '1 notice',
    );
    return '$_temp0';
  }

  @override
  String noticeDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'on $count days',
      one: 'on 1 day',
    );
    return '$_temp0';
  }

  @override
  String get weekComplete => 'Week complete';

  @override
  String get monthComplete => 'Month complete';

  @override
  String reviewStep(int index, int total) {
    return '$index of $total';
  }

  @override
  String get hideNotice => 'Hide';

  @override
  String get allDone => 'All done';

  @override
  String skippedCount(int count) {
    return '$count skipped';
  }

  @override
  String get projectBudget => 'Budget (hours)';

  @override
  String get projectBudgetHint => 'Empty: no budget';

  @override
  String get invalidHours => 'Hours like 40, 37.5 or 37:30';

  @override
  String get noticeCatBudget => 'Project budget';

  @override
  String warnBudgetNear(String project, String budget) {
    return '$project: 80 % of the budget ($budget) used';
  }

  @override
  String warnBudgetOver(String project, String budget) {
    return '$project: budget ($budget) exceeded';
  }

  @override
  String get openProject => 'Open project';

  @override
  String get thisMonth => 'This month';

  @override
  String get thisYear => 'This year';

  @override
  String budgetUsed(String used, String budget, int percent) {
    return '$used of $budget ($percent %)';
  }

  @override
  String budgetLeft(String left) {
    return '$left left';
  }

  @override
  String budgetOverBy(String over) {
    return '$over over';
  }

  @override
  String get projectHistory => 'History';

  @override
  String get lastTwelveWeeks => 'Recent weeks';

  @override
  String get startTimer => 'Start timer';

  @override
  String get projectRunning => 'Running';

  @override
  String get noTimeBooked => 'No time booked yet';

  @override
  String showAllDays(int count) {
    return 'Show all $count days';
  }

  @override
  String get archive => 'Archive';

  @override
  String get unarchive => 'Restore from archive';

  @override
  String get budget => 'Budget';

  @override
  String get vacationPlanner => 'Vacation planner';

  @override
  String get bridgeDays => 'Bridge days';

  @override
  String bridgeTitle(int count, int free) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days off',
      one: '1 day off',
    );
    return '$_temp0 → $free days free';
  }

  @override
  String get bridgeBook => 'Book';

  @override
  String get bridgeBooked => 'Vacation booked';

  @override
  String noBridges(int year) {
    return 'No more bridge days in $year';
  }

  @override
  String absencesOfYear(int year) {
    return 'Absences $year';
  }

  @override
  String get bridgeDay => 'Bridge day';

  @override
  String get otherAbsence => 'Other absence';

  @override
  String get trayOpen => 'Open TimeTrack';

  @override
  String get trayQuit => 'Quit';

  @override
  String get closeToTray => 'Keep running in the tray';

  @override
  String get closeToTrayHint =>
      'Closing hides the window; the tray icon\'s menu has Quit.';

  @override
  String get defaultBreakStart => 'Usual break: start';

  @override
  String get defaultBreakLength => 'Usual break: length';

  @override
  String get defaultBreakHint => 'Suggested when you add a break';

  @override
  String beforeBalanceStart(String date) {
    return 'Before the balance starts ($date): no target, no overtime';
  }

  @override
  String get autostart => 'Start with Windows';

  @override
  String get autostartHint =>
      'Starts TimeTrack when you sign in to Windows (this user only).';

  @override
  String get removeDayType => 'Remove day type';

  @override
  String get dayTypeRemoved => 'Day type removed';

  @override
  String tripDayRemove(String trip) {
    return 'This day belongs to the trip $trip. To remove it, change the trip.';
  }

  @override
  String get bookingTransfer => 'Transfer to booking system';

  @override
  String get bookingSystem => 'Booking system';

  @override
  String get bookingUrl => 'Booking system (address)';

  @override
  String get bookingUrlHint =>
      'Page for the weekly project time; saved only on this PC';

  @override
  String bookingPreviewTitle(String week) {
    return 'Transfer week $week';
  }

  @override
  String get bookingOpen => 'Open in booking system';

  @override
  String get bookingNoRows =>
      'No project time with a project number in this week.';

  @override
  String get bookingRunningTimer =>
      'A project timer is still running; its time counts up to now.';

  @override
  String bookingUnassigned(String day, String time) {
    return '$day: $time without a project, not transferred';
  }

  @override
  String bookingRounding(String rounded, String exact) {
    return 'Rounded to half hours: $rounded instead of $exact';
  }

  @override
  String bookingSkipped(String name, String time) {
    return '$name ($time) has no project number and is not transferred';
  }

  @override
  String get bookingSum => 'Sum';

  @override
  String bookingTransferredOn(String date) {
    return 'Transferred on $date';
  }

  @override
  String bookingChangedSince(String date) {
    return 'Changed since the transfer on $date';
  }

  @override
  String get bookingNotTransferred => 'Not transferred yet';

  @override
  String get bookingLoading => 'Opening the booking page…';

  @override
  String get bookingFilling => 'Filling in…';

  @override
  String bookingFilled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows',
      one: '1 row',
    );
    return '$_temp0 filled. Add Kostengruppe and Position, check the hours, then click Buchen.';
  }

  @override
  String bookingUnknownProjects(String projects) {
    return 'Unknown in the booking system, not filled: $projects';
  }

  @override
  String bookingLockedDays(String days) {
    return 'Booking period locked, not filled: $days';
  }

  @override
  String get bookingReplaceTitle => 'Replace the entries?';

  @override
  String get bookingReplaceBody =>
      'The form already contains entries. Replace them with this week?';

  @override
  String get bookingReplace => 'Replace';

  @override
  String get bookingKept => 'Form left unchanged.';

  @override
  String get bookingBooked =>
      'Booking started; the week is marked as transferred.';

  @override
  String get bookingAskBooked => 'Was the week booked?';

  @override
  String get bookingAskBookedBody =>
      'If you clicked Buchen, TimeTrack marks the week as transferred.';

  @override
  String get bookingWasBooked => 'Yes, booked';

  @override
  String get bookingNotBooked => 'No';

  @override
  String get bookingErrorTimeout =>
      'The booking page didn\'t get ready within 30 s. Check the address and the company network.';

  @override
  String bookingErrorPage(String detail) {
    return 'The page looks different than expected ($detail); nothing was filled.';
  }

  @override
  String bookingErrorFill(String detail) {
    return 'Filling in failed: $detail';
  }

  @override
  String bookingErrorLoad(String detail) {
    return 'The page couldn\'t be loaded ($detail).';
  }

  @override
  String get bookingNoRuntime =>
      'The Microsoft Edge WebView2 Runtime is missing; please install it.';

  @override
  String get bookingClose => 'Close';
}
