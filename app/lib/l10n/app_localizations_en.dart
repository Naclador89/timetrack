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
  String get autoClockIn => 'Clock in automatically when a project starts';

  @override
  String get resumeAfterBreak => 'Resume the project after a break';

  @override
  String get askStampTime => 'Ask for the time when stamping';

  @override
  String get askStampTimeHint =>
      'When clocking in or out and at breaks; the current time is suggested';

  @override
  String get stampTimeFuture => 'That time is in the future.';

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
    return 'Service trip on a weekday: counts as a normal workday ($credit), however long.';
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
  String get travelRulesHint =>
      'Only for the overtime account. The travel record always shows the exact outbound, customer and return times.';

  @override
  String get weekendRulesHint =>
      'For every Saturday, Sunday and holiday, on a trip or not. Only for the overtime account.';

  @override
  String get backAgainToLeave => 'Press back again to leave';

  @override
  String get perDiemRates => 'Per-diem rates';

  @override
  String get perDiemRatesHint =>
      'The BMF rates of every country and city from 2026 are built in; search to see them. A trip day uses the newest rate of its place valid on that day; your own rows supersede the built-in ones. Provided meals reduce it: breakfast by 20 %, lunch and dinner by 40 % each of the full-day rate.';

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

  @override
  String get serviceTrip => 'Service or commissioning';

  @override
  String get serviceTripHint =>
      'Work on a site: weekdays count the target, Saturdays at most 8 h; the extra work is paid as a supplement. Off for a fair, training or meeting: the real time counts, up to 10 h.';

  @override
  String get serviceSaturdayCap => 'Saturday on a service trip: max. hours';

  @override
  String get serviceSaturdayCapHint =>
      'Weekdays of a service trip always count the target; Saturdays the real time up to this cap.';

  @override
  String get dayCap => 'Other trips and Saturdays: max. hours';

  @override
  String get dayCapHint =>
      'Trips without service work and Saturdays without a trip: the real time, travel included, up to this cap.';

  @override
  String get servicePayDays => 'Days with trip supplement';

  @override
  String explainOtherTripWorkday(String cap) {
    return 'Business trip without service work: the real time counts, travel included, at most $cap.';
  }

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String monthReportTitle(String month) {
    return 'Report the overtime balance for $month';
  }

  @override
  String monthReportText(String date, String balance) {
    return 'Balance on $date: $balance. Enter it in the company system.';
  }

  @override
  String get monthReportReminder => 'Reminder: report overtime';

  @override
  String get monthReportReminderHint =>
      'After a change of month, reminds you of last month\'s closing balance';

  @override
  String get noticeCatBalanceZone => 'Time account zone';

  @override
  String warnBalanceYellow(String balance) {
    return 'Time account in the yellow zone ($balance)';
  }

  @override
  String warnBalanceRed(String balance) {
    return 'Time account in the red zone ($balance)';
  }

  @override
  String warnBalanceOverLimit(String balance) {
    return 'Time account over its limit ($balance)';
  }

  @override
  String get zoneGreen => 'Green zone';

  @override
  String get zoneYellow => 'Yellow zone';

  @override
  String get zoneRed => 'Red zone';

  @override
  String get zoneOverLimit => 'Over the limit';

  @override
  String get zoneYellowFrom => 'Yellow above';

  @override
  String get zoneRedFrom => 'Red above';

  @override
  String get zoneMax => 'Limit';

  @override
  String get zonePlus => 'Plus';

  @override
  String get zoneMinus => 'Minus';

  @override
  String get balanceZones => 'Time account zones';

  @override
  String get balanceZonesHint =>
      'Off · your employer\'s green/yellow/red limits';

  @override
  String get balanceZonesDialogHint =>
      'Whole hours above the target (plus) or below it (minus). Empty: no limit.';

  @override
  String get vacationCarryDeadline => 'Take carried-over vacation by';

  @override
  String get vacationCarryDeadlineHint =>
      'Shows on Today how many days of it are not planned yet';

  @override
  String get deadlineOff => 'Off';

  @override
  String deadlineEndOf(String month) {
    return 'End of $month';
  }

  @override
  String vacationCarryTitle(String year) {
    return 'Vacation left from $year';
  }

  @override
  String vacationCarryText(String days, String date) {
    return '$days days still to take or plan by $date.';
  }

  @override
  String vacationCarryOverInto(String year) {
    return 'Vacation carried into $year';
  }

  @override
  String get sectionAccount => 'Working time & account';

  @override
  String get sectionClocking => 'Clocking & breaks';

  @override
  String get sectionTravel => 'Trips & supplements';

  @override
  String get sectionApp => 'Appearance & updates';

  @override
  String get groupTarget => 'Target hours';

  @override
  String get groupVacation => 'Vacation';

  @override
  String get groupClocking => 'Clocking';

  @override
  String get groupBreaks => 'Breaks';

  @override
  String get groupExpenses => 'Expenses';

  @override
  String get groupDisplay => 'Display';

  @override
  String get groupUpdates => 'Updates';

  @override
  String noticesActive(String on, String all) {
    return '$on of $all on';
  }

  @override
  String get workPcSummary => 'Autostart, tray, monthly reminder, booking';

  @override
  String get specialHolidayHours => 'Special holiday hours';

  @override
  String get nightHours => 'Night hours';

  @override
  String get specialDays => 'Special holidays';

  @override
  String get specialDaysHint =>
      'Their hours are listed apart from the Sunday/holiday hours, e.g. for a higher supplement';

  @override
  String get specialDaysNone => 'None';

  @override
  String get specialDayNewYear => 'New Year\'s Day';

  @override
  String get specialDayEasterSunday => 'Easter Sunday';

  @override
  String get specialDayEasterMonday => 'Easter Monday';

  @override
  String get specialDayMayDay => '1 May';

  @override
  String get specialDayWhitSunday => 'Whit Sunday';

  @override
  String get specialDayWhitMonday => 'Whit Monday';

  @override
  String get specialDayChristmasDay => 'Christmas Day';

  @override
  String get specialDayBoxingDay => 'Boxing Day';

  @override
  String get groupNightWork => 'Night work';

  @override
  String get nightWorkCredit => 'Night hours (11 pm–6 am, from 2 h)';

  @override
  String get nightCount => 'On the account';

  @override
  String get nightExclude => 'Not on the account';

  @override
  String get nightCountHint => 'Listed and credited like any other work.';

  @override
  String get nightExcludeHint =>
      'Paid out: listed, but not credited to the overtime account. Service-trip workdays keep their target.';

  @override
  String get explainNightExcluded => 'Paid out, not on the overtime account.';

  @override
  String get explainNightCounted =>
      'Work between 11 pm and 6 am in a night of at least 2 h; reported for the supplement.';

  @override
  String get explainSpecialHolidayHours =>
      'Reported apart from the Sunday/holiday hours (higher supplement), not on the overtime account.';

  @override
  String monthReportSupplements(String items) {
    return 'Supplements: $items.';
  }

  @override
  String get columnSpecialHours => 'Special';

  @override
  String get columnNightHours => 'Night';

  @override
  String get searchCountry => 'Search country or city';

  @override
  String get restOfCountry => 'Elsewhere in the country';

  @override
  String get placeHint => 'Picks the per-diem and lodging rate';

  @override
  String get otherPlaces => 'Other places';

  @override
  String placeFrom(String date) {
    return 'From $date';
  }

  @override
  String get changePlace => 'Change place';

  @override
  String get changePlaceFrom => 'From which day?';

  @override
  String get lodging => 'Lodging';

  @override
  String get lodgingCompany => 'Company';

  @override
  String get lodgingFlat => 'Lump sum';

  @override
  String get lodgingReceipt => 'Receipts';

  @override
  String get lodgingReceiptTotal => 'Receipts total';

  @override
  String get lodgingFlatHint =>
      'No lump sum for nights on a plane, train or ship.';

  @override
  String get lodgingRate => 'Lodging per night (optional)';

  @override
  String get carKm => 'Own car';

  @override
  String get markClaimed => 'Claimed';

  @override
  String claimedOn(String date) {
    return 'Claimed on $date';
  }

  @override
  String claimTitle(String trip, String date) {
    return 'Claim the expenses of $trip by $date';
  }

  @override
  String get tripExpenses => 'Expense report';

  @override
  String get place => 'Place';

  @override
  String get siteAllowance => 'Site allowance';

  @override
  String get siteAllowanceHint =>
      'The site allowance is paid with the salary (taxable), not with the expense claim.';

  @override
  String get siteAllowanceRatesHint =>
      'Per site day of a service trip, from the first to the last site day once there are enough in a row. Country * covers all others.';

  @override
  String siteAllowanceSummary(String days) {
    return 'From $days site days in a row';
  }

  @override
  String get siteAllowanceMinDays => 'Site allowance from … site days in a row';

  @override
  String get siteAllowanceCountryHint =>
      'ISO code, or * for all other countries';

  @override
  String get allOtherCountries => 'All other countries';

  @override
  String get perSiteDay => 'Per site day';

  @override
  String get mileageRate => 'Mileage (own car)';

  @override
  String get mileage => 'Mileage';

  @override
  String get laundryAfterDays => 'Laundry on trips of';

  @override
  String get laundryHint => 'Laundry can be claimed for this trip.';

  @override
  String moreThanDays(String days) {
    return 'more than $days days';
  }

  @override
  String get claimDeadlineMonths => 'Claim expenses within';

  @override
  String get claimDeadlineHint =>
      'Today reminds you after each trip until it is marked as claimed';

  @override
  String get claimDeadline => 'Claim by';

  @override
  String monthsCount(String count) {
    return '$count months';
  }

  @override
  String get claimTotal => 'Claim total';

  @override
  String nightsCount(String count) {
    return '$count nights';
  }

  @override
  String daysCount(String count) {
    return '$count days';
  }

  @override
  String get cityOptional => 'City (optional)';

  @override
  String get noticeCatWeekLimit => 'Weekly limits';

  @override
  String warnWeekOverMax(String minutes) {
    return 'Week with $minutes worked: above the weekly maximum';
  }

  @override
  String warnWeekAverage(String minutes) {
    return 'Weekly average $minutes: above the limit';
  }

  @override
  String weekWorkedOfMax(String worked, String max) {
    return 'Worked $worked of max. $max';
  }

  @override
  String weekAverageOf(String weeks, String average, String limit) {
    return 'Average of $weeks weeks $average (limit $limit)';
  }

  @override
  String get groupWeekLimits => 'Weekly limits';

  @override
  String get weekMaxSetting => 'Most per week';

  @override
  String weekAverageSetting(String weeks) {
    return 'Average over $weeks weeks at most';
  }

  @override
  String get weekLimitsHint =>
      'All recorded work including travel, without breaks (§ 3 ArbZG). 0 switches it off.';

  @override
  String get addWorkTime => 'Add working time';
}
