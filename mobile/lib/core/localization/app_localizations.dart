import 'package:flutter/foundation.dart';
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
  String get englishNative => 'English';
  String get swedishNative => 'Svenska';
  String get helperRole => _isSwedish ? 'Hjälpare' : 'Helper';
  String get recyclerRole => _isSwedish ? 'Återvinnare' : 'Recycler';
  String roleLabel(String role) => role == 'Helper' ? helperRole : recyclerRole;

  String get notificationFallbackTitle => _isSwedish ? 'Notis' : 'Notification';
  String get viewAction => _isSwedish ? 'VISA' : 'VIEW';

  String get appTagline => _isSwedish
      ? 'Boka upphämtningar, hantera förfrågningar och gör återvinningen enkel.'
      : 'Schedule pickups, manage requests, and keep recycling simple.';
  String get logIn => _isSwedish ? 'Logga in' : 'Log in';
  String get createAccount => _isSwedish ? 'Skapa konto' : 'Create account';
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
  String get email => _isSwedish ? 'E-post' : 'Email';
  String get pleaseEnterEmail =>
      _isSwedish ? 'Ange din e-postadress' : 'Please enter your email';
  String get pleaseEnterValidEmail =>
      _isSwedish ? 'Ange en giltig e-postadress' : 'Please enter a valid email';
  String get password => _isSwedish ? 'Lösenord' : 'Password';
  String get createStrongPassword =>
      _isSwedish ? 'Skapa ett starkt lösenord' : 'Create a strong password';
  String get enterPassword =>
      _isSwedish ? 'Ange ditt lösenord' : 'Enter your password';
  String get hidePassword => _isSwedish ? 'Dölj lösenord' : 'Hide password';
  String get showPassword => _isSwedish ? 'Visa lösenord' : 'Show password';
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
  String signUpFailed(String error) => _isSwedish
      ? 'Registreringen misslyckades: $error'
      : 'Sign up failed: $error';
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
    return _isSwedish ? 'Välkommen tillbaka, $name!' : 'Welcome Back, $name!';
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
  String get thankYouForRating =>
      _isSwedish ? 'Tack för ditt betyg!' : 'Thank you for your rating!';

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
  String get myActiveJobs => _isSwedish ? 'Mina aktiva jobb' : 'My Active Jobs';
  String get noActiveJobs => _isSwedish ? 'Inga aktiva jobb' : 'No Active Jobs';
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
  String get markComplete => _isSwedish ? 'Markera som klar' : 'Mark Complete';
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
  String minuteCount(int count) =>
      _isSwedish ? '$count min' : '$count min${count == 1 ? '' : 's'}';
  String get moments => _isSwedish ? 'ögonblick' : 'moments';
  String overdueLabel(String value) =>
      _isSwedish ? 'FÖRSENAD: $value' : 'OVERDUE: $value';
  String leftLabel(String value) => _isSwedish ? '$value KVAR' : '$value LEFT';

  String get newPickupRequest =>
      _isSwedish ? 'Ny upphämtningsförfrågan' : 'New Pickup Request';
  String get addPhoto => _isSwedish ? 'Lägg till bild' : 'Add a photo';
  String get tapToChooseImage =>
      _isSwedish ? 'Tryck för att välja en bild' : 'Tap to choose an image';
  String get removePhoto => _isSwedish ? 'Ta bort bild' : 'Remove photo';
  String get choosePhoto => _isSwedish ? 'Välj bild' : 'Choose Photo';
  String get changePhoto => _isSwedish ? 'Byt bild' : 'Change Photo';
  String get whatAreYouGettingRidOf =>
      _isSwedish ? 'Vad vill du bli av med?' : 'What are you getting rid of?';
  String get requestTitleHint => _isSwedish
      ? 't.ex. Gammal soffa, trädgårdsavfall'
      : 'e.g. Old Sofa, Garden Waste';
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
  String get invalidNumber => _isSwedish ? 'Ogiltigt nummer' : 'Invalid number';
  String get requestCreated =>
      _isSwedish ? 'Förfrågan skapad!' : 'Request Created!';
  String get postRequest => _isSwedish ? 'Publicera förfrågan' : 'Post Request';
  String get verifiedPantAmount =>
      _isSwedish ? 'Verifierad pantmängd (SEK)' : 'Verified Pant Amount (SEK)';
  String get recyclerShare =>
      _isSwedish ? '💚 Återvinnarens andel:' : '💚 Recycler Share:';
  String get helperEarnings =>
      _isSwedish ? '🚴 Hjälparens ersättning:' : '🚴 Helper Earnings:';
  String get camera => _isSwedish ? 'Kamera' : 'Camera';
  String get gallery => _isSwedish ? 'Galleri' : 'Gallery';
  String get typeMessage =>
      _isSwedish ? 'Skriv ett meddelande...' : 'Type a message...';
  String get noMessagesYet =>
      _isSwedish ? 'Inga meddelanden ännu' : 'No messages yet';
  String get openMaps => _isSwedish ? 'Öppna kartor' : 'Open Maps';
  String get atTheDoor => _isSwedish ? 'Jag är vid dörren' : "I'm at Door";
  String get chatWithHelper => _isSwedish ? 'Chatta med hjälparen' : 'Chat with Helper';
  String get pausePickupTitle => _isSwedish ? 'Pausa upphämtningen?' : 'Pause the pick up?';
  String get pausePickupContent => _isSwedish ? 'Är du säker på att du vill pausa eller avbryta den här förfrågan? Den kommer att tas bort från den aktiva marknaden.' : 'Are you sure you want to pause or cancel this request? It will be removed from the active market.';
  String get pausePickupNo => _isSwedish ? 'Nej, behåll den' : 'No, keep it';
  String get pausePickupYes => _isSwedish ? 'Ja, pausa den' : 'Yes, pause it';
  String get pausePickup => _isSwedish ? 'Pausa upphämtningen' : 'Pause the pick up';
  String get scanAndComplete =>
      _isSwedish ? 'Skanna och slutför' : 'Scan & Complete';
  String get imageNotAvailable =>
      _isSwedish ? 'Bilden är inte tillgänglig' : 'Image not available';
  String get split70_30 => _isSwedish ? '70% Jag / 30% Hjälpare' : '70% Me / 30% Helper';
  String get split50_50 => '50% / 50%';
  String get split100Helper => _isSwedish ? '100% Hjälpare' : '100% Helper';
  String get simulateHelperGps => _isSwedish ? 'Simulera GPS-rörelse (Testa ETA)' : 'Simulate Helper GPS Movement (Test ETA)';
  String get useDemoReceipt => _isSwedish ? 'Använd svenskt demokvitto (Testa OCR)' : 'Use Demo Swedish Receipt (Test OCR)';
  String get milestoneOnWay => _isSwedish ? 'På väg' : 'On way';
  String get milestoneNear => _isSwedish ? 'Nära (<1km)' : 'Near (<1km)';
  String get milestoneArrived => _isSwedish ? 'Framme' : 'Arrived';
  String get impactContainers => _isSwedish ? 'Förpackningar' : 'Containers';
  String get impactCansBottles => _isSwedish ? 'Burkar & flaskor' : 'Cans & bottles';
  String get impactCo2Saved => _isSwedish ? 'Sparad CO₂' : 'CO₂ Saved';
  String get impactEmissionsAvoided => _isSwedish ? 'Undvikna utsläpp' : 'Emissions avoided';
  String get impactTreesPlanted => _isSwedish ? 'Planterade träd' : 'Trees Planted';
  String get impactEquivalentAbsorption => _isSwedish ? 'Motsvarande absorption' : 'Equivalent absorption';
  String get impactPickups => _isSwedish ? 'Upphämtningar' : 'Pickups';
  String get impactCompletedCycles => _isSwedish ? 'Slutförda cykler' : 'Completed cycles';
  String get editDetails => _isSwedish ? 'Redigera uppgifter' : 'Edit details';
  String get routinePickup => _isSwedish ? 'Vanlig upphämtning' : 'Routine pickup';
  String get choosePickupAddress => _isSwedish ? 'Välj en upphämtningsadress' : 'Choose a pickup address';
  String get open => _isSwedish ? 'Öppna' : 'Open';

  String get scanPantReceipt => _isSwedish ? 'Skanna pantkvitto' : 'Scan Pant Receipt';
  String get contactlessDoorPickup => _isSwedish ? 'Kontaktlös upphämtning' : 'Contactless Door Pickup';
  String instructionsStr(String inst) => _isSwedish ? 'Instruktioner: $inst' : 'Instructions: $inst';
  String get dropoffPhotoCaptured => _isSwedish ? 'Fotobevis taget ✓' : 'Drop-off Photo Captured ✓';
  String get readingReceiptOcr => _isSwedish ? 'Läser kvittotext med OCR...' : 'Reading receipt text with OCR...';
  String get verifiedStore => _isSwedish ? 'Verifierad butik:' : 'Verified Store:';
  String get recycledUnits => _isSwedish ? 'Återvunna enheter:' : 'Recycled Units:';
  String itemsCount(int count) => _isSwedish ? '$count st' : '$count items';
  String get detectedTotal => _isSwedish ? 'Upptäckt summa:' : 'Detected Total:';
  String sekAmount(String amount) => '$amount SEK';
  String automatedPantSplit(int r, int h) => _isSwedish ? 'Automatisk fördelning ($r% / $h%)' : 'Automated Pant Split ($r% / $h%)';
  String get confirmReceiptAndComplete => _isSwedish ? 'Bekräfta kvitto & slutför' : 'Confirm Receipt & Complete Pickup';
  String get pickupPinLabel => _isSwedish ? 'Hämta' : 'Pickup';
  String get helperPinLabel => _isSwedish ? 'Hjälpare' : 'Helper';
  String etaLabel(int min, double km) => _isSwedish ? 'ETA: $min min ($km km)' : 'ETA: $min min ($km km)';
  String get localTestingDemo => _isSwedish ? 'Lokal testning / 1-klicksdemo' : 'Local Testing / 1-Click Demo';
  String get bypassCognitoInfo => _isSwedish ? 'Kringgå Cognito och logga in med förinlagd data:' : 'Bypass Cognito and enter with pre-seeded data:';

  String get dropoffPhotoProof =>
      _isSwedish ? 'Fotobevis på avlämning' : 'Drop-off Photo Proof';
  String get close => _isSwedish ? 'Stäng' : 'Close';
  String get bookAgain => _isSwedish ? 'Boka igen' : 'Book again';
  String get impact => _isSwedish ? 'Påverkan' : 'Impact';
  String get pantHistoryAndImpact => _isSwedish
      ? 'Pantistorik och miljöpåverkan'
      : 'Pant History & Eco Impact';
  String get confirmQuickRequest =>
      _isSwedish ? 'Bekräfta snabbförfrågan' : 'Confirm quick request';
  String get marketLimitReached =>
      _isSwedish ? 'Marknadsgränsen är nådd' : 'Market limit reached';
  String get startQuickRequest =>
      _isSwedish ? 'Starta snabbförfrågan' : 'Start quick request';
  String get couldNotPickPhoto => _isSwedish
      ? 'Det gick inte att välja bilden.'
      : 'Could not pick the photo.';

  String get feedback => _isSwedish ? 'Feedback' : 'Feedback';
  String get sendFeedback => _isSwedish ? 'Skicka feedback' : 'Send feedback';
  String get category => _isSwedish ? 'Kategori' : 'Category';
  String get yourFeedback => _isSwedish ? 'Din feedback' : 'Your feedback';
  String get openToBeingContacted => _isSwedish
      ? 'Jag kan tänka mig att bli kontaktad'
      : 'I’m open to being contacted';
  String get send => _isSwedish ? 'Skicka' : 'Send';
  String get thanksForFeedback =>
      _isSwedish ? 'Tack för din feedback!' : 'Thanks for your feedback!';
  String get couldNotSendFeedback => _isSwedish
      ? 'Det gick inte att skicka feedback.'
      : 'Could not send feedback.';
  String get general => _isSwedish ? 'Allmänt' : 'General';
  String get bug => _isSwedish ? 'Bugg' : 'Bug';
  String get idea => _isSwedish ? 'Idé' : 'Idea';
  String get accountCategory => _isSwedish ? 'Konto' : 'Account';
  String get editName => _isSwedish ? 'Redigera namn' : 'Edit name';
  String get firstAndLastName =>
      _isSwedish ? 'För- och efternamn' : 'First and last name';
  String get save => _isSwedish ? 'Spara' : 'Save';
  String get nameUpdated =>
      _isSwedish ? 'Namnet uppdaterades.' : 'Name updated.';
  String get useCurrentLocation =>
      _isSwedish ? 'Använd aktuell plats' : 'Use current location';
  String get enable => _isSwedish ? 'Aktivera' : 'Enable';
  String get earningsAndImpact =>
      _isSwedish ? 'Intäkter och påverkan' : 'Earnings & Impact';
  String get earnings => _isSwedish ? 'Intäkter' : 'Earnings';
  String get savedAddresses =>
      _isSwedish ? 'Sparade adresser' : 'Saved addresses';
  String get recentAddresses =>
      _isSwedish ? 'Senaste adresser' : 'Recent addresses';
  String get leaveAtDoor => _isSwedish
      ? 'Lämna vid dörren (kontaktlös upphämtning)'
      : 'Leave at Door (Contactless Pickup)';
  String get doorAccessInstructions => _isSwedish
      ? 'Dörr- och åtkomstinstruktioner'
      : 'Door & Access Instructions';
  String get saveAddressForLater =>
      _isSwedish ? 'Spara adressen för senare' : 'Save this address for later';
  String get keepPickupLocationOneTapAway => _isSwedish
      ? 'Ha denna upphämtningsplats nära till hands.'
      : 'Keep this pickup location one tap away.';
  String get saveReusableTemplate =>
      _isSwedish ? 'Spara som återanvändbar mall' : 'Save as reusable template';
  String get reusableTemplateDescription => _isSwedish
      ? 'Skapa snabbare förfrågningar med denna mall.'
      : 'Create requests faster with this template.';
  String get operationsAndMarketOversight => _isSwedish
      ? 'Drift och marknadsöversikt'
      : 'Panta Operations & Market Oversight';
  String personalCaps(int recycler, int helper) => _isSwedish
      ? 'Personliga gränser: $recycler återvinnare / $helper hjälpare'
      : 'Personal Caps: $recycler Recycler / $helper Helper';
  String get refreshMarketData =>
      _isSwedish ? 'Uppdatera marknadsdata' : 'Refresh Market Data';
  String get switchToUserView =>
      _isSwedish ? 'Byt till användarvy' : 'Switch to User View';
  String get simulateMarketEvent =>
      _isSwedish ? 'Simulera marknadshändelse' : 'Simulate Market Event';
  String get simulating => _isSwedish ? 'Simulerar...' : 'Simulating...';
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
  String get notifications => _isSwedish ? 'Notiser' : 'Notifications';
  String get stayUpdatedOnActivity => _isSwedish
      ? 'Håll dig uppdaterad om aktivitet'
      : 'Stay updated on activity';
  String get impactStats => _isSwedish ? 'Påverkansstatistik' : 'Impact stats';
  String get trackRecyclingContribution => _isSwedish
      ? 'Följ ditt återvinningsbidrag'
      : 'Track your recycling contribution';
  String get helpSupport => _isSwedish ? 'Hjälp och support' : 'Help & support';
  String get getHelpWhenYouNeedIt =>
      _isSwedish ? 'Få hjälp när du behöver det' : 'Get help when you need it';
  String get requestTemplates => _isSwedish ? 'Förfrågningsmallar' : 'Request templates';
  String get aboutPanta => _isSwedish ? 'Om Panta' : 'About Panta';
  String get language => _isSwedish ? 'Språk' : 'Language';
  String get chooseLanguage => _isSwedish ? 'Välj språk' : 'Choose language';
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
  String get chooseMapApp => _isSwedish ? 'Välj kartapp' : 'Choose map app';
  String get googleMaps => 'Google Maps';
  String get appleMaps => 'Apple Maps';
  String couldNotOpenMap(String label) => _isSwedish
      ? 'Det gick inte att öppna $label för den här adressen.'
      : 'Could not open $label for this address.';

  String get bankIdLogin =>
      _isSwedish ? 'Logga in med BankID' : 'Log in with BankID';
  String get bankIdVerify =>
      _isSwedish ? 'Verifiera med BankID' : 'Verify with BankID';
  String get bankIdVerified =>
      _isSwedish ? 'BankID-verifierad' : 'BankID Verified';
  String get bankIdVerificationTitle => _isSwedish
      ? 'BankID Säker Identifiering'
      : 'BankID Secure Identification';
  String get bankIdWaiting =>
      _isSwedish ? 'Startar BankID...' : 'Starting BankID...';
  String get bankIdOpenApp => _isSwedish
      ? 'Öppna BankID-appen på din telefon'
      : 'Open the BankID app on your phone';
  String get bankIdSuccess =>
      _isSwedish ? 'Verifiering lyckades!' : 'Verification successful!';
  String get bankIdPersonalNumber =>
      _isSwedish ? 'Personnummer' : 'Personal Identity Number';
  String get bankIdPersonalNumberHint =>
      _isSwedish ? 'ÅÅÅÅMMDD-XXXX (valfritt)' : 'YYYYMMDD-XXXX (optional)';
  String get bankIdOpenOnThisDevice =>
      _isSwedish ? 'Öppna på denna enhet' : 'Open on this device';
  String get bankIdVerifiedBadge =>
      _isSwedish ? 'Verifierad med BankID' : 'Verified with BankID';
  String get reseedSampleRequests => _isSwedish ? 'Återskapa exempelförfrågningar' : 'Re-seed Sample Requests';
  String get bankIdTrustSubtitle => _isSwedish
      ? 'Öka tryggheten för återvinnare och hjälpare genom att verifiera din identitet.'
      : 'Increase trust with recyclers and helpers by verifying your identity.';
  String get bankIdAppNotFound => _isSwedish
      ? 'BankID-appen hittades inte på denna enhet.'
      : 'The BankID app was not found on this device.';
  String get bankIdCouldNotOpen => _isSwedish
      ? 'Kunde inte öppna BankID-appen.'
      : 'Could not open the BankID app.';
  String get bankIdTestEnv => _isSwedish ? 'TESTMILJÖ (v6.0 API)' : 'TEST ENV (v6.0 API)';
  String get activeNow => _isSwedish ? 'Aktiv nu' : 'Active now';
  String requestLimitReached(int active, int max) => _isSwedish ? 'Gränsen för aktiva förfrågningar har nåtts ($active/$max). Vänta på att en befintlig upphämtning slutförs.' : 'Active request limit reached ($active/$max). Please wait for an existing pickup to complete.';
  String get bookIn30Seconds => _isSwedish ? 'Boka på 30 sekunder' : 'Book in 30 seconds';
  String get bankIdSecureAuth => _isSwedish ? 'SÄKER IDENTIFIERING' : 'SECURE IDENTIFICATION';
  String get bankIdEnterCode => _isSwedish ? 'Skriv in din säkerhetskod i BankID...' : 'Enter your security code in BankID...';
  String get bankIdOpenOnDevice => _isSwedish ? 'Öppna BankID på denna enhet' : 'Open BankID on this device';
  String get bankIdSimulating => _isSwedish ? 'Simulerar...' : 'Simulating...';
  String get bankIdSimulateApproval => _isSwedish ? 'Simulera godkännande (Testmiljö)' : 'Simulate Approval (Test Env)';
  String get bankIdV6Hint => _isSwedish ? 'I BankID v6.0 kan du lämna personnumret tomt och scanna QR-koden direkt med appen.' : 'In BankID v6.0 you can leave the personal number empty and scan the QR code directly with the app.';

  // Helper Job Card Additions
  String get bankIdName => 'BankID';
  String get contactlessPickupLeaveAtDoor => _isSwedish ? 'Kontaktlös upphämtning (Lämna vid dörren)' : 'Contactless Pickup (Leave at Door)';
  String chatNew(int count) => _isSwedish ? 'Chatt ($count NYA)' : 'Chat ($count NEW)';
  String chatCount(int count) => _isSwedish ? 'Chatt ($count)' : 'Chat ($count)';
  String get chat => _isSwedish ? 'Chatt' : 'Chat';
  String newMessagesCount(int count) => _isSwedish ? '$count NYA' : '$count NEW';
  String atDoorTime(String hour, String minute) => _isSwedish ? 'Vid dörren ($hour:$minute)' : 'At Door ($hour:$minute)';
  String get arrivalAlertSent => _isSwedish ? '🛎️ Ding-Dong! Ankomstnotis skickad till återvinnaren.' : '🛎️ Ding-Dong! Arrival alert sent to recycler.';
  String completedPantAndPayout(String amount, String payout) => _isSwedish ? 'Klart! Pant: $amount SEK. Din utbetalning: $payout SEK' : 'Completed! Pant: $amount SEK. Your payout: $payout SEK';

  // Create Request Page Additions
  String activeMarketQuotaUsed(int used, int max) => _isSwedish ? 'Aktiv marknadskvot: $used av $max använda' : 'Active Market Quota: $used of $max used';
  String activeMarketLimitReachedStatus(int used, int max) => _isSwedish ? 'Gräns för aktiv marknad nådd ($used/$max)' : 'Active Market Limit Reached ($used/$max)';
  String requestSlotsRemaining(int remaining) => _isSwedish ? 'Du har $remaining förfrågningsplatser kvar på din marknad.' : 'You have $remaining request slots remaining in your market.';
  String get waitBeforeCreatingNewRequest => _isSwedish ? 'Vänligen vänta tills en befintlig upphämtning är klar innan du skapar en ny.' : 'Please wait for an existing pickup to complete before creating a new one.';
  String get bookingFromHistoryNotice => _isSwedish ? 'Bokar igen från din förfrågningshistorik. Uppdatera eventuella detaljer innan publicering.' : 'Booking again from your request history. Update any details before posting.';
  String get useSavedTemplate => _isSwedish ? 'Använd en sparad mall' : 'Use a saved template';
  String get suggestion2BagsPetBottles => _isSwedish ? '2 påsar PET-flaskor' : '2 bags of PET bottles';
  String get suggestion1BagAluminumCans => _isSwedish ? '1 påse aluminiumburkar' : '1 bag of aluminum cans';
  String get suggestionMixedRecyclingBags => _isSwedish ? 'Blandade pantpåsar' : 'Mixed recycling bags';
  String get pantRefundSplitTitle => _isSwedish ? 'Fördelning av pantersättning' : 'Pant Refund Split';
  String get pantRefundSplitSubtitle => _isSwedish ? 'Hur vill du fördela det inskannade pantkvittot?' : 'How would you like to split the scanned recycling receipt?';
  String get leaveAtDoorDescription => _isSwedish ? 'Hjälparen hämtar påsarna utanför din dörr och tar en bild som bekräftelse.' : 'Helper will pick up bags outside your door and take a photo confirmation.';
  String get doorInstructionsExample => _isSwedish ? 't.ex. Portkod 1234, 3:e våningen, påsen står utanför dörr 12B' : 'e.g. Door code 1234, 3rd floor, bag is outside door 12B';
  String get reuseTemplateDescription => _isSwedish ? 'Återanvänd titel, anteckningar och belöning nästa gång.' : 'Reuse the title, notes, and reward next time.';

  // BankID & Auth
  String get bankIdScanQr => _isSwedish ? 'Scanna QR-koden i BankID-appen' : 'Scan the QR code in the BankID app';
  String get emailExampleHint => _isSwedish ? 'namn@exempel.se' : 'name@example.com';
  String get adminDashboardSwedenOversight => _isSwedish ? 'Adminpanel (Sverige Marknadsöversikt)' : 'Admin Dashboard (Sweden Market Oversight)';
  String get annaRecyclerDemo => _isSwedish ? 'Anna (Återvinnare)' : 'Anna (Recycler)';
  String get erikHelperDemo => _isSwedish ? 'Erik (Hjälpare)' : 'Erik (Helper)';

  // Chat & Navigation
  String get newBadge => _isSwedish ? 'NY' : 'NEW';
  String get dismiss => _isSwedish ? 'Avfärda' : 'Dismiss';

  // Receipt Scanner & Verification
  String get takeDropoffPhotoProof => _isSwedish ? 'Ta bildbevis för avlämning' : 'Take Drop-off Photo Proof';
  String get pantStation => _isSwedish ? 'Pantstation' : 'Recycling Station';

  // Streak & Dashboard
  String streakWeeksShort(int weeks) => _isSwedish ? '${weeks}v' : '${weeks}w';

  // User Request Card
  String verifiedPantValue(String amount) => _isSwedish ? 'Verifierad pant: $amount SEK' : 'Verified Pant: $amount SEK';
  String yourPayoutAmount(String amount) => _isSwedish ? 'Din utbetalning: $amount SEK' : 'Your Payout: $amount SEK';
  String get helperConfirmedPickupAtDoor => _isSwedish ? 'Hjälparen bekräftade upphämtning vid dörren:' : 'Helper confirmed pickup at door:';
  String get photoVerifiedByHelper => _isSwedish ? 'Foto verifierat av hjälparen' : 'Photo Verified by Helper';
  String get viewPhotoProof => _isSwedish ? 'Visa bildbevis ✓' : 'View Photo Proof ✓';
  String get helperOutsideYourDoor => _isSwedish ? 'Hjälparen är utanför din dörr!' : 'Helper is outside your door!';
  String get bagsCanBePickedUpOutsideDoor => _isSwedish ? 'Påsarna kan hämtas direkt utanför din dörr.' : 'Bags can be picked up directly outside your door.';
  String get pleaseOpenDoorToHandOverBags => _isSwedish ? 'Vänligen öppna dörren eller möt hjälparen för att lämna över pantpåsarna.' : 'Please open your door or meet the helper to hand over pant bags.';
  String chatWithHelperNew(int count) => _isSwedish ? 'Chatta med hjälpare ($count NYA)' : 'Chat with Helper ($count NEW)';
  String chatWithHelperCount(int count) => _isSwedish ? 'Chatta med hjälpare ($count)' : 'Chat with Helper ($count)';
  String unreadCountBadge(int count) => '$count $newBadge';

  // Profile Screen
  String get pickupShortcuts => _isSwedish ? 'Snabbval för upphämtning' : 'Pickup shortcuts';
  String get demoTestingTools => _isSwedish ? 'Demo- och lokala testverktyg' : 'Demo & Local Testing Tools';
  String get switchToRecyclerDemo => _isSwedish ? 'Växla till återvinnare (Anna)' : 'Switch to Recycler (Anna)';
  String get switchToHelperDemo => _isSwedish ? 'Växla till hjälpare (Erik)' : 'Switch to Helper (Erik)';
  String get switchRoleSubtitle => _isSwedish ? 'Byt roll med 1 klick för att testa marknadsplatsen' : 'Switch role in 1 click to test marketplace interaction';
  String get switchedToRecyclerDemo => _isSwedish ? 'Bytte till återvinnare (Anna)' : 'Switched to Recycler (Anna)';
  String get switchedToHelperDemo => _isSwedish ? 'Bytte till hjälpare (Erik)' : 'Switched to Helper (Erik)';
  String get reseedSampleSubtitle => _isSwedish ? 'Fyll på väntande, accepterade och slutförda förfrågningar med chatt och foton' : 'Populate pending, accepted, and completed requests with chat & photos';
  String get sampleRequestsReseeded => _isSwedish ? 'Exempelförfrågningar återställda!' : 'Sample requests re-seeded!';
  String get failedToSeedRequests => _isSwedish ? 'Kunde inte skapa exempelförfrågningar' : 'Failed to seed requests';

  // Analytics & Impact Dashboard
  String get myEarningsAndImpact => _isSwedish ? 'Mina intäkter & miljöpåverkan' : 'My Earnings & Impact';
  String get pantHistoryAndEcoImpact => _isSwedish ? 'Panthistorik & miljöpåverkan' : 'Pant History & Eco Impact';
  String get totalHelperEarnings => _isSwedish ? 'Hjälparens totala intäkter' : 'Total Helper Earnings';
  String get totalPantRefund => _isSwedish ? 'Total pantersättning' : 'Total Pant Refund';
  String amountSek(String amount) => '$amount SEK';
  String plusAmountSek(String amount) => '+$amount SEK';
  String co2SavedKg(String amount) => '-$amount kg CO₂';
  String helperImpactDescription(int containers, int pickups) => _isSwedish ? 'Du hjälpte till att återvinna $containers förpackningar över $pickups slutförda upphämtningar!' : 'You helped recycle $containers containers across $pickups completed pickups!';
  String recyclerImpactDescription(int containers) => _isSwedish ? 'Du återvann $containers förpackningar och minskade koldioxidutsläppen med Panta Go!' : 'You recycled $containers containers and offset carbon emissions with Panta Go!';
  String weekStreakTitle(int weeks) => _isSwedish ? '$weeks veckors återvinningssvit!' : '$weeks Week Recycling Streak!';
  String get startStreakTitle => _isSwedish ? 'Starta din återvinningssvit!' : 'Start your Recycling Streak!';
  String get keepRecyclingWeeklySubtitle => _isSwedish ? 'Fortsätt panta varje vecka för att hålla lågan vid liv och tjäna utmärkelser.' : 'Keep recycling weekly to maintain your flame & earn streak badges.';
  String get igniteFlameSubtitle => _isSwedish ? 'Slutför en upphämtning denna vecka för att tända din återvinningslåga!' : 'Complete a pickup this week to ignite your recycling flame!';
  String get ecoBadgesAndMilestones => _isSwedish ? 'Miljömärken & milstolpar' : 'Eco Badges & Milestones';
  String badgesUnlockedCount(int unlocked, int total) => _isSwedish ? '$unlocked / $total upplåsta' : '$unlocked / $total Unlocked';
  String get pickupActivityTitle => _isSwedish ? 'Upphämtningsaktivitet & bidrag' : 'Pickup Activity & Contribution';
  String get noCompletedPickupsYet => _isSwedish ? 'Inga slutförda upphämtningar än' : 'No completed pickups yet';
  String get completeFirstPickupSubtitle => _isSwedish ? 'Slutför din första pantupphämtning för att bygga dina mätvärden!' : 'Complete your first recycling pickup to build your impact metrics!';
  String verifiedDateAndAmount(String dateStr, String amount) => _isSwedish ? '$dateStr • Verifierat: $amount SEK' : '$dateStr • Verified: $amount SEK';

  // Admin Dashboard
  String get antiSpamProtectionActive => _isSwedish ? 'Spam- och bunkringsskydd aktivt' : 'Anti-Spam & Anti-Hoarding Protection Active';
  String adminQuotaDescription(int recyclerCap, int helperCap) => _isSwedish ? 'Personlig marknadskvot för återvinnare: $recyclerCap aktiva förfrågningar | Personlig kvot för hjälpare: $helperCap aktiva uppdrag.' : 'Personal recycler market cap: $recyclerCap active requests | Personal helper cap: $helperCap active jobs.';
  String get statusActive => _isSwedish ? 'AKTIV' : 'ACTIVE';
  String get swedenMapVisualizationTitle => _isSwedish ? 'Visualisering av karta för Sverige och städer' : 'Sweden Country & City Map Visualization';
  String monitoredHubsCount(int count) => _isSwedish ? '$count övervakade hubbar' : '$count Monitored Hubs';
  String get swedenMapDescription => _isSwedish ? 'Interaktiv geografisk karta som representerar aktuell marknadsbelastning och tillgänglighet av hjälpare i Sverige. Tryck på en stad för att granska.' : 'Interactive geographic map representing live market load and helper availability across Sweden. Tap any city node to inspect.';
  String selectedNodeCity(String name, String status) => _isSwedish ? 'Vald nod: $name ($status)' : 'Selected Node: $name ($status)';
  String get cityBreakdownTitle => _isSwedish ? 'Stadsuppdelning & kapacitetstrender' : 'City Breakdown & Capacity Trends';
  String cityCapacityStats(int active, int pending, int helpers, int eta) => _isSwedish ? 'Aktiva: $active | Väntande: $pending | Hjälpare: $helpers | ETA: ~${eta}m' : 'Active: $active | Pending: $pending | Helpers: $helpers | ETA: ~${eta}m';
  String get userFeedbackTitle => _isSwedish ? 'Användarfeedback' : 'User Feedback';
  String feedbackSubmissionsCount(int count) => _isSwedish ? '$count inskickade' : '$count submissions';
  String get feedbackMarketDescription => _isSwedish ? 'Feedback inskickad av användare på din marknad.' : 'Feedback submitted by users in your market.';
  String get noFeedbackReceivedYet => _isSwedish ? 'Ingen feedback mottagen än.' : 'No feedback received yet.';
  String get unknownUser => _isSwedish ? 'Okänd användare' : 'Unknown user';
  String get liveSystemAuditLogs => _isSwedish ? 'Realtids- och granskningsloggar' : 'Live System & Audit Logs';
  String eventsCount(int count) => _isSwedish ? '$count händelser' : '$count events';
  String get auditLogDescription => _isSwedish ? 'Realtidslogg över dispatch-åtgärder, utbetalningar och kvotuppföljning.' : 'Real-time audit log of dispatch actions, payout events, and market quota enforcement.';
  String get noSystemLogsRecordedYet => _isSwedish ? 'Inga systemloggar har registrerats än.' : 'No system logs recorded yet.';
  String simulatedEventLogged(String action, String details) => _isSwedish ? 'Simulerad händelse loggad [$action]: $details' : 'Simulated Event Logged [$action]: $details';
  String get simulatedEventTriggeredLocal => _isSwedish ? 'Simulerad händelse utlöst (Lokal fallback)' : 'Simulated Event Triggered (Local fallback)';
  String simulationError(String error) => _isSwedish ? 'Simuleringsfel: $error' : 'Simulation error: $error';
  String get adminSimQuotaEnforced => _isSwedish ? 'Personlig kvot tillämpad: 20 max förfrågningar per återvinnare, 30 aktiva jobb per hjälpare' : 'Personal quota enforced: 20 max requests per Recycler, 30 active jobs per Helper';
  String get adminSimNationalSpamCheck => _isSwedish ? 'Nationell spam-kontroll: Alla konton inom 20/30-gränsen. Överträdelser: 0' : 'National spam check: All accounts within 20/30 limit. Violations: 0';
  String get adminSimDisbursedRevenue => _isSwedish ? 'Betalade ut 70/30 pantintäkter: 175.00 SEK till Anna Återvinnare, 75.00 SEK till Erik Hjälpare' : 'Disbursed 70/30 pant revenue: 175.00 SEK to Anna Recycler, 75.00 SEK to Erik Helper';
  String get adminSimPickupAccepted => _isSwedish ? 'Simulerad upphämtning accepterad i Stockholm Vasastan (ETA: 12 min)' : 'Simulated pickup accepted in Stockholm Vasastan (ETA: 12 min)';

  // Feedback & Profile
  String get feedbackSubtitle => _isSwedish
      ? 'Berätta för Panta-teamet vad vi kan förbättra'
      : 'Tell the Panta team what to improve';
  String get loadingVersion => _isSwedish ? 'Laddar version…' : 'Loading version…';
  String appVersionBuild(String version, String build) =>
      _isSwedish ? 'v$version (Bygge $build)' : 'v$version (Build $build)';
  String get enterValidNameLength => _isSwedish
      ? 'Ange ett namn mellan 1 och 100 tecken.'
      : 'Enter a name between 1 and 100 characters.';

  // Admin KPI Cards
  String get activePickups => _isSwedish ? 'Aktiva upphämtningar' : 'Active Pickups';
  String kpiActivePickupsSubtitle(int pending, int inTransit) => _isSwedish
      ? '$pending vänt / $inTransit under transport'
      : '$pending pend / $inTransit in transit';
  String get totalPantScanned => _isSwedish ? 'Totalt scannad pant' : 'Total Pant Scanned';
  String get kpiPantSplitSubtitle => _isSwedish ? '70% Användare / 30% Hjälpare' : '70% User / 30% Helper';
  String get recyclerLimit => _isSwedish ? 'Gräns för återvinnare' : 'Recycler Limit';
  String get recyclerLimitSubtitle => _isSwedish ? 'Personlig kvot mot spam' : 'Anti-spam individual quota';
  String get helperLimit => _isSwedish ? 'Gräns för hjälpare' : 'Helper Limit';
  String get helperLimitSubtitle => _isSwedish ? 'Kapacitetstak mot bunkring' : 'Anti-hoarding capacity cap';

  // Request & Locations
  String get recentPickup => _isSwedish ? 'Senaste upphämtning' : 'Recent pickup';
  String get pantPickup => _isSwedish ? 'Pantupphämtning' : 'Pant Pickup';

  // Eco Badges
  String badgeTitle(String id, {String? fallback}) {
    switch (id) {
      case 'first_step':
        return _isSwedish ? 'Första steget' : 'First Step';
      case 'centurion':
        return _isSwedish ? 'Hundring-återvinnare' : 'Centurion Recycler';
      case 'carbon_crusher':
        return _isSwedish ? 'Koldioxidkrossare' : 'Carbon Crusher';
      case 'streak_master':
        return _isSwedish ? 'Svitmästare' : 'Streak Master';
      case 'pant_legend':
        return _isSwedish ? 'Pantlegend' : 'Pant Legend';
      case 'eco_champion':
        return _isSwedish ? 'Eko-mästare' : 'Eco Champion';
      default:
        return fallback ?? id;
    }
  }

  String badgeDescription(String id, {String? fallback}) {
    switch (id) {
      case 'first_step':
        return _isSwedish
            ? 'Slutför din första pantupphämtning'
            : 'Complete your first pant pickup';
      case 'centurion':
        return _isSwedish
            ? 'Återvinn 100+ burkar & flaskor'
            : 'Recycle 100+ cans & bottles';
      case 'carbon_crusher':
        return _isSwedish
            ? 'Minska minst 10 kg CO₂'
            : 'Offset at least 10 kg of CO₂';
      case 'streak_master':
        return _isSwedish
            ? 'Behåll en återvinningssvit i 3 veckor'
            : 'Maintain a 3-week recycling streak';
      case 'pant_legend':
        return _isSwedish
            ? 'Slutför 10+ pantupphämtningar'
            : 'Complete 10+ recycling pickups';
      case 'eco_champion':
        return _isSwedish
            ? 'Tjäna/få tillbaka över 500 SEK i pant'
            : 'Earn/refund over 500 SEK in pant';
      default:
        return fallback ?? '';
    }
  }

  // Live Map Tracking ETA
  String get etaHelperArrived =>
      _isSwedish ? 'Hjälparen har anlänt!' : 'Helper has arrived!';
  String etaArrivingSoon(int minutes) =>
      _isSwedish ? 'Anländer snart (~$minutes min)' : 'Arriving soon (~$minutes min)';
  String etaOnTheWay(int minutes, double distanceKm) => _isSwedish
      ? 'På väg (~$minutes min, $distanceKm km)'
      : 'On the way (~$minutes min, $distanceKm km)';
  String get pickupInProgress =>
      _isSwedish ? 'Upphämtning pågår' : 'Pickup in progress';

  // Receipt Scanner
  String couldNotProcessReceiptImage(String error) => _isSwedish
      ? 'Kunde inte bearbeta kvitto-bild: $error'
      : 'Could not process receipt image: $error';
  String get pleaseEnterValidPantAmount => _isSwedish
      ? 'Vänligen ange ett giltigt pantbelopp i SEK.'
      : 'Please enter a valid SEK pant amount.';
  String get recyclingStation =>
      _isSwedish ? 'Pantstation' : 'Recycling Station';

  // BankID Dialog Errors
  String get bankIdInitFailed => _isSwedish
      ? 'Kunde inte initiera BankID. Kontrollera anslutningen.'
      : 'Could not initialize BankID. Please check your connection.';
  String bankIdGenericError(String error) =>
      _isSwedish ? 'Fel: $error' : 'Error: $error';
  String get bankIdStatusCheckFailed => _isSwedish
      ? 'Kunde inte verifiera BankID-status.'
      : 'Could not verify BankID status.';
  String get bankIdCancelled => _isSwedish
      ? 'BankID-identifieringen avbröts.'
      : 'BankID authentication was canceled.';
  String get bankIdFailedOrExpired => _isSwedish
      ? 'BankID-identifieringen misslyckades eller löpte ut.'
      : 'BankID authentication failed or expired.';
  String get bankIdLinkFailed => _isSwedish
      ? 'Kunde inte koppla BankID till nuvarande konto.'
      : 'Could not link BankID to current account.';
  String get bankIdSimulationFailed => _isSwedish
      ? 'Kunde inte simulera godkännande.'
      : 'Could not simulate approval.';

  // Chat & Common
  String get me => _isSwedish ? 'Jag' : 'Me';

  // GDPR Cookie Consent
  String get cookieBannerTitle =>
      _isSwedish ? 'Vi värnar om din integritet' : 'We value your privacy';
  String get cookieBannerDescription => _isSwedish
      ? 'Panta använder nödvändiga kakor och lokal lagring för säker inloggning, sessionshantering och kärnfunktioner. Med ditt medgivande använder vi även funktionella kakor, analyskakor och marknadsföringskakor i enlighet med lagen om elektronisk kommunikation (LEK) och GDPR.'
      : 'Panta uses strictly necessary cookies and local storage for secure sign-in, session management, and core features. With your consent, we also use functional, analytics, and marketing cookies in compliance with Swedish LEK and GDPR.';
  String get cookieAcceptAll =>
      _isSwedish ? 'Godkänn alla' : 'Accept all';
  String get cookieNecessaryOnly =>
      _isSwedish ? 'Endast nödvändiga' : 'Necessary only';
  String get cookieCustomize =>
      _isSwedish ? 'Anpassa kakor' : 'Customize cookies';
  String get cookiePreferencesTitle =>
      _isSwedish ? 'Cookie-inställningar' : 'Cookie Preferences';
  String get cookiePreferencesSubtitle => _isSwedish
      ? 'Hantera samtycke för kakor och lokal lagring'
      : 'Manage cookie and local storage consent';
  String get cookiePreferencesDescription => _isSwedish
      ? 'Välj vilka typer av kakor och lokal lagring du tillåter. Nödvändiga kakor krävs för att tjänsten ska fungera och kan inte stängas av.'
      : 'Choose which types of cookies and local storage you allow. Necessary cookies are required for the service to function and cannot be turned off.';
  String get cookieCategoryNecessary =>
      _isSwedish ? 'Nödvändiga kakor' : 'Necessary Cookies';
  String get cookieCategoryNecessaryDesc => _isSwedish
      ? 'Krävs för grundläggande funktionalitet som inloggning, BankID-verifiering och säkerhet. Alltid aktiva.'
      : 'Required for core functionality such as sign-in, BankID verification, and security. Always active.';
  String get cookieCategoryFunctional =>
      _isSwedish ? 'Funktionella kakor' : 'Functional Cookies';
  String get cookieCategoryFunctionalDesc => _isSwedish
      ? 'Sparar dina personliga gränssnittsval som språk, visningsinställningar och filter.'
      : 'Saves your personal interface preferences like language, display settings, and filters.';
  String get cookieCategoryAnalytics =>
      _isSwedish ? 'Analys & Prestanda' : 'Analytics & Performance';
  String get cookieCategoryAnalyticsDesc => _isSwedish
      ? 'Hjälper oss förstå hur appen används och upptäcka fel så att vi kan förbättra återvinningsupplevelsen.'
      : 'Helps us understand how the app is used and detect bugs to improve the recycling experience.';
  String get cookieCategoryMarketing =>
      _isSwedish ? 'Marknadsföring' : 'Marketing';
  String get cookieCategoryMarketingDesc => _isSwedish
      ? 'Används för att utvärdera kampanjer, värvningslänkar och återvinningsincitament.'
      : 'Used to measure promotional campaigns, referral links, and recycling incentives.';
  String get cookieAlwaysActive =>
      _isSwedish ? 'Alltid aktiv' : 'Always active';
  String get cookieSavePreferences =>
      _isSwedish ? 'Spara inställningar' : 'Save preferences';
  String get cookieConsentSaved => _isSwedish
      ? 'Dina cookie-inställningar har sparats'
      : 'Your cookie preferences have been saved';

  // User Suspension & Case Management
  String get userSuspensionsTitle => _isSwedish
      ? 'Användaravstängningar & Juridiska ärenden'
      : 'User Suspensions & Legal Cases';
  String get suspendUserAction =>
      _isSwedish ? 'Stäng av användare' : 'Suspend user';
  String get unblockUserAction =>
      _isSwedish ? 'Häv avstängning' : 'Lift suspension';
  String get caseReferenceIdLabel => _isSwedish
      ? 'Ärendereferens (t.ex. CASE-2026-001)'
      : 'Case reference ID (e.g. CASE-2026-001)';
  String get suspensionReasonLabel =>
      _isSwedish ? 'Skäl för avstängning' : 'Reason for suspension';
  String get optionalExpiryDateLabel => _isSwedish
      ? 'Valfritt utgångsdatum (YYYY-MM-DD)'
      : 'Optional expiry date (YYYY-MM-DD)';
  String get userIdOrEmailLabel =>
      _isSwedish ? 'Användar-ID eller E-post' : 'User ID or Email';
  String activeSuspensionsCount(int count) => _isSwedish
      ? 'Aktiva avstängningar: $count'
      : 'Active suspensions: $count';
  String get noActiveSuspensions => _isSwedish
      ? 'Inga aktiva användaravstängningar'
      : 'No active user suspensions';
  String get userSuspendedSuccess => _isSwedish
      ? 'Användaren har stängts av och ärendet har loggats'
      : 'User has been suspended and case logged';
  String get userUnblockedSuccess =>
      _isSwedish ? 'Avstängningen har hävts' : 'Suspension has been lifted';
  String get accountRestrictedTitle =>
      _isSwedish ? 'Kontot är begränsat' : 'Account Restricted';
  String accountRestrictedMessage(String ref) => _isSwedish
      ? 'Ditt konto har begränsats för juridisk eller regelefterlevnadsgranskning. Kontakta Panta Support och ange referens: $ref'
      : 'Your account is restricted for compliance or legal review. Please contact Panta Support quoting reference: $ref';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['sv', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>(AppLocalizations(locale));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => true;
}

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
