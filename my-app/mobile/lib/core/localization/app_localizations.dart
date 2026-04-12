import 'package:flutter/material.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [
    Locale('sv', 'SE'),
    Locale('en', 'US'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final localizations =
        Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(localizations != null, 'AppLocalizations not found in context');
    return localizations!;
  }

  bool get _isSwedish => locale.languageCode == 'sv';
  String get localeName => _isSwedish ? 'sv_SE' : 'en_US';

  String get english => _isSwedish ? 'Engelska' : 'English';
  String get swedish => _isSwedish ? 'Svenska' : 'Swedish';
  String get helperRole => _isSwedish ? 'Hjälpare' : 'Helper';
  String get recyclerRole => _isSwedish ? 'Återvinnare' : 'Recycler';
  String roleLabel(String role) => role == 'Helper' ? helperRole : recyclerRole;

  String get notificationFallbackTitle =>
      _isSwedish ? 'Notis' : 'Notification';
  String get viewAction => _isSwedish ? 'VISA' : 'VIEW';

  String get appTagline => _isSwedish
      ? 'Boka upphämtningar, hantera förfrågningar och gör återvinningen enkel.'
      : 'Schedule pickups, manage requests, and keep recycling simple.';
  String get logIn => _isSwedish ? 'Logga in' : 'Log in';
  String get createAccount =>
      _isSwedish ? 'Skapa konto' : 'Create account';
  String createRoleAccount(String role) => _isSwedish
      ? 'Skapa ditt konto som ${roleLabel(role).toLowerCase()}'
      : 'Create your ${roleLabel(role)} account';
  String continueAsRole(String role) => _isSwedish
      ? 'Fortsätt som ${roleLabel(role).toLowerCase()}'
      : 'Continue as ${roleLabel(role)}';
  String get signUpDescription => _isSwedish
      ? 'Använd din e-post för att skapa ett konto. Vi sparar ditt namn för en mer personlig upplevelse.'
      : 'Use your email to create an account and we will store your name for a personal experience.';
  String get signInDescription => _isSwedish
      ? 'Logga in med e-postadressen som är kopplad till ditt konto.'
      : 'Sign in with the email address connected to your account.';
  String get fullName => _isSwedish ? 'Fullständigt namn' : 'Full name';
  String get enterFullName =>
      _isSwedish ? 'Ange ditt fullständiga namn' : 'Enter your full name';
  String get pleaseEnterName =>
      _isSwedish ? 'Ange ditt namn' : 'Please enter your name';
  String get email => 'Email';
  String get pleaseEnterEmail =>
      _isSwedish ? 'Ange din e-postadress' : 'Please enter your email';
  String get pleaseEnterValidEmail => _isSwedish
      ? 'Ange en giltig e-postadress'
      : 'Please enter a valid email';
  String get password => _isSwedish ? 'Lösenord' : 'Password';
  String get createStrongPassword => _isSwedish
      ? 'Skapa ett starkt lösenord'
      : 'Create a strong password';
  String get enterPassword =>
      _isSwedish ? 'Ange ditt lösenord' : 'Enter your password';
  String get hidePassword =>
      _isSwedish ? 'Dölj lösenord' : 'Hide password';
  String get showPassword =>
      _isSwedish ? 'Visa lösenord' : 'Show password';
  String get pleaseEnterPassword =>
      _isSwedish ? 'Ange ditt lösenord' : 'Please enter your password';
  String get passwordMinLength => _isSwedish
      ? 'Lösenordet måste vara minst 8 tecken'
      : 'Password must be at least 8 characters';
  String get passwordLowercase => _isSwedish
      ? 'Måste innehålla minst en liten bokstav'
      : 'Must contain at least one lowercase letter';
  String get passwordUppercase => _isSwedish
      ? 'Måste innehålla minst en stor bokstav'
      : 'Must contain at least one uppercase letter';
  String get passwordNumber => _isSwedish
      ? 'Måste innehålla minst en siffra'
      : 'Must contain at least one number';
  String switchToRole(String role) => _isSwedish
      ? 'Byt till ${roleLabel(role).toLowerCase()}'
      : 'Switch to ${roleLabel(role)}';
  String get alreadyHaveAccount => _isSwedish
      ? 'Har du redan ett konto? Logga in'
      : 'Already have an account? Log in';
  String get newToPanta => _isSwedish
      ? 'Ny på Panta? Skapa ett konto'
      : 'New to Panta? Create an account';
  String get platformTagline => _isSwedish
      ? 'Byggd för smidig och pålitlig upphämtningsplanering på iOS, Android och webben.'
      : 'Built for clean, reliable pickup scheduling across iOS, Android, and web.';
  String loginFailed(String error) =>
      _isSwedish ? 'Inloggningen misslyckades: $error' : 'Login failed: $error';
  String signUpFailed(String error) =>
      _isSwedish ? 'Registreringen misslyckades: $error' : 'Sign up failed: $error';
  String get confirmYourEmail =>
      _isSwedish ? 'Bekräfta din e-post' : 'Confirm your email';
  String get verificationCodeDescription => _isSwedish
      ? 'Ange verifieringskoden som skickades till din e-postadress.'
      : 'Enter the verification code that was sent to your email address.';
  String get confirmationCode =>
      _isSwedish ? 'Bekräftelsekod' : 'Confirmation code';
  String get cancel => _isSwedish ? 'Avbryt' : 'Cancel';
  String get confirm => _isSwedish ? 'Bekräfta' : 'Confirm';
  String confirmationFailed(String error) => _isSwedish
      ? 'Bekräftelsen misslyckades: $error'
      : 'Confirmation failed: $error';
  String loginFailedAfterConfirmation(String error) => _isSwedish
      ? 'Inloggningen efter bekräftelsen misslyckades: $error'
      : 'Login failed after confirmation: $error';

  String get home => _isSwedish ? 'Hem' : 'Home';
  String get history => _isSwedish ? 'Historik' : 'History';
  String get profile => _isSwedish ? 'Profil' : 'Profile';
  String get recycleNow => _isSwedish ? 'Återvinn nu' : 'Recycle Now';
  String welcomeBack([String? name]) {
    if (name == null || name.isEmpty) {
      return _isSwedish ? 'Välkommen tillbaka!' : 'Welcome Back!';
    }
    return _isSwedish
        ? 'Välkommen tillbaka, $name!'
        : 'Welcome Back, $name!';
  }

  String get ongoingRequests =>
      _isSwedish ? 'Pågående förfrågningar' : 'Ongoing Requests';
  String get noOngoingRequests => _isSwedish
      ? 'Inga pågående återvinningsförfrågningar.\nBörja återvinna redan idag!'
      : 'No ongoing recycling requests.\nStart recycling today!';
  String get userHistoryTitle => _isSwedish ? 'Historik' : 'History';
  String get waitingForHelper =>
      _isSwedish ? 'Väntar på hjälpare' : 'Waiting for Helper';
  String get helperOnTheWay =>
      _isSwedish ? 'Hjälparen är på väg' : 'Helper on the way';
  String get pickedUp => _isSwedish ? 'Upphämtad' : 'Picked Up';
  String get rateHelper => _isSwedish ? 'Betygsätt hjälparen' : 'Rate Helper';
  String get rateYourHelper =>
      _isSwedish ? 'Betygsätt din hjälpare' : 'Rate your Helper';
  String get howWasPickupService => _isSwedish
      ? 'Hur fungerade upphämtningen?'
      : 'How was the pickup service?';
  String get optionalCommentHint => _isSwedish
      ? 'Valfri kommentar (t.ex. Toppenhjälp!)'
      : 'Optional comment (e.g. Great job!)';
  String get submit => _isSwedish ? 'Skicka' : 'Submit';
  String get thankYouForRating => _isSwedish
      ? 'Tack för ditt betyg!'
      : 'Thank you for your rating!';

  String get available => _isSwedish ? 'Tillgängliga' : 'Available';
  String get myJobs => _isSwedish ? 'Mina jobb' : 'My Jobs';
  String get pickupHistory =>
      _isSwedish ? 'Upphämtningshistorik' : 'Pickup History';
  String get closestJobsMessage => _isSwedish
      ? 'Närmaste jobben visas först utifrån din nuvarande plats.'
      : 'Closest jobs are shown first based on your current location.';
  String get enableLocationMessage => _isSwedish
      ? 'Aktivera platsåtkomst för att sortera tillgängliga jobb efter avstånd.'
      : 'Enable location access to sort available jobs by distance.';
  String get noJobsAvailable => _isSwedish
      ? 'Inga jobb tillgängliga just nu.'
      : 'No jobs available right now.';
  String get myActiveJobs =>
      _isSwedish ? 'Mina aktiva jobb' : 'My Active Jobs';
  String get noActiveJobs =>
      _isSwedish ? 'Inga aktiva jobb' : 'No Active Jobs';
  String get availableTabPrompt => _isSwedish
      ? 'Gå till fliken "Tillgängliga" för att hitta återvinningsförfrågningar i närheten.'
      : 'Go to the \'Available\' tab to find recycling requests nearby.';
  String get noCompletedJobsYet =>
      _isSwedish ? 'Inga avslutade jobb ännu.' : 'No completed jobs yet.';
  String get distanceAwareSortingEnabled => _isSwedish
      ? 'Avståndsbaserad sortering är aktiverad för denna upphämtning.'
      : 'Distance-aware sorting is enabled for this pickup.';
  String get completed => _isSwedish ? 'Avslutad' : 'Completed';
  String get naLabel => _isSwedish ? 'Ej tillgängligt' : 'N/A';
  String ratedValue(String rating) =>
      _isSwedish ? 'Betyg $rating' : 'Rated $rating';
  String get couldNotAcceptPickup => _isSwedish
      ? 'Det gick inte att acceptera upphämtningen.'
      : 'Could not accept this pickup.';
  String get jobAcceptedHeadToMyJobs => _isSwedish
      ? 'Jobbet accepterades! Gå till Mina jobb.'
      : 'Job Accepted! Head to My Jobs.';
  String get acceptPickup =>
      _isSwedish ? 'Acceptera upphämtning' : 'Accept Pickup';
  String get cancelPickupQuestion =>
      _isSwedish ? 'Avbryta upphämtning?' : 'Cancel pickup?';
  String get cancelPickupDescription => _isSwedish
      ? 'Det här jobbet blir tillgängligt igen för andra hjälpare och återvinnaren får en notis.'
      : 'This job will become available again for another helper, and the recycler will be notified.';
  String get keepJob => _isSwedish ? 'Behåll jobbet' : 'Keep Job';
  String get cancelPickup =>
      _isSwedish ? 'Avbryt upphämtning' : 'Cancel Pickup';
  String get couldNotCancelPickup => _isSwedish
      ? 'Det gick inte att avbryta upphämtningen.'
      : 'Could not cancel this pickup.';
  String get pickupCancelledAvailableAgain => _isSwedish
      ? 'Upphämtningen avbröts. Förfrågan är nu tillgänglig för andra hjälpare igen.'
      : 'Pickup cancelled. The request is available to other helpers again.';
  String get couldNotCompletePickup => _isSwedish
      ? 'Det gick inte att slutföra upphämtningen.'
      : 'Could not complete this pickup.';
  String get markedAsPickedUp =>
      _isSwedish ? 'Markerad som upphämtad!' : 'Marked as Picked Up!';
  String get markComplete =>
      _isSwedish ? 'Markera som klar' : 'Mark Complete';
  String get pickupCompletedTitle =>
      _isSwedish ? 'Upphämtning slutförd!' : 'Pickup completed!';
  String get pickupCompletedMessage => _isSwedish
      ? 'Snyggt jobbat. Den här upphämtningen är nu markerad som slutförd.'
      : 'Nice work. This pickup is now marked as completed.';
  String dayCount(int count) => _isSwedish
      ? '$count dag${count == 1 ? '' : 'ar'}'
      : '$count day${count == 1 ? '' : 's'}';
  String hourCount(int count) => _isSwedish
      ? '$count tim${count == 1 ? '' : ''}'
      : '$count hr${count == 1 ? '' : 's'}';
  String minuteCount(int count) => _isSwedish
      ? '$count min'
      : '$count min${count == 1 ? '' : 's'}';
  String get moments => _isSwedish ? 'ögonblick' : 'moments';
  String overdueLabel(String value) =>
      _isSwedish ? 'FÖRSENAD: $value' : 'OVERDUE: $value';
  String leftLabel(String value) =>
      _isSwedish ? '$value KVAR' : '$value LEFT';

  String get newPickupRequest =>
      _isSwedish ? 'Ny upphämtningsförfrågan' : 'New Pickup Request';
  String get addPhoto => _isSwedish ? 'Lägg till bild' : 'Add a photo';
  String get tapToChooseImage =>
      _isSwedish ? 'Tryck för att välja en bild' : 'Tap to choose an image';
  String get removePhoto => _isSwedish ? 'Ta bort bild' : 'Remove photo';
  String get choosePhoto =>
      _isSwedish ? 'Välj bild' : 'Choose Photo';
  String get changePhoto =>
      _isSwedish ? 'Byt bild' : 'Change Photo';
  String get whatAreYouGettingRidOf => _isSwedish
      ? 'Vad vill du bli av med?'
      : 'What are you getting rid of?';
  String get requestTitleHint =>
      _isSwedish ? 't.ex. Gammal soffa, trädgårdsavfall' : 'e.g. Old Sofa, Garden Waste';
  String get pleaseEnterTitle =>
      _isSwedish ? 'Ange en titel' : 'Please enter a title';
  String get description => _isSwedish ? 'Beskrivning' : 'Description';
  String get descriptionHint => _isSwedish
      ? 'Några detaljer? (t.ex. tungt, tredje våningen, nedmonterad)'
      : 'Any details? (e.g. heavy, 3rd floor, dismantled)';
  String get location => _isSwedish ? 'Plats' : 'Location';
  String get enterPickupAddress =>
      _isSwedish ? 'Ange upphämtningsadress' : 'Enter pickup address';
  String get pleaseEnterLocation =>
      _isSwedish ? 'Ange plats' : 'Please enter location';
  String get when => _isSwedish ? 'När?' : 'When?';
  String get from => _isSwedish ? 'Från' : 'From';
  String get to => _isSwedish ? 'Till' : 'To';
  String get yourPriceReward =>
      _isSwedish ? 'Ditt pris (ersättning)' : 'Your Price (Reward)';
  String get pleaseSetPrice =>
      _isSwedish ? 'Ange ett pris' : 'Please set a price';
  String get invalidNumber =>
      _isSwedish ? 'Ogiltigt nummer' : 'Invalid number';
  String get requestCreated =>
      _isSwedish ? 'Förfrågan skapad!' : 'Request Created!';
  String get postRequest =>
      _isSwedish ? 'Publicera förfrågan' : 'Post Request';
  String get couldNotPickPhoto =>
      _isSwedish ? 'Det gick inte att välja bilden.' : 'Could not pick the photo.';

  String get profileTitle => _isSwedish ? 'Profil' : 'Profile';
  String get helperStats => _isSwedish ? 'Hjälparstatistik' : 'Helper stats';
  String get completedJobs => _isSwedish ? 'Slutförda jobb' : 'Completed jobs';
  String get cancelledPickups =>
      _isSwedish ? 'Avbrutna upphämtningar' : 'Cancelled pickups';
  String get reliabilityContext =>
      _isSwedish ? 'Pålitlighetsöversikt' : 'Reliability context';
  String reliabilitySummary(int completed, int cancelled) => _isSwedish
      ? '$completed slutförda · $cancelled avbrutna'
      : '$completed completed · $cancelled cancelled';
  String get account => _isSwedish ? 'Konto' : 'Account';
  String get settings => _isSwedish ? 'Inställningar' : 'Settings';
  String get manageAppPreferences =>
      _isSwedish ? 'Hantera appinställningar' : 'Manage app preferences';
  String get notifications =>
      _isSwedish ? 'Notiser' : 'Notifications';
  String get stayUpdatedOnActivity => _isSwedish
      ? 'Håll dig uppdaterad om aktivitet'
      : 'Stay updated on activity';
  String get impactStats => _isSwedish ? 'Påverkansstatistik' : 'Impact stats';
  String get trackRecyclingContribution => _isSwedish
      ? 'Följ ditt återvinningsbidrag'
      : 'Track your recycling contribution';
  String get helpSupport =>
      _isSwedish ? 'Hjälp och support' : 'Help & support';
  String get getHelpWhenYouNeedIt => _isSwedish
      ? 'Få hjälp när du behöver det'
      : 'Get help when you need it';
  String get language => _isSwedish ? 'Språk' : 'Language';
  String get chooseLanguage =>
      _isSwedish ? 'Välj språk' : 'Choose language';
  String get appLanguageDescription => _isSwedish
      ? 'Välj språket som används i appen'
      : 'Choose the language used in the app';
  String get logOut => _isSwedish ? 'Logga ut' : 'Log out';
  String get returnToSignInScreen => _isSwedish
      ? 'Gå tillbaka till inloggningsskärmen'
      : 'Return to the sign in screen';
  String get excellent => _isSwedish ? 'Utmärkt' : 'Excellent';
  String get strong => _isSwedish ? 'Stark' : 'Strong';
  String get fair => _isSwedish ? 'Godkänd' : 'Fair';
  String get needsImprovement =>
      _isSwedish ? 'Behöver förbättras' : 'Needs improvement';
  String get atRisk => _isSwedish ? 'Riskzon' : 'At risk';
  String get noHistoryYet =>
      _isSwedish ? 'Ingen historik ännu' : 'No history yet';
  String get recyclerRating =>
      _isSwedish ? 'Pålitlighetsbetyg' : 'Recycler rating';
  String basedOnCompletedAndCancelled(int completed, int cancelled) => _isSwedish
      ? 'Baserat på $completed slutförda jobb och $cancelled avbrutna upphämtningar.'
      : 'Based on $completed completed jobs and $cancelled cancelled pickups.';

  String get getDirections =>
      _isSwedish ? 'Visa vägbeskrivning' : 'Get directions';
  String get chooseMapForDirections => _isSwedish
      ? 'Välj karta för vägbeskrivning'
      : 'Choose map for directions';
  String get chooseMapApp =>
      _isSwedish ? 'Välj kartapp' : 'Choose map app';
  String get googleMaps => 'Google Maps';
  String get appleMaps => 'Apple Maps';
  String couldNotOpenMap(String label) => _isSwedish
      ? 'Det gick inte att öppna $label för den här adressen.'
      : 'Could not open $label for this address.';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['sv', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
