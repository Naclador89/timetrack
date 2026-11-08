import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'TimeTrack'**
  String get appTitle;

  /// No description provided for @navToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get navToday;

  /// No description provided for @navCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get navCalendar;

  /// No description provided for @navProjects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get navProjects;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @clockIn.
  ///
  /// In en, this message translates to:
  /// **'Clock in'**
  String get clockIn;

  /// No description provided for @clockOut.
  ///
  /// In en, this message translates to:
  /// **'Clock out'**
  String get clockOut;

  /// No description provided for @startBreak.
  ///
  /// In en, this message translates to:
  /// **'Break'**
  String get startBreak;

  /// No description provided for @endBreak.
  ///
  /// In en, this message translates to:
  /// **'End break'**
  String get endBreak;

  /// No description provided for @notClockedIn.
  ///
  /// In en, this message translates to:
  /// **'Not clocked in'**
  String get notClockedIn;

  /// No description provided for @clockedInSince.
  ///
  /// In en, this message translates to:
  /// **'Clocked in since {time}'**
  String clockedInSince(String time);

  /// No description provided for @onBreakSince.
  ///
  /// In en, this message translates to:
  /// **'On break since {time}'**
  String onBreakSince(String time);

  /// No description provided for @locationOffice.
  ///
  /// In en, this message translates to:
  /// **'Office'**
  String get locationOffice;

  /// No description provided for @locationHome.
  ///
  /// In en, this message translates to:
  /// **'Home office'**
  String get locationHome;

  /// No description provided for @locationOnSite.
  ///
  /// In en, this message translates to:
  /// **'On site'**
  String get locationOnSite;

  /// No description provided for @locationTravel.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get locationTravel;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @worked.
  ///
  /// In en, this message translates to:
  /// **'Worked'**
  String get worked;

  /// No description provided for @target.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get target;

  /// No description provided for @credited.
  ///
  /// In en, this message translates to:
  /// **'Credited'**
  String get credited;

  /// No description provided for @difference.
  ///
  /// In en, this message translates to:
  /// **'Balance ±'**
  String get difference;

  /// No description provided for @balance.
  ///
  /// In en, this message translates to:
  /// **'Overtime balance'**
  String get balance;

  /// No description provided for @balanceToday.
  ///
  /// In en, this message translates to:
  /// **'incl. today'**
  String get balanceToday;

  /// No description provided for @unassigned.
  ///
  /// In en, this message translates to:
  /// **'Without project'**
  String get unassigned;

  /// No description provided for @chooseProject.
  ///
  /// In en, this message translates to:
  /// **'Choose project'**
  String get chooseProject;

  /// No description provided for @stopProject.
  ///
  /// In en, this message translates to:
  /// **'Stop project'**
  String get stopProject;

  /// No description provided for @noProjectRunning.
  ///
  /// In en, this message translates to:
  /// **'No project running'**
  String get noProjectRunning;

  /// No description provided for @homeOfficeWeek.
  ///
  /// In en, this message translates to:
  /// **'Home office this week: {used} of {allowed} days, {left} left'**
  String homeOfficeWeek(String used, String allowed, String left);

  /// No description provided for @homeOfficeMonth.
  ///
  /// In en, this message translates to:
  /// **'Home office this month: {used} of {allowed} days, {left} left'**
  String homeOfficeMonth(String used, String allowed, String left);

  /// No description provided for @setupHint.
  ///
  /// In en, this message translates to:
  /// **'Set your federal state and work schedule in the settings, so targets and balances are right.'**
  String get setupHint;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @startTrip.
  ///
  /// In en, this message translates to:
  /// **'Start trip'**
  String get startTrip;

  /// No description provided for @endTrip.
  ///
  /// In en, this message translates to:
  /// **'End trip'**
  String get endTrip;

  /// No description provided for @onTripTo.
  ///
  /// In en, this message translates to:
  /// **'On a trip to {destination}'**
  String onTripTo(String destination);

  /// No description provided for @onTrip.
  ///
  /// In en, this message translates to:
  /// **'On a trip'**
  String get onTrip;

  /// No description provided for @startTripQuestion.
  ///
  /// In en, this message translates to:
  /// **'Start a business trip?'**
  String get startTripQuestion;

  /// No description provided for @endTripQuestion.
  ///
  /// In en, this message translates to:
  /// **'Has the trip ended?'**
  String get endTripQuestion;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @destination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get destination;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country code'**
  String get country;

  /// No description provided for @overnight.
  ///
  /// In en, this message translates to:
  /// **'With overnight stay'**
  String get overnight;

  /// No description provided for @depart.
  ///
  /// In en, this message translates to:
  /// **'Departure'**
  String get depart;

  /// No description provided for @returnTime.
  ///
  /// In en, this message translates to:
  /// **'Return'**
  String get returnTime;

  /// No description provided for @notices.
  ///
  /// In en, this message translates to:
  /// **'Notices'**
  String get notices;

  /// No description provided for @warnBreakMissing.
  ///
  /// In en, this message translates to:
  /// **'{minutes} break missing (ArbZG §4)'**
  String warnBreakMissing(String minutes);

  /// No description provided for @warnOver6h.
  ///
  /// In en, this message translates to:
  /// **'More than 6 h without a break (ArbZG §4)'**
  String get warnOver6h;

  /// No description provided for @warnOver10h.
  ///
  /// In en, this message translates to:
  /// **'More than 10 h worked (ArbZG §3)'**
  String get warnOver10h;

  /// No description provided for @warnRest.
  ///
  /// In en, this message translates to:
  /// **'Only {minutes} rest since the previous day (ArbZG §5)'**
  String warnRest(String minutes);

  /// No description provided for @warnSunday.
  ///
  /// In en, this message translates to:
  /// **'Work on a Sunday or public holiday'**
  String get warnSunday;

  /// No description provided for @warnOpenSession.
  ///
  /// In en, this message translates to:
  /// **'Clocked in for a long time – forgot to clock out?'**
  String get warnOpenSession;

  /// No description provided for @warnOverlapSessions.
  ///
  /// In en, this message translates to:
  /// **'Overlapping working times'**
  String get warnOverlapSessions;

  /// No description provided for @warnOverlapProjects.
  ///
  /// In en, this message translates to:
  /// **'Overlapping project times'**
  String get warnOverlapProjects;

  /// No description provided for @warnProjectOutside.
  ///
  /// In en, this message translates to:
  /// **'{minutes} project time outside working time'**
  String warnProjectOutside(String minutes);

  /// No description provided for @warnQuota.
  ///
  /// In en, this message translates to:
  /// **'Another home-office day would exceed your quota'**
  String get warnQuota;

  /// No description provided for @weekNumber.
  ///
  /// In en, this message translates to:
  /// **'Week {number}'**
  String weekNumber(String number);

  /// No description provided for @weekTotal.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get weekTotal;

  /// No description provided for @sessions.
  ///
  /// In en, this message translates to:
  /// **'Working times'**
  String get sessions;

  /// No description provided for @breaks.
  ///
  /// In en, this message translates to:
  /// **'Breaks'**
  String get breaks;

  /// No description provided for @projectEntries.
  ///
  /// In en, this message translates to:
  /// **'Project times'**
  String get projectEntries;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @end.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get end;

  /// No description provided for @running.
  ///
  /// In en, this message translates to:
  /// **'running'**
  String get running;

  /// No description provided for @absence.
  ///
  /// In en, this message translates to:
  /// **'Absence'**
  String get absence;

  /// No description provided for @absences.
  ///
  /// In en, this message translates to:
  /// **'Absences'**
  String get absences;

  /// No description provided for @absenceVacation.
  ///
  /// In en, this message translates to:
  /// **'Vacation'**
  String get absenceVacation;

  /// No description provided for @absenceSick.
  ///
  /// In en, this message translates to:
  /// **'Sick'**
  String get absenceSick;

  /// No description provided for @absenceSpecialLeave.
  ///
  /// In en, this message translates to:
  /// **'Celebration/bereavement'**
  String get absenceSpecialLeave;

  /// No description provided for @absenceCompTime.
  ///
  /// In en, this message translates to:
  /// **'Flexitime'**
  String get absenceCompTime;

  /// No description provided for @absenceExtraHoliday.
  ///
  /// In en, this message translates to:
  /// **'Day off'**
  String get absenceExtraHoliday;

  /// No description provided for @halfDay.
  ///
  /// In en, this message translates to:
  /// **'Half day'**
  String get halfDay;

  /// No description provided for @addAbsence.
  ///
  /// In en, this message translates to:
  /// **'Add absence'**
  String get addAbsence;

  /// No description provided for @trips.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get trips;

  /// No description provided for @newTrip.
  ///
  /// In en, this message translates to:
  /// **'New trip'**
  String get newTrip;

  /// No description provided for @holiday.
  ///
  /// In en, this message translates to:
  /// **'Public holiday'**
  String get holiday;

  /// No description provided for @tripDay.
  ///
  /// In en, this message translates to:
  /// **'Trip'**
  String get tripDay;

  /// No description provided for @newProject.
  ///
  /// In en, this message translates to:
  /// **'New project'**
  String get newProject;

  /// No description provided for @editProject.
  ///
  /// In en, this message translates to:
  /// **'Edit project'**
  String get editProject;

  /// No description provided for @projectName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get projectName;

  /// No description provided for @projectNumber.
  ///
  /// In en, this message translates to:
  /// **'Project number'**
  String get projectNumber;

  /// No description provided for @orderNumber.
  ///
  /// In en, this message translates to:
  /// **'Order number'**
  String get orderNumber;

  /// No description provided for @client.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get client;

  /// No description provided for @favorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get favorite;

  /// No description provided for @archived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get archived;

  /// No description provided for @searchProjects.
  ///
  /// In en, this message translates to:
  /// **'Name, project or order number'**
  String get searchProjects;

  /// No description provided for @showArchived.
  ///
  /// In en, this message translates to:
  /// **'Show archived'**
  String get showArchived;

  /// No description provided for @createProjectNamed.
  ///
  /// In en, this message translates to:
  /// **'New project \"{name}\"'**
  String createProjectNamed(String name);

  /// No description provided for @noProjects.
  ///
  /// In en, this message translates to:
  /// **'No projects yet'**
  String get noProjects;

  /// No description provided for @federalState.
  ///
  /// In en, this message translates to:
  /// **'Federal state'**
  String get federalState;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @schedules.
  ///
  /// In en, this message translates to:
  /// **'Work schedules'**
  String get schedules;

  /// No description provided for @newSchedule.
  ///
  /// In en, this message translates to:
  /// **'New schedule'**
  String get newSchedule;

  /// No description provided for @validFrom.
  ///
  /// In en, this message translates to:
  /// **'Valid from'**
  String get validFrom;

  /// No description provided for @hoursPerWeekday.
  ///
  /// In en, this message translates to:
  /// **'Hours per weekday (h:mm)'**
  String get hoursPerWeekday;

  /// No description provided for @vacationDays.
  ///
  /// In en, this message translates to:
  /// **'Vacation days per year'**
  String get vacationDays;

  /// No description provided for @perWeekSummary.
  ///
  /// In en, this message translates to:
  /// **'{hours} per week, {days} vacation days'**
  String perWeekSummary(String hours, String days);

  /// No description provided for @breakRule.
  ///
  /// In en, this message translates to:
  /// **'Missing breaks'**
  String get breakRule;

  /// No description provided for @breakWarn.
  ///
  /// In en, this message translates to:
  /// **'Warn only'**
  String get breakWarn;

  /// No description provided for @breakDeduct.
  ///
  /// In en, this message translates to:
  /// **'Deduct automatically'**
  String get breakDeduct;

  /// No description provided for @startingBalance.
  ///
  /// In en, this message translates to:
  /// **'Starting balance (h:mm, may be negative)'**
  String get startingBalance;

  /// No description provided for @balanceStart.
  ///
  /// In en, this message translates to:
  /// **'Balance counted from'**
  String get balanceStart;

  /// No description provided for @homeOfficeRules.
  ///
  /// In en, this message translates to:
  /// **'Home-office rules'**
  String get homeOfficeRules;

  /// No description provided for @newRule.
  ///
  /// In en, this message translates to:
  /// **'New rule'**
  String get newRule;

  /// No description provided for @perWeek.
  ///
  /// In en, this message translates to:
  /// **'per week'**
  String get perWeek;

  /// No description provided for @perMonth.
  ///
  /// In en, this message translates to:
  /// **'per month'**
  String get perMonth;

  /// No description provided for @maxPercent.
  ///
  /// In en, this message translates to:
  /// **'Max. share in %'**
  String get maxPercent;

  /// No description provided for @basisWorked.
  ///
  /// In en, this message translates to:
  /// **'of days worked'**
  String get basisWorked;

  /// No description provided for @basisScheduled.
  ///
  /// In en, this message translates to:
  /// **'of scheduled workdays'**
  String get basisScheduled;

  /// No description provided for @ruleSummary.
  ///
  /// In en, this message translates to:
  /// **'{percent} % {period} {basis}'**
  String ruleSummary(String percent, String period, String basis);

  /// No description provided for @travelRules.
  ///
  /// In en, this message translates to:
  /// **'Crediting on trips'**
  String get travelRules;

  /// No description provided for @saturdayCap.
  ///
  /// In en, this message translates to:
  /// **'Saturday: max. hours'**
  String get saturdayCap;

  /// No description provided for @autoClockIn.
  ///
  /// In en, this message translates to:
  /// **'Clock in automatically when a project starts'**
  String get autoClockIn;

  /// No description provided for @resumeAfterBreak.
  ///
  /// In en, this message translates to:
  /// **'Resume the project after a break'**
  String get resumeAfterBreak;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @vacationLeft.
  ///
  /// In en, this message translates to:
  /// **'Vacation {year}: {remaining} of {total} days left'**
  String vacationLeft(String year, String remaining, String total);

  /// No description provided for @vacationTakenPlanned.
  ///
  /// In en, this message translates to:
  /// **'{taken} taken, {planned} planned'**
  String vacationTakenPlanned(String taken, String planned);

  /// No description provided for @deleteQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete this entry?'**
  String get deleteQuestion;

  /// No description provided for @endBeforeStart.
  ///
  /// In en, this message translates to:
  /// **'The end must be after the start'**
  String get endBeforeStart;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @invalidValue.
  ///
  /// In en, this message translates to:
  /// **'Invalid value'**
  String get invalidValue;

  /// No description provided for @nothingRecorded.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded'**
  String get nothingRecorded;

  /// No description provided for @previousWeek.
  ///
  /// In en, this message translates to:
  /// **'Previous week'**
  String get previousWeek;

  /// No description provided for @nextWeek.
  ///
  /// In en, this message translates to:
  /// **'Next week'**
  String get nextWeek;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get thisWeek;

  /// No description provided for @from.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get from;

  /// No description provided for @to.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get to;

  /// No description provided for @sync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get sync;

  /// No description provided for @syncIntro.
  ///
  /// In en, this message translates to:
  /// **'Sync this device with your other devices through your Nextcloud. All data is end-to-end encrypted with a sync passphrase before it is uploaded.'**
  String get syncIntro;

  /// No description provided for @syncServer.
  ///
  /// In en, this message translates to:
  /// **'Nextcloud address'**
  String get syncServer;

  /// No description provided for @syncManual.
  ///
  /// In en, this message translates to:
  /// **'Enter login name and app password manually'**
  String get syncManual;

  /// No description provided for @syncLoginName.
  ///
  /// In en, this message translates to:
  /// **'Login name'**
  String get syncLoginName;

  /// No description provided for @syncAppPassword.
  ///
  /// In en, this message translates to:
  /// **'App password'**
  String get syncAppPassword;

  /// No description provided for @syncConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get syncConnect;

  /// No description provided for @syncWaitingForLogin.
  ///
  /// In en, this message translates to:
  /// **'Please confirm the login in the browser, then return to TimeTrack…'**
  String get syncWaitingForLogin;

  /// No description provided for @syncLoginTimeout.
  ///
  /// In en, this message translates to:
  /// **'The login was not confirmed in time.'**
  String get syncLoginTimeout;

  /// No description provided for @syncDerivingKey.
  ///
  /// In en, this message translates to:
  /// **'Deriving the key… this can take a few seconds.'**
  String get syncDerivingKey;

  /// No description provided for @syncWrongPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Wrong sync passphrase.'**
  String get syncWrongPassphrase;

  /// No description provided for @syncPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Sync passphrase'**
  String get syncPassphrase;

  /// No description provided for @syncPassphraseNew.
  ///
  /// In en, this message translates to:
  /// **'Choose a passphrase. You\'ll need it once on every further device. Without it, the data on Nextcloud can\'t be read.'**
  String get syncPassphraseNew;

  /// No description provided for @syncPassphraseJoin.
  ///
  /// In en, this message translates to:
  /// **'Enter the passphrase you chose on your first device.'**
  String get syncPassphraseJoin;

  /// No description provided for @syncPassphraseRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat passphrase'**
  String get syncPassphraseRepeat;

  /// No description provided for @syncPassphraseShort.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get syncPassphraseShort;

  /// No description provided for @syncPassphraseMismatch.
  ///
  /// In en, this message translates to:
  /// **'The passphrases don\'t match'**
  String get syncPassphraseMismatch;

  /// No description provided for @syncLastSuccess.
  ///
  /// In en, this message translates to:
  /// **'Last synced at {time}'**
  String syncLastSuccess(String time);

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @syncDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get syncDisconnect;

  /// No description provided for @syncNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get syncNotConnected;

  /// No description provided for @syncError.
  ///
  /// In en, this message translates to:
  /// **'Sync failed'**
  String get syncError;

  /// No description provided for @syncProxy.
  ///
  /// In en, this message translates to:
  /// **'Proxy for this device (optional, host:port)'**
  String get syncProxy;

  /// No description provided for @navReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get navReports;

  /// No description provided for @timesheet.
  ///
  /// In en, this message translates to:
  /// **'Timesheet'**
  String get timesheet;

  /// No description provided for @orderReport.
  ///
  /// In en, this message translates to:
  /// **'Order report'**
  String get orderReport;

  /// No description provided for @travelReport.
  ///
  /// In en, this message translates to:
  /// **'Travel report'**
  String get travelReport;

  /// No description provided for @statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// No description provided for @backupJson.
  ///
  /// In en, this message translates to:
  /// **'Backup of all data (JSON)'**
  String get backupJson;

  /// No description provided for @savedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved: {path}'**
  String savedTo(String path);

  /// No description provided for @colDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get colDate;

  /// No description provided for @colBreak.
  ///
  /// In en, this message translates to:
  /// **'Break'**
  String get colBreak;

  /// No description provided for @colNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get colNotes;

  /// No description provided for @balanceBefore.
  ///
  /// In en, this message translates to:
  /// **'Balance at start of month'**
  String get balanceBefore;

  /// No description provided for @balanceAfter.
  ///
  /// In en, this message translates to:
  /// **'Balance at end'**
  String get balanceAfter;

  /// No description provided for @homeOfficeDays.
  ///
  /// In en, this message translates to:
  /// **'Home-office days'**
  String get homeOfficeDays;

  /// No description provided for @vacationDaysTaken.
  ///
  /// In en, this message translates to:
  /// **'Vacation days'**
  String get vacationDaysTaken;

  /// No description provided for @workedDays.
  ///
  /// In en, this message translates to:
  /// **'Days worked'**
  String get workedDays;

  /// No description provided for @signature.
  ///
  /// In en, this message translates to:
  /// **'Date, signature'**
  String get signature;

  /// No description provided for @perDiem.
  ///
  /// In en, this message translates to:
  /// **'Meal allowance'**
  String get perDiem;

  /// No description provided for @perDiemPartial.
  ///
  /// In en, this message translates to:
  /// **'partial day'**
  String get perDiemPartial;

  /// No description provided for @perDiemFull.
  ///
  /// In en, this message translates to:
  /// **'full day'**
  String get perDiemFull;

  /// No description provided for @perDiemNone.
  ///
  /// In en, this message translates to:
  /// **'no allowance'**
  String get perDiemNone;

  /// No description provided for @mealsProvided.
  ///
  /// In en, this message translates to:
  /// **'Meals provided'**
  String get mealsProvided;

  /// No description provided for @breakfast.
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get breakfast;

  /// No description provided for @lunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get lunch;

  /// No description provided for @dinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get dinner;

  /// No description provided for @hoursAway.
  ///
  /// In en, this message translates to:
  /// **'Hours away'**
  String get hoursAway;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @noTrips.
  ///
  /// In en, this message translates to:
  /// **'No trips in this month'**
  String get noTrips;

  /// No description provided for @noBookings.
  ///
  /// In en, this message translates to:
  /// **'No project times in this month'**
  String get noBookings;

  /// No description provided for @rateMissing.
  ///
  /// In en, this message translates to:
  /// **'No rate for {country}'**
  String rateMissing(String country);

  /// No description provided for @hoursByProject.
  ///
  /// In en, this message translates to:
  /// **'Hours by project'**
  String get hoursByProject;

  /// No description provided for @weeks.
  ///
  /// In en, this message translates to:
  /// **'Weeks'**
  String get weeks;

  /// No description provided for @previousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get previousMonth;

  /// No description provided for @nextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get nextMonth;

  /// No description provided for @generatedBy.
  ///
  /// In en, this message translates to:
  /// **'Created with TimeTrack on {date}'**
  String generatedBy(String date);

  /// No description provided for @addProjectTime.
  ///
  /// In en, this message translates to:
  /// **'Add project time'**
  String get addProjectTime;

  /// No description provided for @durationHours.
  ///
  /// In en, this message translates to:
  /// **'Duration (h:mm)'**
  String get durationHours;

  /// No description provided for @withClockTime.
  ///
  /// In en, this message translates to:
  /// **'Set a start time'**
  String get withClockTime;

  /// No description provided for @withClockTimeHint.
  ///
  /// In en, this message translates to:
  /// **'Optional; without it only the duration counts'**
  String get withClockTimeHint;

  /// No description provided for @summary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summary;

  /// No description provided for @summaryHint.
  ///
  /// In en, this message translates to:
  /// **'What did you do?'**
  String get summaryHint;

  /// No description provided for @summaryQuestion.
  ///
  /// In en, this message translates to:
  /// **'What did you do for {project}?'**
  String summaryQuestion(String project);

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @activity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activity;

  /// No description provided for @warnProjectOverWork.
  ///
  /// In en, this message translates to:
  /// **'{minutes} more project time than working time'**
  String warnProjectOverWork(String minutes);

  /// No description provided for @switchProject.
  ///
  /// In en, this message translates to:
  /// **'Switch project'**
  String get switchProject;

  /// No description provided for @quickWorking.
  ///
  /// In en, this message translates to:
  /// **'Working'**
  String get quickWorking;

  /// No description provided for @quickOnBreak.
  ///
  /// In en, this message translates to:
  /// **'On a break'**
  String get quickOnBreak;

  /// No description provided for @quickToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get quickToday;

  /// No description provided for @travelWorkday.
  ///
  /// In en, this message translates to:
  /// **'Workdays on a trip'**
  String get travelWorkday;

  /// No description provided for @travelWorkdayHint.
  ///
  /// In en, this message translates to:
  /// **'Target: the account gets your target (e.g. 8:00) however long travel and work took. Actual time: what you worked counts.'**
  String get travelWorkdayHint;

  /// No description provided for @travelWorkdayTarget.
  ///
  /// In en, this message translates to:
  /// **'Target hours'**
  String get travelWorkdayTarget;

  /// No description provided for @travelWorkdayActual.
  ///
  /// In en, this message translates to:
  /// **'Actual time'**
  String get travelWorkdayActual;

  /// No description provided for @travelSaturdayHint.
  ///
  /// In en, this message translates to:
  /// **'Work and travel count as overtime, up to this cap.'**
  String get travelSaturdayHint;

  /// No description provided for @saturdayCapScope.
  ///
  /// In en, this message translates to:
  /// **'Saturday cap covers'**
  String get saturdayCapScope;

  /// No description provided for @capTotal.
  ///
  /// In en, this message translates to:
  /// **'Travel + work'**
  String get capTotal;

  /// No description provided for @capTravelOnly.
  ///
  /// In en, this message translates to:
  /// **'Travel only'**
  String get capTravelOnly;

  /// No description provided for @travelSunday.
  ///
  /// In en, this message translates to:
  /// **'Sundays'**
  String get travelSunday;

  /// No description provided for @travelSundayHoursHint.
  ///
  /// In en, this message translates to:
  /// **'Work and travel count as Sunday/holiday hours for HR (monthly timesheet), not as overtime.'**
  String get travelSundayHoursHint;

  /// No description provided for @travelSundayWorkOnlyHint.
  ///
  /// In en, this message translates to:
  /// **'Work counts as overtime, travel time doesn\'t count.'**
  String get travelSundayWorkOnlyHint;

  /// No description provided for @sundayHours.
  ///
  /// In en, this message translates to:
  /// **'Sunday/holiday hours'**
  String get sundayHours;

  /// No description provided for @sundayWorkOnly.
  ///
  /// In en, this message translates to:
  /// **'Work only'**
  String get sundayWorkOnly;

  /// No description provided for @sundayCap.
  ///
  /// In en, this message translates to:
  /// **'Sunday/holiday hours: max. per day'**
  String get sundayCap;

  /// No description provided for @travelHoliday.
  ///
  /// In en, this message translates to:
  /// **'Public holidays'**
  String get travelHoliday;

  /// No description provided for @likeSunday.
  ///
  /// In en, this message translates to:
  /// **'Like Sunday'**
  String get likeSunday;

  /// No description provided for @likeSaturday.
  ///
  /// In en, this message translates to:
  /// **'Like Saturday'**
  String get likeSaturday;

  /// No description provided for @weekendRules.
  ///
  /// In en, this message translates to:
  /// **'Weekends and public holidays'**
  String get weekendRules;

  /// No description provided for @breakDeducted.
  ///
  /// In en, this message translates to:
  /// **'Missing break deducted: {minutes}'**
  String breakDeducted(String minutes);

  /// No description provided for @timesheetLegend.
  ///
  /// In en, this message translates to:
  /// **'Worked: the time actually worked. Credited: the time that goes into the overtime account; on trips, weekends and public holidays it follows the rules in the settings (Sunday and holiday work is listed separately as Sunday/holiday hours). Balance ± = credited − target.'**
  String get timesheetLegend;

  /// No description provided for @tripProjectNone.
  ///
  /// In en, this message translates to:
  /// **'No project (optional)'**
  String get tripProjectNone;

  /// No description provided for @colProject.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get colProject;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview and download'**
  String get preview;

  /// No description provided for @tripNoProject.
  ///
  /// In en, this message translates to:
  /// **'Trip without a project'**
  String get tripNoProject;

  /// No description provided for @tripBookedTo.
  ///
  /// In en, this message translates to:
  /// **'Booked to {project}'**
  String tripBookedTo(String project);

  /// No description provided for @tripDays.
  ///
  /// In en, this message translates to:
  /// **'Trip days'**
  String get tripDays;

  /// No description provided for @dayBusinessTrip.
  ///
  /// In en, this message translates to:
  /// **'Business trip'**
  String get dayBusinessTrip;

  /// No description provided for @absenceChildSick.
  ///
  /// In en, this message translates to:
  /// **'Child sick day'**
  String get absenceChildSick;

  /// No description provided for @absenceShortTime.
  ///
  /// In en, this message translates to:
  /// **'Short-time work'**
  String get absenceShortTime;

  /// No description provided for @dayType.
  ///
  /// In en, this message translates to:
  /// **'Type of day'**
  String get dayType;

  /// No description provided for @tripDayLocked.
  ///
  /// In en, this message translates to:
  /// **'This day belongs to the trip {trip}. To make it an office or home-office day, change the trip first.'**
  String tripDayLocked(String trip);

  /// No description provided for @editTrip.
  ///
  /// In en, this message translates to:
  /// **'Edit trip'**
  String get editTrip;

  /// No description provided for @tripTimes.
  ///
  /// In en, this message translates to:
  /// **'Travel {travel} · On site {onSite}'**
  String tripTimes(String travel, String onSite);

  /// No description provided for @absenceWorkHint.
  ///
  /// In en, this message translates to:
  /// **'Working time recorded on this day is credited as overtime.'**
  String get absenceWorkHint;

  /// No description provided for @goToToday.
  ///
  /// In en, this message translates to:
  /// **'Go to today'**
  String get goToToday;

  /// No description provided for @assignedTo.
  ///
  /// In en, this message translates to:
  /// **'{minutes} booked to {project}'**
  String assignedTo(String minutes, String project);

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @chooseDayType.
  ///
  /// In en, this message translates to:
  /// **'Day type'**
  String get chooseDayType;

  /// No description provided for @commandPalette.
  ///
  /// In en, this message translates to:
  /// **'Search and actions'**
  String get commandPalette;

  /// No description provided for @commandPaletteHint.
  ///
  /// In en, this message translates to:
  /// **'Action, screen or project …'**
  String get commandPaletteHint;

  /// No description provided for @copiedPreviousDay.
  ///
  /// In en, this message translates to:
  /// **'Previous day copied'**
  String get copiedPreviousDay;

  /// No description provided for @copyPreviousDay.
  ///
  /// In en, this message translates to:
  /// **'Copy previous day'**
  String get copyPreviousDay;

  /// No description provided for @deleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get deleted;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @editDay.
  ///
  /// In en, this message translates to:
  /// **'Edit day'**
  String get editDay;

  /// No description provided for @explainAbsenceCredit.
  ///
  /// In en, this message translates to:
  /// **'Absence credit'**
  String get explainAbsenceCredit;

  /// No description provided for @explainBreakDeducted.
  ///
  /// In en, this message translates to:
  /// **'Break deducted'**
  String get explainBreakDeducted;

  /// No description provided for @explainBreakDeductedHint.
  ///
  /// In en, this message translates to:
  /// **'The required break was missing (ArbZG §4).'**
  String get explainBreakDeductedHint;

  /// No description provided for @explainDeltaMinus.
  ///
  /// In en, this message translates to:
  /// **'Less than the target: this lowers your balance.'**
  String get explainDeltaMinus;

  /// No description provided for @explainDeltaPlus.
  ///
  /// In en, this message translates to:
  /// **'More than the target: this counts as overtime.'**
  String get explainDeltaPlus;

  /// No description provided for @explainDeltaZero.
  ///
  /// In en, this message translates to:
  /// **'Exactly the target: no overtime, no minus.'**
  String get explainDeltaZero;

  /// No description provided for @explainHow.
  ///
  /// In en, this message translates to:
  /// **'How is this calculated?'**
  String get explainHow;

  /// No description provided for @explainRule.
  ///
  /// In en, this message translates to:
  /// **'Rule for this day'**
  String get explainRule;

  /// No description provided for @explainSaturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday: worked time counts as overtime.'**
  String get explainSaturday;

  /// No description provided for @explainSaturdayCapped.
  ///
  /// In en, this message translates to:
  /// **'Saturday: at most {cap} count, {rest} not counted.'**
  String explainSaturdayCapped(String cap, String rest);

  /// No description provided for @explainSundayCounted.
  ///
  /// In en, this message translates to:
  /// **'Sunday/holiday rule: work on site counts as usual.'**
  String get explainSundayCounted;

  /// No description provided for @explainSundayHours.
  ///
  /// In en, this message translates to:
  /// **'Reported to HR for extra pay, not part of the balance.'**
  String get explainSundayHours;

  /// No description provided for @explainSundayNotCounted.
  ///
  /// In en, this message translates to:
  /// **'Sunday/holiday rule: {rest} not counted towards the balance.'**
  String explainSundayNotCounted(String rest);

  /// No description provided for @explainTargetDayOff.
  ///
  /// In en, this message translates to:
  /// **'No scheduled work on this day.'**
  String get explainTargetDayOff;

  /// No description provided for @explainTargetHoliday.
  ///
  /// In en, this message translates to:
  /// **'Public holiday {name}: no target.'**
  String explainTargetHoliday(String name);

  /// No description provided for @explainTargetReduced.
  ///
  /// In en, this message translates to:
  /// **'Lowered by short-time work or an extra day off.'**
  String get explainTargetReduced;

  /// No description provided for @explainTargetSchedule.
  ///
  /// In en, this message translates to:
  /// **'From your work schedule.'**
  String get explainTargetSchedule;

  /// No description provided for @explainTitle.
  ///
  /// In en, this message translates to:
  /// **'How {date} is counted'**
  String explainTitle(String date);

  /// No description provided for @explainTripWorkday.
  ///
  /// In en, this message translates to:
  /// **'Trip on a workday: credited as a normal day ({credit}), however long it was.'**
  String explainTripWorkday(String credit);

  /// No description provided for @fixAddBreak.
  ///
  /// In en, this message translates to:
  /// **'Add break'**
  String get fixAddBreak;

  /// No description provided for @fixAssign.
  ///
  /// In en, this message translates to:
  /// **'Assign'**
  String get fixAssign;

  /// No description provided for @fixSetEnd.
  ///
  /// In en, this message translates to:
  /// **'Set end'**
  String get fixSetEnd;

  /// No description provided for @homeOfficeLimit.
  ///
  /// In en, this message translates to:
  /// **'Limit: {percent} % per month'**
  String homeOfficeLimit(String percent);

  /// No description provided for @homeOfficeOfWorked.
  ///
  /// In en, this message translates to:
  /// **'{home} of {worked} days worked at home'**
  String homeOfficeOfWorked(String home, String worked);

  /// No description provided for @month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get month;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @noLimit.
  ///
  /// In en, this message translates to:
  /// **'No limit'**
  String get noLimit;

  /// No description provided for @ofTarget.
  ///
  /// In en, this message translates to:
  /// **'of {target}'**
  String ofTarget(String target);

  /// No description provided for @openDay.
  ///
  /// In en, this message translates to:
  /// **'Open day'**
  String get openDay;

  /// No description provided for @percentPerMonth.
  ///
  /// In en, this message translates to:
  /// **'{percent} % per month'**
  String percentPerMonth(String percent);

  /// No description provided for @perDaySummary.
  ///
  /// In en, this message translates to:
  /// **'That is {minutes} per workday.'**
  String perDaySummary(String minutes);

  /// No description provided for @quickEntry.
  ///
  /// In en, this message translates to:
  /// **'Quick entry'**
  String get quickEntry;

  /// No description provided for @quickEntryHelp.
  ///
  /// In en, this message translates to:
  /// **'Times, break (p30), place (@home), project, note after \": \"'**
  String get quickEntryHelp;

  /// No description provided for @quickEntryInvalid.
  ///
  /// In en, this message translates to:
  /// **'Add times like 8-16:30 or a duration like 1:30'**
  String get quickEntryInvalid;

  /// No description provided for @quickEntryNoProject.
  ///
  /// In en, this message translates to:
  /// **'no project matches \"{query}\"'**
  String quickEntryNoProject(String query);

  /// No description provided for @quickEntrySaved.
  ///
  /// In en, this message translates to:
  /// **'Entered'**
  String get quickEntrySaved;

  /// No description provided for @saveAsTemplate.
  ///
  /// In en, this message translates to:
  /// **'Save day as template'**
  String get saveAsTemplate;

  /// No description provided for @searchSettings.
  ///
  /// In en, this message translates to:
  /// **'Search settings'**
  String get searchSettings;

  /// No description provided for @setupAgainHint.
  ///
  /// In en, this message translates to:
  /// **'State, working time, balance and home office in four steps'**
  String get setupAgainHint;

  /// No description provided for @setupBalanceHint.
  ///
  /// In en, this message translates to:
  /// **'From which day should the balance count, and what did you bring along?'**
  String get setupBalanceHint;

  /// No description provided for @setupConnectSync.
  ///
  /// In en, this message translates to:
  /// **'Connect Nextcloud'**
  String get setupConnectSync;

  /// No description provided for @setupDone.
  ///
  /// In en, this message translates to:
  /// **'All set'**
  String get setupDone;

  /// No description provided for @setupDoneHint.
  ///
  /// In en, this message translates to:
  /// **'You can change everything later in the settings. Connect Nextcloud to sync your devices.'**
  String get setupDoneHint;

  /// No description provided for @setupHomeOfficeHint.
  ///
  /// In en, this message translates to:
  /// **'How much home office does your employer allow?'**
  String get setupHomeOfficeHint;

  /// No description provided for @setupScheduleHint.
  ///
  /// In en, this message translates to:
  /// **'Your contractual working time and vacation.'**
  String get setupScheduleHint;

  /// No description provided for @setupStart.
  ///
  /// In en, this message translates to:
  /// **'Set up'**
  String get setupStart;

  /// No description provided for @setupStateHint.
  ///
  /// In en, this message translates to:
  /// **'For public holidays.'**
  String get setupStateHint;

  /// No description provided for @setupTitle.
  ///
  /// In en, this message translates to:
  /// **'Setup'**
  String get setupTitle;

  /// No description provided for @startingBalanceHint.
  ///
  /// In en, this message translates to:
  /// **'Overtime carried over, e.g. 12:30 or -2:00'**
  String get startingBalanceHint;

  /// No description provided for @startProjectNamed.
  ///
  /// In en, this message translates to:
  /// **'Start {project}'**
  String startProjectNamed(String project);

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing …'**
  String get syncing;

  /// No description provided for @templateApplied.
  ///
  /// In en, this message translates to:
  /// **'Template \"{name}\" applied'**
  String templateApplied(String name);

  /// No description provided for @templateName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get templateName;

  /// No description provided for @timeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get timeline;

  /// No description provided for @timelineHint.
  ///
  /// In en, this message translates to:
  /// **'Drag the edges to adjust, tap a hatched gap to assign it.'**
  String get timelineHint;

  /// No description provided for @tripStillOpen.
  ///
  /// In en, this message translates to:
  /// **'Trip still open'**
  String get tripStillOpen;

  /// No description provided for @tripStillOpenTo.
  ///
  /// In en, this message translates to:
  /// **'Trip to {destination} still open'**
  String tripStillOpenTo(String destination);

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @vacationCarryOver.
  ///
  /// In en, this message translates to:
  /// **'Vacation days carried over'**
  String get vacationCarryOver;

  /// No description provided for @vacationDaysPerYear.
  ///
  /// In en, this message translates to:
  /// **'Vacation days per year'**
  String get vacationDaysPerYear;

  /// No description provided for @warnUnassigned.
  ///
  /// In en, this message translates to:
  /// **'{minutes} without a project'**
  String warnUnassigned(String minutes);

  /// No description provided for @week.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get week;

  /// No description provided for @weeklyHours.
  ///
  /// In en, this message translates to:
  /// **'Hours per week'**
  String get weeklyHours;

  /// No description provided for @workdaysPerWeek.
  ///
  /// In en, this message translates to:
  /// **'Workdays per week'**
  String get workdaysPerWeek;

  /// No description provided for @showLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get showLess;

  /// No description provided for @moreNotices.
  ///
  /// In en, this message translates to:
  /// **'{count} more notices'**
  String moreNotices(String count);

  /// No description provided for @noticeUnassignedFrom.
  ///
  /// In en, this message translates to:
  /// **'\"Without a project\" from'**
  String get noticeUnassignedFrom;

  /// No description provided for @noticeUnassignedHint.
  ///
  /// In en, this message translates to:
  /// **'Days with less unassigned time get no notice.'**
  String get noticeUnassignedHint;

  /// No description provided for @noticeCatUnassigned.
  ///
  /// In en, this message translates to:
  /// **'Time without a project'**
  String get noticeCatUnassigned;

  /// No description provided for @noticeCatBreaks.
  ///
  /// In en, this message translates to:
  /// **'Missing break (ArbZG §4)'**
  String get noticeCatBreaks;

  /// No description provided for @noticeCatLongDay.
  ///
  /// In en, this message translates to:
  /// **'More than 10 hours (ArbZG §3)'**
  String get noticeCatLongDay;

  /// No description provided for @noticeCatRest.
  ///
  /// In en, this message translates to:
  /// **'Rest under 11 hours (ArbZG §5)'**
  String get noticeCatRest;

  /// No description provided for @noticeCatSunday.
  ///
  /// In en, this message translates to:
  /// **'Work on Sundays and holidays'**
  String get noticeCatSunday;

  /// No description provided for @noticeCatOpenSession.
  ///
  /// In en, this message translates to:
  /// **'Forgotten clock-out'**
  String get noticeCatOpenSession;

  /// No description provided for @noticeCatOverlaps.
  ///
  /// In en, this message translates to:
  /// **'Overlapping entries'**
  String get noticeCatOverlaps;

  /// No description provided for @noticeCatProjectTime.
  ///
  /// In en, this message translates to:
  /// **'Project time outside or above working time'**
  String get noticeCatProjectTime;

  /// No description provided for @noticeCatQuota.
  ///
  /// In en, this message translates to:
  /// **'Home-office limit'**
  String get noticeCatQuota;

  /// No description provided for @noticeCatOpenTrip.
  ///
  /// In en, this message translates to:
  /// **'Trip still open'**
  String get noticeCatOpenTrip;

  /// No description provided for @restoreNotices.
  ///
  /// In en, this message translates to:
  /// **'Show dismissed notices again'**
  String get restoreNotices;

  /// No description provided for @dismissedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} dismissed'**
  String dismissedCount(String count);

  /// No description provided for @noticeDismissed.
  ///
  /// In en, this message translates to:
  /// **'Notice hidden; the calendar keeps a small marker'**
  String get noticeDismissed;

  /// No description provided for @hiddenNotices.
  ///
  /// In en, this message translates to:
  /// **'{count} hidden notices'**
  String hiddenNotices(String count);

  /// No description provided for @noticeCategoryOff.
  ///
  /// In en, this message translates to:
  /// **'Switched off in the settings'**
  String get noticeCategoryOff;

  /// No description provided for @showAgain.
  ///
  /// In en, this message translates to:
  /// **'Show again'**
  String get showAgain;

  /// No description provided for @hasNotices.
  ///
  /// In en, this message translates to:
  /// **'Has notices'**
  String get hasNotices;

  /// No description provided for @bookProjectTime.
  ///
  /// In en, this message translates to:
  /// **'Book project time'**
  String get bookProjectTime;

  /// No description provided for @editProjectTime.
  ///
  /// In en, this message translates to:
  /// **'Edit project time'**
  String get editProjectTime;

  /// No description provided for @projectSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Project: name, number, order, client …'**
  String get projectSearchHint;

  /// No description provided for @recentlyUsed.
  ///
  /// In en, this message translates to:
  /// **'Recently used'**
  String get recentlyUsed;

  /// No description provided for @changeProject.
  ///
  /// In en, this message translates to:
  /// **'Change project'**
  String get changeProject;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @restOfDay.
  ///
  /// In en, this message translates to:
  /// **'Rest of the day {minutes}'**
  String restOfDay(String minutes);

  /// No description provided for @whatWasDone.
  ///
  /// In en, this message translates to:
  /// **'What was done?'**
  String get whatWasDone;

  /// No description provided for @book.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get book;

  /// No description provided for @legOutbound.
  ///
  /// In en, this message translates to:
  /// **'Outbound'**
  String get legOutbound;

  /// No description provided for @legOnSite.
  ///
  /// In en, this message translates to:
  /// **'At the customer'**
  String get legOnSite;

  /// No description provided for @legInbound.
  ///
  /// In en, this message translates to:
  /// **'Return'**
  String get legInbound;

  /// No description provided for @creditedAccount.
  ///
  /// In en, this message translates to:
  /// **'Credited (account)'**
  String get creditedAccount;

  /// No description provided for @travelRecord.
  ///
  /// In en, this message translates to:
  /// **'Travel record'**
  String get travelRecord;

  /// No description provided for @travelRecordEmpty.
  ///
  /// In en, this message translates to:
  /// **'No outbound, on-site or return times yet.'**
  String get travelRecordEmpty;

  /// No description provided for @accountCredits.
  ///
  /// In en, this message translates to:
  /// **'Overtime account: {minutes} credited'**
  String accountCredits(String minutes);

  /// No description provided for @accountSection.
  ///
  /// In en, this message translates to:
  /// **'Overtime account'**
  String get accountSection;

  /// No description provided for @stepStartOutbound.
  ///
  /// In en, this message translates to:
  /// **'Start travelling there'**
  String get stepStartOutbound;

  /// No description provided for @stepArriveOnSite.
  ///
  /// In en, this message translates to:
  /// **'Arrived at the customer'**
  String get stepArriveOnSite;

  /// No description provided for @stepEndOutbound.
  ///
  /// In en, this message translates to:
  /// **'End travel there'**
  String get stepEndOutbound;

  /// No description provided for @stepStartOnSite.
  ///
  /// In en, this message translates to:
  /// **'Start at the customer'**
  String get stepStartOnSite;

  /// No description provided for @stepEndOnSite.
  ///
  /// In en, this message translates to:
  /// **'Done at the customer'**
  String get stepEndOnSite;

  /// No description provided for @stepStartInbound.
  ///
  /// In en, this message translates to:
  /// **'Start travelling back'**
  String get stepStartInbound;

  /// No description provided for @stepEndInbound.
  ///
  /// In en, this message translates to:
  /// **'Back – end travel'**
  String get stepEndInbound;

  /// No description provided for @accountSectionHint.
  ///
  /// In en, this message translates to:
  /// **'What your overtime account is credited. The real times (project time, travel and time at the customer) are recorded separately and go into the reports.'**
  String get accountSectionHint;

  /// No description provided for @travelRulesHint.
  ///
  /// In en, this message translates to:
  /// **'Only for the overtime account. The travel record always shows the exact outbound, customer and return times.'**
  String get travelRulesHint;

  /// No description provided for @weekendRulesHint.
  ///
  /// In en, this message translates to:
  /// **'For every Saturday, Sunday and holiday, on a trip or not. Only for the overtime account.'**
  String get weekendRulesHint;

  /// No description provided for @recordsSection.
  ///
  /// In en, this message translates to:
  /// **'Records'**
  String get recordsSection;

  /// No description provided for @recordsSectionHint.
  ///
  /// In en, this message translates to:
  /// **'Recorded to the minute as it happened, independent of what the account credits.'**
  String get recordsSectionHint;

  /// No description provided for @travelRecordHint.
  ///
  /// In en, this message translates to:
  /// **'Outbound, at the customer and return with times, hours away and per-diem'**
  String get travelRecordHint;

  /// No description provided for @projectTimesRecord.
  ///
  /// In en, this message translates to:
  /// **'Project times'**
  String get projectTimesRecord;

  /// No description provided for @projectTimesRecordHint.
  ///
  /// In en, this message translates to:
  /// **'In 15-minute steps per order; timesheet and order report'**
  String get projectTimesRecordHint;

  /// No description provided for @backAgainToLeave.
  ///
  /// In en, this message translates to:
  /// **'Press back again to leave'**
  String get backAgainToLeave;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
