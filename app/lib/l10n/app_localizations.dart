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

  /// No description provided for @askStampTime.
  ///
  /// In en, this message translates to:
  /// **'Ask for the time when stamping'**
  String get askStampTime;

  /// No description provided for @askStampTimeHint.
  ///
  /// In en, this message translates to:
  /// **'When clocking in or out and at breaks; the current time is suggested'**
  String get askStampTimeHint;

  /// No description provided for @stampTimeFuture.
  ///
  /// In en, this message translates to:
  /// **'That time is in the future.'**
  String get stampTimeFuture;

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
  /// **'Service trip on a weekday: counts as a normal workday ({credit}), however long.'**
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

  /// No description provided for @backAgainToLeave.
  ///
  /// In en, this message translates to:
  /// **'Press back again to leave'**
  String get backAgainToLeave;

  /// No description provided for @perDiemRates.
  ///
  /// In en, this message translates to:
  /// **'Per-diem rates'**
  String get perDiemRates;

  /// No description provided for @perDiemRatesHint.
  ///
  /// In en, this message translates to:
  /// **'The BMF rates of every country and city from 2026 are built in; search to see them. A trip day uses the newest rate of its place valid on that day; your own rows supersede the built-in ones. Provided meals reduce it: breakfast by 20 %, lunch and dinner by 40 % each of the full-day rate.'**
  String get perDiemRatesHint;

  /// No description provided for @perDiemRatesSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} countries'**
  String perDiemRatesSummary(String count);

  /// No description provided for @partialDayRate.
  ///
  /// In en, this message translates to:
  /// **'Partial day (more than 8 h, arrival or departure)'**
  String get partialDayRate;

  /// No description provided for @fullDayRate.
  ///
  /// In en, this message translates to:
  /// **'Full day (24 h)'**
  String get fullDayRate;

  /// No description provided for @newRate.
  ///
  /// In en, this message translates to:
  /// **'New rate'**
  String get newRate;

  /// No description provided for @countryIso.
  ///
  /// In en, this message translates to:
  /// **'Country (ISO code, e.g. AT)'**
  String get countryIso;

  /// No description provided for @builtInRate.
  ///
  /// In en, this message translates to:
  /// **'Built-in'**
  String get builtInRate;

  /// No description provided for @rateInUse.
  ///
  /// In en, this message translates to:
  /// **'in use today'**
  String get rateInUse;

  /// No description provided for @rateAmounts.
  ///
  /// In en, this message translates to:
  /// **'{partial} partial · {full} full'**
  String rateAmounts(String partial, String full);

  /// No description provided for @restoreBackup.
  ///
  /// In en, this message translates to:
  /// **'Load backup'**
  String get restoreBackup;

  /// No description provided for @restoreBackupHint.
  ///
  /// In en, this message translates to:
  /// **'Restore from a JSON backup; you choose how'**
  String get restoreBackupHint;

  /// No description provided for @notABackup.
  ///
  /// In en, this message translates to:
  /// **'This file isn\'t a TimeTrack backup that this version can read.'**
  String get notABackup;

  /// No description provided for @restoreFrom.
  ///
  /// In en, this message translates to:
  /// **'Backup from {date} · {count} entries'**
  String restoreFrom(String date, String count);

  /// No description provided for @restoreChoose.
  ///
  /// In en, this message translates to:
  /// **'How should the backup be loaded?'**
  String get restoreChoose;

  /// No description provided for @restoreMerge.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get restoreMerge;

  /// No description provided for @restoreMergeHint.
  ///
  /// In en, this message translates to:
  /// **'Like a sync: whatever is missing comes back from the backup, everything changed later stays.'**
  String get restoreMergeHint;

  /// No description provided for @restoreReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get restoreReplace;

  /// No description provided for @restoreReplaceHint.
  ///
  /// In en, this message translates to:
  /// **'Your data becomes exactly the backup, on all devices. Everything entered or changed after the backup is lost.'**
  String get restoreReplaceHint;

  /// No description provided for @restoreCounts.
  ///
  /// In en, this message translates to:
  /// **'{added} back · {changed} changed · {deleted} deleted'**
  String restoreCounts(String added, String changed, String deleted);

  /// No description provided for @restoreNoChange.
  ///
  /// In en, this message translates to:
  /// **'no changes'**
  String get restoreNoChange;

  /// No description provided for @restoreSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed: entries from other devices that haven\'t arrived yet are not taken into account.'**
  String get restoreSyncFailed;

  /// No description provided for @restoreTip.
  ///
  /// In en, this message translates to:
  /// **'Tip: save a current backup first.'**
  String get restoreTip;

  /// No description provided for @restoreDone.
  ///
  /// In en, this message translates to:
  /// **'Backup loaded: {counts}'**
  String restoreDone(String counts);

  /// No description provided for @syncLog.
  ///
  /// In en, this message translates to:
  /// **'Sync log'**
  String get syncLog;

  /// No description provided for @syncLogHint.
  ///
  /// In en, this message translates to:
  /// **'Only on this device, the last 100 cycles'**
  String get syncLogHint;

  /// No description provided for @syncLogEmpty.
  ///
  /// In en, this message translates to:
  /// **'No sync cycles yet.'**
  String get syncLogEmpty;

  /// No description provided for @syncLogIdle.
  ///
  /// In en, this message translates to:
  /// **'Nothing to sync'**
  String get syncLogIdle;

  /// No description provided for @syncLogFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get syncLogFailed;

  /// No description provided for @syncLogUp.
  ///
  /// In en, this message translates to:
  /// **'↑ {count} changes sent'**
  String syncLogUp(String count);

  /// No description provided for @syncLogDown.
  ///
  /// In en, this message translates to:
  /// **'↓ {count} changes received'**
  String syncLogDown(String count);

  /// No description provided for @syncLogResolved.
  ///
  /// In en, this message translates to:
  /// **'{count} entries corrected'**
  String syncLogResolved(String count);

  /// No description provided for @syncLogBackground.
  ///
  /// In en, this message translates to:
  /// **'in the background'**
  String get syncLogBackground;

  /// No description provided for @syncLogClear.
  ///
  /// In en, this message translates to:
  /// **'Clear log'**
  String get syncLogClear;

  /// No description provided for @syncLogTimes.
  ///
  /// In en, this message translates to:
  /// **'{count}×'**
  String syncLogTimes(String count);

  /// No description provided for @syncLogNetwork.
  ///
  /// In en, this message translates to:
  /// **'after a network change'**
  String get syncLogNetwork;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'TimeTrack {version} is available'**
  String updateAvailable(String version);

  /// No description provided for @updateNotificationText.
  ///
  /// In en, this message translates to:
  /// **'Tap to see what\'s new and update.'**
  String get updateNotificationText;

  /// No description provided for @updatesChannel.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get updatesChannel;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateNow;

  /// No description provided for @updateWhatsNew.
  ///
  /// In en, this message translates to:
  /// **'What\'s new'**
  String get updateWhatsNew;

  /// No description provided for @updateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateLater;

  /// No description provided for @updateSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip this version'**
  String get updateSkip;

  /// No description provided for @updateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading TimeTrack {version} … {percent}'**
  String updateDownloading(String version, String percent);

  /// No description provided for @updateReady.
  ///
  /// In en, this message translates to:
  /// **'TimeTrack {version} is installed. Restart to use it.'**
  String updateReady(String version);

  /// No description provided for @updateRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get updateRestart;

  /// No description provided for @updateFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed: {error}'**
  String updateFailed(String error);

  /// No description provided for @updateRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get updateRetry;

  /// No description provided for @updateNeedsPermission.
  ///
  /// In en, this message translates to:
  /// **'Allow TimeTrack to install unknown apps, then tap Update again.'**
  String get updateNeedsPermission;

  /// No description provided for @updateNoNotes.
  ///
  /// In en, this message translates to:
  /// **'No release notes.'**
  String get updateNoNotes;

  /// No description provided for @checkForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkForUpdates;

  /// No description provided for @installedVersion.
  ///
  /// In en, this message translates to:
  /// **'Installed: {version}'**
  String installedVersion(String version);

  /// No description provided for @lastChecked.
  ///
  /// In en, this message translates to:
  /// **'last checked {when}'**
  String lastChecked(String when);

  /// No description provided for @autoUpdateCheck.
  ///
  /// In en, this message translates to:
  /// **'Check for updates automatically'**
  String get autoUpdateCheck;

  /// No description provided for @autoUpdateCheckHint.
  ///
  /// In en, this message translates to:
  /// **'At most once a day. Nothing is installed without asking.'**
  String get autoUpdateCheckHint;

  /// No description provided for @upToDate.
  ///
  /// In en, this message translates to:
  /// **'TimeTrack is up to date.'**
  String get upToDate;

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach GitHub.'**
  String get updateCheckFailed;

  /// No description provided for @releasePage.
  ///
  /// In en, this message translates to:
  /// **'All versions on GitHub'**
  String get releasePage;

  /// No description provided for @workPc.
  ///
  /// In en, this message translates to:
  /// **'Work PC'**
  String get workPc;

  /// No description provided for @workPcHint.
  ///
  /// In en, this message translates to:
  /// **'Asks after you sign in to Windows whether to start tracking for today (turns on “Start with Windows” too).'**
  String get workPcHint;

  /// No description provided for @workPcFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t change the Windows autostart.'**
  String get workPcFailed;

  /// No description provided for @startTrackingTitle.
  ///
  /// In en, this message translates to:
  /// **'Start tracking for today?'**
  String get startTrackingTitle;

  /// No description provided for @startTrackingText.
  ///
  /// In en, this message translates to:
  /// **'No working time recorded today yet.'**
  String get startTrackingText;

  /// No description provided for @startTrackingStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startTrackingStart;

  /// No description provided for @startTrackingNotToday.
  ///
  /// In en, this message translates to:
  /// **'Not today'**
  String get startTrackingNotToday;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @wallpaperColors.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper colours'**
  String get wallpaperColors;

  /// No description provided for @wallpaperColorsHint.
  ///
  /// In en, this message translates to:
  /// **'Off: TimeTrack\'s own colours.'**
  String get wallpaperColorsHint;

  /// No description provided for @keyboardShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get keyboardShortcuts;

  /// No description provided for @keysClock.
  ///
  /// In en, this message translates to:
  /// **'Clock in or out'**
  String get keysClock;

  /// No description provided for @keysBreak.
  ///
  /// In en, this message translates to:
  /// **'Start or end a break'**
  String get keysBreak;

  /// No description provided for @keysTabs.
  ///
  /// In en, this message translates to:
  /// **'Today, Calendar, Planner, Projects, Reports'**
  String get keysTabs;

  /// No description provided for @keysPrevNext.
  ///
  /// In en, this message translates to:
  /// **'Previous or next week, month or day'**
  String get keysPrevNext;

  /// No description provided for @keysWeekMonth.
  ///
  /// In en, this message translates to:
  /// **'Switch between week and month'**
  String get keysWeekMonth;

  /// No description provided for @keysHelp.
  ///
  /// In en, this message translates to:
  /// **'This overview'**
  String get keysHelp;

  /// No description provided for @forecastTarget.
  ///
  /// In en, this message translates to:
  /// **'Target reached at {time}'**
  String forecastTarget(String time);

  /// No description provided for @forecastBreak.
  ///
  /// In en, this message translates to:
  /// **'incl. {minutes} min break'**
  String forecastBreak(int minutes);

  /// No description provided for @forecastLimit.
  ///
  /// In en, this message translates to:
  /// **'10 h at {time}'**
  String forecastLimit(String time);

  /// No description provided for @reminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get reminders;

  /// No description provided for @remindBreak.
  ///
  /// In en, this message translates to:
  /// **'Break due'**
  String get remindBreak;

  /// No description provided for @remindBreakHint.
  ///
  /// In en, this message translates to:
  /// **'After 5:45 h without a break'**
  String get remindBreakHint;

  /// No description provided for @remindLongDay.
  ///
  /// In en, this message translates to:
  /// **'Long day'**
  String get remindLongDay;

  /// No description provided for @remindLongDayHint.
  ///
  /// In en, this message translates to:
  /// **'At 9:45 h, before reaching 10 h'**
  String get remindLongDayHint;

  /// No description provided for @reminderBreakTitle.
  ///
  /// In en, this message translates to:
  /// **'Time for a break'**
  String get reminderBreakTitle;

  /// No description provided for @reminderBreakText.
  ///
  /// In en, this message translates to:
  /// **'5:45 h without a break – after 6 h a break is required.'**
  String get reminderBreakText;

  /// No description provided for @reminderLongDayTitle.
  ///
  /// In en, this message translates to:
  /// **'Almost 10 hours'**
  String get reminderLongDayTitle;

  /// No description provided for @reminderLongDayText.
  ///
  /// In en, this message translates to:
  /// **'Still clocked in? More than 10 hours of work a day aren\'t allowed.'**
  String get reminderLongDayText;

  /// No description provided for @forgottenTitle.
  ///
  /// In en, this message translates to:
  /// **'Still clocked in?'**
  String get forgottenTitle;

  /// No description provided for @forgottenText.
  ///
  /// In en, this message translates to:
  /// **'Clocked in since {since}. When did you finish?'**
  String forgottenText(String since);

  /// No description provided for @yesterdayAt.
  ///
  /// In en, this message translates to:
  /// **'yesterday, {time}'**
  String yesterdayAt(String time);

  /// No description provided for @suggestLastActivity.
  ///
  /// In en, this message translates to:
  /// **'Last activity'**
  String get suggestLastActivity;

  /// No description provided for @suggestTarget.
  ///
  /// In en, this message translates to:
  /// **'Target reached'**
  String get suggestTarget;

  /// No description provided for @suggestUsualEnd.
  ///
  /// In en, this message translates to:
  /// **'Usual finish'**
  String get suggestUsualEnd;

  /// No description provided for @otherTime.
  ///
  /// In en, this message translates to:
  /// **'Other time…'**
  String get otherTime;

  /// No description provided for @stillWorking.
  ///
  /// In en, this message translates to:
  /// **'Still working'**
  String get stillWorking;

  /// No description provided for @forgottenTimeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Pick a time between {from} and now.'**
  String forgottenTimeInvalid(String from);

  /// No description provided for @clockedOutAt.
  ///
  /// In en, this message translates to:
  /// **'Clocked out at {time}'**
  String clockedOutAt(String time);

  /// No description provided for @weekCheck.
  ///
  /// In en, this message translates to:
  /// **'Check week'**
  String get weekCheck;

  /// No description provided for @monthCheck.
  ///
  /// In en, this message translates to:
  /// **'Check month'**
  String get monthCheck;

  /// No description provided for @noticeCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 notice} other{{count} notices}}'**
  String noticeCount(int count);

  /// No description provided for @noticeDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{on 1 day} other{on {count} days}}'**
  String noticeDays(int count);

  /// No description provided for @weekComplete.
  ///
  /// In en, this message translates to:
  /// **'Week complete'**
  String get weekComplete;

  /// No description provided for @monthComplete.
  ///
  /// In en, this message translates to:
  /// **'Month complete'**
  String get monthComplete;

  /// No description provided for @reviewStep.
  ///
  /// In en, this message translates to:
  /// **'{index} of {total}'**
  String reviewStep(int index, int total);

  /// No description provided for @hideNotice.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hideNotice;

  /// No description provided for @allDone.
  ///
  /// In en, this message translates to:
  /// **'All done'**
  String get allDone;

  /// No description provided for @skippedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} skipped'**
  String skippedCount(int count);

  /// No description provided for @projectBudget.
  ///
  /// In en, this message translates to:
  /// **'Budget (hours)'**
  String get projectBudget;

  /// No description provided for @projectBudgetHint.
  ///
  /// In en, this message translates to:
  /// **'Empty: no budget'**
  String get projectBudgetHint;

  /// No description provided for @invalidHours.
  ///
  /// In en, this message translates to:
  /// **'Hours like 40, 37.5 or 37:30'**
  String get invalidHours;

  /// No description provided for @noticeCatBudget.
  ///
  /// In en, this message translates to:
  /// **'Project budget'**
  String get noticeCatBudget;

  /// No description provided for @warnBudgetNear.
  ///
  /// In en, this message translates to:
  /// **'{project}: 80 % of the budget ({budget}) used'**
  String warnBudgetNear(String project, String budget);

  /// No description provided for @warnBudgetOver.
  ///
  /// In en, this message translates to:
  /// **'{project}: budget ({budget}) exceeded'**
  String warnBudgetOver(String project, String budget);

  /// No description provided for @openProject.
  ///
  /// In en, this message translates to:
  /// **'Open project'**
  String get openProject;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get thisMonth;

  /// No description provided for @thisYear.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get thisYear;

  /// No description provided for @budgetUsed.
  ///
  /// In en, this message translates to:
  /// **'{used} of {budget} ({percent} %)'**
  String budgetUsed(String used, String budget, int percent);

  /// No description provided for @budgetLeft.
  ///
  /// In en, this message translates to:
  /// **'{left} left'**
  String budgetLeft(String left);

  /// No description provided for @budgetOverBy.
  ///
  /// In en, this message translates to:
  /// **'{over} over'**
  String budgetOverBy(String over);

  /// No description provided for @projectHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get projectHistory;

  /// No description provided for @lastTwelveWeeks.
  ///
  /// In en, this message translates to:
  /// **'Recent weeks'**
  String get lastTwelveWeeks;

  /// No description provided for @startTimer.
  ///
  /// In en, this message translates to:
  /// **'Start timer'**
  String get startTimer;

  /// No description provided for @projectRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get projectRunning;

  /// No description provided for @noTimeBooked.
  ///
  /// In en, this message translates to:
  /// **'No time booked yet'**
  String get noTimeBooked;

  /// No description provided for @showAllDays.
  ///
  /// In en, this message translates to:
  /// **'Show all {count} days'**
  String showAllDays(int count);

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// No description provided for @unarchive.
  ///
  /// In en, this message translates to:
  /// **'Restore from archive'**
  String get unarchive;

  /// No description provided for @budget.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get budget;

  /// No description provided for @vacationPlanner.
  ///
  /// In en, this message translates to:
  /// **'Vacation planner'**
  String get vacationPlanner;

  /// No description provided for @bridgeDays.
  ///
  /// In en, this message translates to:
  /// **'Bridge days'**
  String get bridgeDays;

  /// No description provided for @bridgeTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day off} other{{count} days off}} → {free} days free'**
  String bridgeTitle(num count, int free);

  /// No description provided for @bridgeBook.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get bridgeBook;

  /// No description provided for @bridgeBooked.
  ///
  /// In en, this message translates to:
  /// **'Vacation booked'**
  String get bridgeBooked;

  /// No description provided for @noBridges.
  ///
  /// In en, this message translates to:
  /// **'No more bridge days in {year}'**
  String noBridges(int year);

  /// No description provided for @absencesOfYear.
  ///
  /// In en, this message translates to:
  /// **'Absences {year}'**
  String absencesOfYear(int year);

  /// No description provided for @bridgeDay.
  ///
  /// In en, this message translates to:
  /// **'Bridge day'**
  String get bridgeDay;

  /// No description provided for @otherAbsence.
  ///
  /// In en, this message translates to:
  /// **'Other absence'**
  String get otherAbsence;

  /// No description provided for @trayOpen.
  ///
  /// In en, this message translates to:
  /// **'Open TimeTrack'**
  String get trayOpen;

  /// No description provided for @trayQuit.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get trayQuit;

  /// No description provided for @closeToTray.
  ///
  /// In en, this message translates to:
  /// **'Keep running in the tray'**
  String get closeToTray;

  /// No description provided for @closeToTrayHint.
  ///
  /// In en, this message translates to:
  /// **'Closing hides the window; the tray icon\'s menu has Quit.'**
  String get closeToTrayHint;

  /// No description provided for @defaultBreakStart.
  ///
  /// In en, this message translates to:
  /// **'Usual break: start'**
  String get defaultBreakStart;

  /// No description provided for @defaultBreakLength.
  ///
  /// In en, this message translates to:
  /// **'Usual break: length'**
  String get defaultBreakLength;

  /// No description provided for @defaultBreakHint.
  ///
  /// In en, this message translates to:
  /// **'Suggested when you add a break'**
  String get defaultBreakHint;

  /// No description provided for @beforeBalanceStart.
  ///
  /// In en, this message translates to:
  /// **'Before the balance starts ({date}): no target, no overtime'**
  String beforeBalanceStart(String date);

  /// No description provided for @autostart.
  ///
  /// In en, this message translates to:
  /// **'Start with Windows'**
  String get autostart;

  /// No description provided for @autostartHint.
  ///
  /// In en, this message translates to:
  /// **'Starts TimeTrack when you sign in to Windows (this user only).'**
  String get autostartHint;

  /// No description provided for @removeDayType.
  ///
  /// In en, this message translates to:
  /// **'Remove day type'**
  String get removeDayType;

  /// No description provided for @dayTypeRemoved.
  ///
  /// In en, this message translates to:
  /// **'Day type removed'**
  String get dayTypeRemoved;

  /// No description provided for @tripDayRemove.
  ///
  /// In en, this message translates to:
  /// **'This day belongs to the trip {trip}. To remove it, change the trip.'**
  String tripDayRemove(String trip);

  /// No description provided for @bookingTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer to booking system'**
  String get bookingTransfer;

  /// No description provided for @bookingSystem.
  ///
  /// In en, this message translates to:
  /// **'Booking system'**
  String get bookingSystem;

  /// No description provided for @bookingUrl.
  ///
  /// In en, this message translates to:
  /// **'Booking system (address)'**
  String get bookingUrl;

  /// No description provided for @bookingUrlHint.
  ///
  /// In en, this message translates to:
  /// **'Page for the weekly project time; saved only on this PC'**
  String get bookingUrlHint;

  /// No description provided for @bookingPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer week {week}'**
  String bookingPreviewTitle(String week);

  /// No description provided for @bookingOpen.
  ///
  /// In en, this message translates to:
  /// **'Open in booking system'**
  String get bookingOpen;

  /// No description provided for @bookingNoRows.
  ///
  /// In en, this message translates to:
  /// **'No project time with a project number in this week.'**
  String get bookingNoRows;

  /// No description provided for @bookingRunningTimer.
  ///
  /// In en, this message translates to:
  /// **'A project timer is still running; its time counts up to now.'**
  String get bookingRunningTimer;

  /// No description provided for @bookingUnassigned.
  ///
  /// In en, this message translates to:
  /// **'{day}: {time} without a project, not transferred'**
  String bookingUnassigned(String day, String time);

  /// No description provided for @bookingRounding.
  ///
  /// In en, this message translates to:
  /// **'Rounded to half hours: {rounded} instead of {exact}'**
  String bookingRounding(String rounded, String exact);

  /// No description provided for @bookingSkipped.
  ///
  /// In en, this message translates to:
  /// **'{name} ({time}) has no project number and is not transferred'**
  String bookingSkipped(String name, String time);

  /// No description provided for @bookingSum.
  ///
  /// In en, this message translates to:
  /// **'Sum'**
  String get bookingSum;

  /// No description provided for @bookingTransferredOn.
  ///
  /// In en, this message translates to:
  /// **'Transferred on {date}'**
  String bookingTransferredOn(String date);

  /// No description provided for @bookingChangedSince.
  ///
  /// In en, this message translates to:
  /// **'Changed since the transfer on {date}'**
  String bookingChangedSince(String date);

  /// No description provided for @bookingNotTransferred.
  ///
  /// In en, this message translates to:
  /// **'Not transferred yet'**
  String get bookingNotTransferred;

  /// No description provided for @bookingLoading.
  ///
  /// In en, this message translates to:
  /// **'Opening the booking page…'**
  String get bookingLoading;

  /// No description provided for @bookingFilling.
  ///
  /// In en, this message translates to:
  /// **'Filling in…'**
  String get bookingFilling;

  /// No description provided for @bookingFilled.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 row} other{{count} rows}} filled. Add Kostengruppe and Position, check the hours, then click Buchen.'**
  String bookingFilled(int count);

  /// No description provided for @bookingUnknownProjects.
  ///
  /// In en, this message translates to:
  /// **'Unknown in the booking system, not filled: {projects}'**
  String bookingUnknownProjects(String projects);

  /// No description provided for @bookingLockedDays.
  ///
  /// In en, this message translates to:
  /// **'Booking period locked, not filled: {days}'**
  String bookingLockedDays(String days);

  /// No description provided for @bookingReplaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace the entries?'**
  String get bookingReplaceTitle;

  /// No description provided for @bookingReplaceBody.
  ///
  /// In en, this message translates to:
  /// **'The form already contains entries. Replace them with this week?'**
  String get bookingReplaceBody;

  /// No description provided for @bookingReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get bookingReplace;

  /// No description provided for @bookingKept.
  ///
  /// In en, this message translates to:
  /// **'Form left unchanged.'**
  String get bookingKept;

  /// No description provided for @bookingBooked.
  ///
  /// In en, this message translates to:
  /// **'Booking started; the week is marked as transferred.'**
  String get bookingBooked;

  /// No description provided for @bookingAskBooked.
  ///
  /// In en, this message translates to:
  /// **'Was the week booked?'**
  String get bookingAskBooked;

  /// No description provided for @bookingAskBookedBody.
  ///
  /// In en, this message translates to:
  /// **'If you clicked Buchen, TimeTrack marks the week as transferred.'**
  String get bookingAskBookedBody;

  /// No description provided for @bookingWasBooked.
  ///
  /// In en, this message translates to:
  /// **'Yes, booked'**
  String get bookingWasBooked;

  /// No description provided for @bookingNotBooked.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get bookingNotBooked;

  /// No description provided for @bookingErrorTimeout.
  ///
  /// In en, this message translates to:
  /// **'The booking page didn\'t get ready within 30 s. Check the address and the company network.'**
  String get bookingErrorTimeout;

  /// No description provided for @bookingErrorPage.
  ///
  /// In en, this message translates to:
  /// **'The page looks different than expected ({detail}); nothing was filled.'**
  String bookingErrorPage(String detail);

  /// No description provided for @bookingErrorFill.
  ///
  /// In en, this message translates to:
  /// **'Filling in failed: {detail}'**
  String bookingErrorFill(String detail);

  /// No description provided for @bookingErrorLoad.
  ///
  /// In en, this message translates to:
  /// **'The page couldn\'t be loaded ({detail}).'**
  String bookingErrorLoad(String detail);

  /// No description provided for @bookingNoRuntime.
  ///
  /// In en, this message translates to:
  /// **'The Microsoft Edge WebView2 Runtime is missing; please install it.'**
  String get bookingNoRuntime;

  /// No description provided for @bookingClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get bookingClose;

  /// No description provided for @serviceTrip.
  ///
  /// In en, this message translates to:
  /// **'Service or commissioning'**
  String get serviceTrip;

  /// No description provided for @serviceTripHint.
  ///
  /// In en, this message translates to:
  /// **'Work on a site: weekdays count the target, Saturdays at most 8 h; the extra work is paid as a supplement. Off for a fair, training or meeting: the real time counts, up to 10 h.'**
  String get serviceTripHint;

  /// No description provided for @serviceSaturdayCap.
  ///
  /// In en, this message translates to:
  /// **'Saturday on a service trip: max. hours'**
  String get serviceSaturdayCap;

  /// No description provided for @serviceSaturdayCapHint.
  ///
  /// In en, this message translates to:
  /// **'Weekdays of a service trip always count the target; Saturdays the real time up to this cap.'**
  String get serviceSaturdayCapHint;

  /// No description provided for @dayCap.
  ///
  /// In en, this message translates to:
  /// **'Other trips and Saturdays: max. hours'**
  String get dayCap;

  /// No description provided for @dayCapHint.
  ///
  /// In en, this message translates to:
  /// **'Trips without service work and Saturdays without a trip: the real time, travel included, up to this cap.'**
  String get dayCapHint;

  /// No description provided for @servicePayDays.
  ///
  /// In en, this message translates to:
  /// **'Days with trip supplement'**
  String get servicePayDays;

  /// No description provided for @explainOtherTripWorkday.
  ///
  /// In en, this message translates to:
  /// **'Business trip without service work: the real time counts, travel included, at most {cap}.'**
  String explainOtherTripWorkday(String cap);

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @monthReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report the overtime balance for {month}'**
  String monthReportTitle(String month);

  /// No description provided for @monthReportText.
  ///
  /// In en, this message translates to:
  /// **'Balance on {date}: {balance}. Enter it in the company system.'**
  String monthReportText(String date, String balance);

  /// No description provided for @monthReportReminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder: report overtime'**
  String get monthReportReminder;

  /// No description provided for @monthReportReminderHint.
  ///
  /// In en, this message translates to:
  /// **'After a change of month, reminds you of last month\'s closing balance'**
  String get monthReportReminderHint;

  /// No description provided for @noticeCatBalanceZone.
  ///
  /// In en, this message translates to:
  /// **'Time account zone'**
  String get noticeCatBalanceZone;

  /// No description provided for @warnBalanceYellow.
  ///
  /// In en, this message translates to:
  /// **'Time account in the yellow zone ({balance})'**
  String warnBalanceYellow(String balance);

  /// No description provided for @warnBalanceRed.
  ///
  /// In en, this message translates to:
  /// **'Time account in the red zone ({balance})'**
  String warnBalanceRed(String balance);

  /// No description provided for @warnBalanceOverLimit.
  ///
  /// In en, this message translates to:
  /// **'Time account over its limit ({balance})'**
  String warnBalanceOverLimit(String balance);

  /// No description provided for @zoneGreen.
  ///
  /// In en, this message translates to:
  /// **'Green zone'**
  String get zoneGreen;

  /// No description provided for @zoneYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow zone'**
  String get zoneYellow;

  /// No description provided for @zoneRed.
  ///
  /// In en, this message translates to:
  /// **'Red zone'**
  String get zoneRed;

  /// No description provided for @zoneOverLimit.
  ///
  /// In en, this message translates to:
  /// **'Over the limit'**
  String get zoneOverLimit;

  /// No description provided for @zoneYellowFrom.
  ///
  /// In en, this message translates to:
  /// **'Yellow above'**
  String get zoneYellowFrom;

  /// No description provided for @zoneRedFrom.
  ///
  /// In en, this message translates to:
  /// **'Red above'**
  String get zoneRedFrom;

  /// No description provided for @zoneMax.
  ///
  /// In en, this message translates to:
  /// **'Limit'**
  String get zoneMax;

  /// No description provided for @zonePlus.
  ///
  /// In en, this message translates to:
  /// **'Plus'**
  String get zonePlus;

  /// No description provided for @zoneMinus.
  ///
  /// In en, this message translates to:
  /// **'Minus'**
  String get zoneMinus;

  /// No description provided for @balanceZones.
  ///
  /// In en, this message translates to:
  /// **'Time account zones'**
  String get balanceZones;

  /// No description provided for @balanceZonesHint.
  ///
  /// In en, this message translates to:
  /// **'Off · your employer\'s green/yellow/red limits'**
  String get balanceZonesHint;

  /// No description provided for @balanceZonesDialogHint.
  ///
  /// In en, this message translates to:
  /// **'Whole hours above the target (plus) or below it (minus). Empty: no limit.'**
  String get balanceZonesDialogHint;

  /// No description provided for @vacationCarryDeadline.
  ///
  /// In en, this message translates to:
  /// **'Take carried-over vacation by'**
  String get vacationCarryDeadline;

  /// No description provided for @vacationCarryDeadlineHint.
  ///
  /// In en, this message translates to:
  /// **'Shows on Today how many days of it are not planned yet'**
  String get vacationCarryDeadlineHint;

  /// No description provided for @deadlineOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get deadlineOff;

  /// No description provided for @deadlineEndOf.
  ///
  /// In en, this message translates to:
  /// **'End of {month}'**
  String deadlineEndOf(String month);

  /// No description provided for @vacationCarryTitle.
  ///
  /// In en, this message translates to:
  /// **'Vacation left from {year}'**
  String vacationCarryTitle(String year);

  /// No description provided for @vacationCarryText.
  ///
  /// In en, this message translates to:
  /// **'{days} days still to take or plan by {date}.'**
  String vacationCarryText(String days, String date);

  /// No description provided for @vacationCarryOverInto.
  ///
  /// In en, this message translates to:
  /// **'Vacation carried into {year}'**
  String vacationCarryOverInto(String year);

  /// No description provided for @sectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Working time & account'**
  String get sectionAccount;

  /// No description provided for @sectionClocking.
  ///
  /// In en, this message translates to:
  /// **'Clocking & breaks'**
  String get sectionClocking;

  /// No description provided for @sectionTravel.
  ///
  /// In en, this message translates to:
  /// **'Trips & supplements'**
  String get sectionTravel;

  /// No description provided for @sectionApp.
  ///
  /// In en, this message translates to:
  /// **'Appearance & updates'**
  String get sectionApp;

  /// No description provided for @groupTarget.
  ///
  /// In en, this message translates to:
  /// **'Target hours'**
  String get groupTarget;

  /// No description provided for @groupVacation.
  ///
  /// In en, this message translates to:
  /// **'Vacation'**
  String get groupVacation;

  /// No description provided for @groupClocking.
  ///
  /// In en, this message translates to:
  /// **'Clocking'**
  String get groupClocking;

  /// No description provided for @groupBreaks.
  ///
  /// In en, this message translates to:
  /// **'Breaks'**
  String get groupBreaks;

  /// No description provided for @groupExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get groupExpenses;

  /// No description provided for @groupDisplay.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get groupDisplay;

  /// No description provided for @groupUpdates.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get groupUpdates;

  /// No description provided for @noticesActive.
  ///
  /// In en, this message translates to:
  /// **'{on} of {all} on'**
  String noticesActive(String on, String all);

  /// No description provided for @workPcSummary.
  ///
  /// In en, this message translates to:
  /// **'Autostart, tray, monthly reminder, booking'**
  String get workPcSummary;

  /// No description provided for @specialHolidayHours.
  ///
  /// In en, this message translates to:
  /// **'Special holiday hours'**
  String get specialHolidayHours;

  /// No description provided for @nightHours.
  ///
  /// In en, this message translates to:
  /// **'Night hours'**
  String get nightHours;

  /// No description provided for @specialDays.
  ///
  /// In en, this message translates to:
  /// **'Special holidays'**
  String get specialDays;

  /// No description provided for @specialDaysHint.
  ///
  /// In en, this message translates to:
  /// **'Their hours are listed apart from the Sunday/holiday hours, e.g. for a higher supplement'**
  String get specialDaysHint;

  /// No description provided for @specialDaysNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get specialDaysNone;

  /// No description provided for @specialDayNewYear.
  ///
  /// In en, this message translates to:
  /// **'New Year\'s Day'**
  String get specialDayNewYear;

  /// No description provided for @specialDayEasterSunday.
  ///
  /// In en, this message translates to:
  /// **'Easter Sunday'**
  String get specialDayEasterSunday;

  /// No description provided for @specialDayEasterMonday.
  ///
  /// In en, this message translates to:
  /// **'Easter Monday'**
  String get specialDayEasterMonday;

  /// No description provided for @specialDayMayDay.
  ///
  /// In en, this message translates to:
  /// **'1 May'**
  String get specialDayMayDay;

  /// No description provided for @specialDayWhitSunday.
  ///
  /// In en, this message translates to:
  /// **'Whit Sunday'**
  String get specialDayWhitSunday;

  /// No description provided for @specialDayWhitMonday.
  ///
  /// In en, this message translates to:
  /// **'Whit Monday'**
  String get specialDayWhitMonday;

  /// No description provided for @specialDayChristmasDay.
  ///
  /// In en, this message translates to:
  /// **'Christmas Day'**
  String get specialDayChristmasDay;

  /// No description provided for @specialDayBoxingDay.
  ///
  /// In en, this message translates to:
  /// **'Boxing Day'**
  String get specialDayBoxingDay;

  /// No description provided for @groupNightWork.
  ///
  /// In en, this message translates to:
  /// **'Night work'**
  String get groupNightWork;

  /// No description provided for @nightWorkCredit.
  ///
  /// In en, this message translates to:
  /// **'Night hours (11 pm–6 am, from 2 h)'**
  String get nightWorkCredit;

  /// No description provided for @nightCount.
  ///
  /// In en, this message translates to:
  /// **'On the account'**
  String get nightCount;

  /// No description provided for @nightExclude.
  ///
  /// In en, this message translates to:
  /// **'Not on the account'**
  String get nightExclude;

  /// No description provided for @nightCountHint.
  ///
  /// In en, this message translates to:
  /// **'Listed and credited like any other work.'**
  String get nightCountHint;

  /// No description provided for @nightExcludeHint.
  ///
  /// In en, this message translates to:
  /// **'Paid out: listed, but not credited to the overtime account. Service-trip workdays keep their target.'**
  String get nightExcludeHint;

  /// No description provided for @explainNightExcluded.
  ///
  /// In en, this message translates to:
  /// **'Paid out, not on the overtime account.'**
  String get explainNightExcluded;

  /// No description provided for @explainNightCounted.
  ///
  /// In en, this message translates to:
  /// **'Work between 11 pm and 6 am in a night of at least 2 h; reported for the supplement.'**
  String get explainNightCounted;

  /// No description provided for @explainSpecialHolidayHours.
  ///
  /// In en, this message translates to:
  /// **'Reported apart from the Sunday/holiday hours (higher supplement), not on the overtime account.'**
  String get explainSpecialHolidayHours;

  /// No description provided for @monthReportSupplements.
  ///
  /// In en, this message translates to:
  /// **'Supplements: {items}.'**
  String monthReportSupplements(String items);

  /// No description provided for @columnSpecialHours.
  ///
  /// In en, this message translates to:
  /// **'Special'**
  String get columnSpecialHours;

  /// No description provided for @columnNightHours.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get columnNightHours;

  /// No description provided for @searchCountry.
  ///
  /// In en, this message translates to:
  /// **'Search country or city'**
  String get searchCountry;

  /// No description provided for @restOfCountry.
  ///
  /// In en, this message translates to:
  /// **'Elsewhere in the country'**
  String get restOfCountry;

  /// No description provided for @placeHint.
  ///
  /// In en, this message translates to:
  /// **'Picks the per-diem and lodging rate'**
  String get placeHint;

  /// No description provided for @otherPlaces.
  ///
  /// In en, this message translates to:
  /// **'Other places'**
  String get otherPlaces;

  /// No description provided for @placeFrom.
  ///
  /// In en, this message translates to:
  /// **'From {date}'**
  String placeFrom(String date);

  /// No description provided for @changePlace.
  ///
  /// In en, this message translates to:
  /// **'Change place'**
  String get changePlace;

  /// No description provided for @changePlaceFrom.
  ///
  /// In en, this message translates to:
  /// **'From which day?'**
  String get changePlaceFrom;

  /// No description provided for @lodging.
  ///
  /// In en, this message translates to:
  /// **'Lodging'**
  String get lodging;

  /// No description provided for @lodgingCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get lodgingCompany;

  /// No description provided for @lodgingFlat.
  ///
  /// In en, this message translates to:
  /// **'Lump sum'**
  String get lodgingFlat;

  /// No description provided for @lodgingReceipt.
  ///
  /// In en, this message translates to:
  /// **'Receipts'**
  String get lodgingReceipt;

  /// No description provided for @lodgingReceiptTotal.
  ///
  /// In en, this message translates to:
  /// **'Receipts total'**
  String get lodgingReceiptTotal;

  /// No description provided for @lodgingFlatHint.
  ///
  /// In en, this message translates to:
  /// **'No lump sum for nights on a plane, train or ship.'**
  String get lodgingFlatHint;

  /// No description provided for @lodgingRate.
  ///
  /// In en, this message translates to:
  /// **'Lodging per night (optional)'**
  String get lodgingRate;

  /// No description provided for @carKm.
  ///
  /// In en, this message translates to:
  /// **'Own car'**
  String get carKm;

  /// No description provided for @markClaimed.
  ///
  /// In en, this message translates to:
  /// **'Claimed'**
  String get markClaimed;

  /// No description provided for @claimedOn.
  ///
  /// In en, this message translates to:
  /// **'Claimed on {date}'**
  String claimedOn(String date);

  /// No description provided for @claimTitle.
  ///
  /// In en, this message translates to:
  /// **'Claim the expenses of {trip} by {date}'**
  String claimTitle(String trip, String date);

  /// No description provided for @tripExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expense report'**
  String get tripExpenses;

  /// No description provided for @place.
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get place;

  /// No description provided for @siteAllowance.
  ///
  /// In en, this message translates to:
  /// **'Site allowance'**
  String get siteAllowance;

  /// No description provided for @siteAllowanceHint.
  ///
  /// In en, this message translates to:
  /// **'The site allowance is paid with the salary (taxable), not with the expense claim.'**
  String get siteAllowanceHint;

  /// No description provided for @siteAllowanceRatesHint.
  ///
  /// In en, this message translates to:
  /// **'Per site day of a service trip, from the first to the last site day once there are enough in a row. Country * covers all others.'**
  String get siteAllowanceRatesHint;

  /// No description provided for @siteAllowanceSummary.
  ///
  /// In en, this message translates to:
  /// **'From {days} site days in a row'**
  String siteAllowanceSummary(String days);

  /// No description provided for @siteAllowanceMinDays.
  ///
  /// In en, this message translates to:
  /// **'Site allowance from … site days in a row'**
  String get siteAllowanceMinDays;

  /// No description provided for @siteAllowanceCountryHint.
  ///
  /// In en, this message translates to:
  /// **'ISO code, or * for all other countries'**
  String get siteAllowanceCountryHint;

  /// No description provided for @allOtherCountries.
  ///
  /// In en, this message translates to:
  /// **'All other countries'**
  String get allOtherCountries;

  /// No description provided for @perSiteDay.
  ///
  /// In en, this message translates to:
  /// **'Per site day'**
  String get perSiteDay;

  /// No description provided for @mileageRate.
  ///
  /// In en, this message translates to:
  /// **'Mileage (own car)'**
  String get mileageRate;

  /// No description provided for @mileage.
  ///
  /// In en, this message translates to:
  /// **'Mileage'**
  String get mileage;

  /// No description provided for @laundryAfterDays.
  ///
  /// In en, this message translates to:
  /// **'Laundry on trips of'**
  String get laundryAfterDays;

  /// No description provided for @laundryHint.
  ///
  /// In en, this message translates to:
  /// **'Laundry can be claimed for this trip.'**
  String get laundryHint;

  /// No description provided for @moreThanDays.
  ///
  /// In en, this message translates to:
  /// **'more than {days} days'**
  String moreThanDays(String days);

  /// No description provided for @claimDeadlineMonths.
  ///
  /// In en, this message translates to:
  /// **'Claim expenses within'**
  String get claimDeadlineMonths;

  /// No description provided for @claimDeadlineHint.
  ///
  /// In en, this message translates to:
  /// **'Today reminds you after each trip until it is marked as claimed'**
  String get claimDeadlineHint;

  /// No description provided for @claimDeadline.
  ///
  /// In en, this message translates to:
  /// **'Claim by'**
  String get claimDeadline;

  /// No description provided for @monthsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} months'**
  String monthsCount(String count);

  /// No description provided for @claimTotal.
  ///
  /// In en, this message translates to:
  /// **'Claim total'**
  String get claimTotal;

  /// No description provided for @nightsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} nights'**
  String nightsCount(String count);

  /// No description provided for @daysCount.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String daysCount(String count);

  /// No description provided for @cityOptional.
  ///
  /// In en, this message translates to:
  /// **'City (optional)'**
  String get cityOptional;

  /// No description provided for @noticeCatWeekLimit.
  ///
  /// In en, this message translates to:
  /// **'Weekly limits'**
  String get noticeCatWeekLimit;

  /// No description provided for @warnWeekOverMax.
  ///
  /// In en, this message translates to:
  /// **'Week with {minutes} worked: above the weekly maximum'**
  String warnWeekOverMax(String minutes);

  /// No description provided for @warnWeekAverage.
  ///
  /// In en, this message translates to:
  /// **'Weekly average {minutes}: above the limit'**
  String warnWeekAverage(String minutes);

  /// No description provided for @weekWorkedOfMax.
  ///
  /// In en, this message translates to:
  /// **'Worked {worked} of max. {max}'**
  String weekWorkedOfMax(String worked, String max);

  /// No description provided for @weekAverageOf.
  ///
  /// In en, this message translates to:
  /// **'Average of {weeks} weeks {average} (limit {limit})'**
  String weekAverageOf(String weeks, String average, String limit);

  /// No description provided for @groupWeekLimits.
  ///
  /// In en, this message translates to:
  /// **'Weekly limits'**
  String get groupWeekLimits;

  /// No description provided for @weekMaxSetting.
  ///
  /// In en, this message translates to:
  /// **'Most per week'**
  String get weekMaxSetting;

  /// No description provided for @weekAverageSetting.
  ///
  /// In en, this message translates to:
  /// **'Average over {weeks} weeks at most'**
  String weekAverageSetting(String weeks);

  /// No description provided for @weekLimitsHint.
  ///
  /// In en, this message translates to:
  /// **'All recorded work including travel, without breaks (§ 3 ArbZG). 0 switches it off.'**
  String get weekLimitsHint;

  /// No description provided for @addWorkTime.
  ///
  /// In en, this message translates to:
  /// **'Add working time'**
  String get addWorkTime;

  /// No description provided for @dashOfTarget.
  ///
  /// In en, this message translates to:
  /// **'of {target}'**
  String dashOfTarget(String target);

  /// No description provided for @dashMonthDelta.
  ///
  /// In en, this message translates to:
  /// **'{delta} this month'**
  String dashMonthDelta(String delta);

  /// No description provided for @dashDaysOf.
  ///
  /// In en, this message translates to:
  /// **'of {total} days left'**
  String dashDaysOf(String total);

  /// No description provided for @dashQuotaWeek.
  ///
  /// In en, this message translates to:
  /// **'{used} of {allowed} days this week'**
  String dashQuotaWeek(String used, String allowed);

  /// No description provided for @dashQuotaMonth.
  ///
  /// In en, this message translates to:
  /// **'{used} of {allowed} days this month'**
  String dashQuotaMonth(String used, String allowed);

  /// No description provided for @dashDaysLeft.
  ///
  /// In en, this message translates to:
  /// **'{days} left'**
  String dashDaysLeft(String days);

  /// No description provided for @balanceHistory.
  ///
  /// In en, this message translates to:
  /// **'Balance by month'**
  String get balanceHistory;

  /// No description provided for @balanceCountedSince.
  ///
  /// In en, this message translates to:
  /// **'Counted since {date}, starting with {balance}'**
  String balanceCountedSince(String date, String balance);

  /// No description provided for @dashAccount.
  ///
  /// In en, this message translates to:
  /// **'Time account'**
  String get dashAccount;

  /// No description provided for @nextVacationIn.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Vacation from tomorrow} other{Vacation in {count} days}} · {days, plural, =1{1 day} other{{length} days}}'**
  String nextVacationIn(int count, num days, String length);

  /// No description provided for @remindTarget.
  ///
  /// In en, this message translates to:
  /// **'Target reached'**
  String get remindTarget;

  /// No description provided for @remindTargetHint.
  ///
  /// In en, this message translates to:
  /// **'When today\'s target time is done'**
  String get remindTargetHint;

  /// No description provided for @reminderTargetTitle.
  ///
  /// In en, this message translates to:
  /// **'Target reached'**
  String get reminderTargetTitle;

  /// No description provided for @reminderTargetText.
  ///
  /// In en, this message translates to:
  /// **'You can call it a day – today\'s target is done.'**
  String get reminderTargetText;

  /// No description provided for @patternsTitle.
  ///
  /// In en, this message translates to:
  /// **'Worth a look'**
  String get patternsTitle;

  /// No description provided for @patternMissingBreak.
  ///
  /// In en, this message translates to:
  /// **'{count}× too little break – step out more often?'**
  String patternMissingBreak(int count);

  /// No description provided for @patternLongDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}} over 10 h – the Working Hours Act doesn\'t allow that'**
  String patternLongDays(int count);

  /// No description provided for @patternShortRest.
  ///
  /// In en, this message translates to:
  /// **'{count}× less than 11 h rest between two working days'**
  String patternShortRest(int count);

  /// No description provided for @patternSundayWork.
  ///
  /// In en, this message translates to:
  /// **'Worked on {count, plural, =1{1 Sunday or holiday} other{{count} Sundays and holidays}}'**
  String patternSundayWork(int count);

  /// No description provided for @patternLateFinish.
  ///
  /// In en, this message translates to:
  /// **'Finished after 8 pm {count} times – treat yourself to an early evening'**
  String patternLateFinish(int count);

  /// No description provided for @patternAllBreaksKept.
  ///
  /// In en, this message translates to:
  /// **'Every break kept – well done!'**
  String get patternAllBreaksKept;

  /// No description provided for @returnOpen.
  ///
  /// In en, this message translates to:
  /// **'Still travelling: leave the return open'**
  String get returnOpen;

  /// No description provided for @tripOrder.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get tripOrder;

  /// No description provided for @tripOrderHint.
  ///
  /// In en, this message translates to:
  /// **'The trip is billed through this order'**
  String get tripOrderHint;

  /// No description provided for @tripOrderInstallation.
  ///
  /// In en, this message translates to:
  /// **'Installation order'**
  String get tripOrderInstallation;

  /// No description provided for @tripOrderWarranty.
  ///
  /// In en, this message translates to:
  /// **'Warranty order'**
  String get tripOrderWarranty;

  /// No description provided for @tripOrderService.
  ///
  /// In en, this message translates to:
  /// **'Service order'**
  String get tripOrderService;

  /// No description provided for @tripNote.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get tripNote;

  /// No description provided for @tripNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Anything else about the trip'**
  String get tripNoteHint;

  /// No description provided for @tripDates.
  ///
  /// In en, this message translates to:
  /// **'Trip dates'**
  String get tripDates;

  /// No description provided for @tripDatesFrom.
  ///
  /// In en, this message translates to:
  /// **'from {date}'**
  String tripDatesFrom(String date);

  /// No description provided for @pickTripStart.
  ///
  /// In en, this message translates to:
  /// **'Tap the departure day'**
  String get pickTripStart;

  /// No description provided for @pickTripEnd.
  ///
  /// In en, this message translates to:
  /// **'Tap the return day'**
  String get pickTripEnd;

  /// No description provided for @acceptNotice.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get acceptNotice;

  /// No description provided for @noticeAccepted.
  ///
  /// In en, this message translates to:
  /// **'Notice accepted; it won\'t be reported again'**
  String get noticeAccepted;

  /// No description provided for @acceptedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} accepted'**
  String acceptedCount(String count);

  /// No description provided for @acceptAllHidden.
  ///
  /// In en, this message translates to:
  /// **'Accept hidden notices'**
  String get acceptAllHidden;

  /// No description provided for @acceptAllHiddenHint.
  ///
  /// In en, this message translates to:
  /// **'They also leave the calendar and the day view'**
  String get acceptAllHiddenHint;

  /// No description provided for @restoreAccepted.
  ///
  /// In en, this message translates to:
  /// **'Report accepted notices again'**
  String get restoreAccepted;

  /// No description provided for @navPlanner.
  ///
  /// In en, this message translates to:
  /// **'Planner'**
  String get navPlanner;

  /// No description provided for @plannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Trips & absences'**
  String get plannerTitle;

  /// No description provided for @plannerAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get plannerAll;

  /// No description provided for @plannerUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Coming up'**
  String get plannerUpcoming;

  /// No description provided for @plannerPast.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get plannerPast;

  /// No description provided for @plannerNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get plannerNew;

  /// No description provided for @plannerEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing entered for {year}'**
  String plannerEmpty(int year);

  /// No description provided for @tripsInYear.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{trip} other{trips}} · {days, plural, =1{1 day} other{{days} days}} away'**
  String tripsInYear(int count, int days);

  /// No description provided for @claimsOpen.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 trip still to claim} other{{count} trips still to claim}}'**
  String claimsOpen(int count);

  /// No description provided for @claimsAllDone.
  ///
  /// In en, this message translates to:
  /// **'All claimed'**
  String get claimsAllDone;

  /// No description provided for @notClaimed.
  ///
  /// In en, this message translates to:
  /// **'Not claimed yet'**
  String get notClaimed;

  /// No description provided for @daysUnit.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{day} other{days}}'**
  String daysUnit(num count);

  /// No description provided for @startsIn.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{today} =1{tomorrow} other{in {count} days}}'**
  String startsIn(int count);

  /// No description provided for @awaySince.
  ///
  /// In en, this message translates to:
  /// **'away since {date}'**
  String awaySince(String date);

  /// No description provided for @plannerMore.
  ///
  /// In en, this message translates to:
  /// **'Show {count} more'**
  String plannerMore(int count);

  /// No description provided for @halfDayEves.
  ///
  /// In en, this message translates to:
  /// **'Christmas Eve and New Year\'s Eve are half days'**
  String get halfDayEves;

  /// No description provided for @halfDayEvesHint.
  ///
  /// In en, this message translates to:
  /// **'Half the target; vacation there counts at most ½ day'**
  String get halfDayEvesHint;

  /// No description provided for @explainTargetHalfDay.
  ///
  /// In en, this message translates to:
  /// **'{name}: half a day.'**
  String explainTargetHalfDay(String name);

  /// No description provided for @absenceDates.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get absenceDates;

  /// No description provided for @pickAbsenceStart.
  ///
  /// In en, this message translates to:
  /// **'Tap the first day'**
  String get pickAbsenceStart;

  /// No description provided for @pickAbsenceEnd.
  ///
  /// In en, this message translates to:
  /// **'Tap the last day'**
  String get pickAbsenceEnd;

  /// No description provided for @absenceDaysUsed.
  ///
  /// In en, this message translates to:
  /// **'Vacation days: {days}'**
  String absenceDaysUsed(String days);

  /// No description provided for @schoolHolidays.
  ///
  /// In en, this message translates to:
  /// **'School holidays'**
  String get schoolHolidays;

  /// No description provided for @schoolHolidaysNone.
  ///
  /// In en, this message translates to:
  /// **'No school holidays known for {year} yet.'**
  String schoolHolidaysNone(int year);

  /// No description provided for @schoolHolidaysSource.
  ///
  /// In en, this message translates to:
  /// **'Source: OpenHolidays API (ODbL)'**
  String get schoolHolidaysSource;

  /// No description provided for @planVacation.
  ///
  /// In en, this message translates to:
  /// **'Enter vacation'**
  String get planVacation;

  /// No description provided for @schoolHolidaysNoState.
  ///
  /// In en, this message translates to:
  /// **'Choose your federal state in the settings to see its school holidays here.'**
  String get schoolHolidaysNoState;
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
