import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('en'),
    Locale('tr')
  ];

  /// No description provided for @appTitle.
  ///
  /// In tr, this message translates to:
  /// **'İstanbul Kafe'**
  String get appTitle;

  /// No description provided for @commonBack.
  ///
  /// In tr, this message translates to:
  /// **'Geri'**
  String get commonBack;

  /// No description provided for @commonSave.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get commonSave;

  /// No description provided for @commonCancel.
  ///
  /// In tr, this message translates to:
  /// **'İptal'**
  String get commonCancel;

  /// No description provided for @commonRetry.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar dene'**
  String get commonRetry;

  /// No description provided for @commonClose.
  ///
  /// In tr, this message translates to:
  /// **'Kapat'**
  String get commonClose;

  /// No description provided for @commonClear.
  ///
  /// In tr, this message translates to:
  /// **'Temizle'**
  String get commonClear;

  /// No description provided for @commonEdit.
  ///
  /// In tr, this message translates to:
  /// **'Düzenle'**
  String get commonEdit;

  /// Daha fazla icerik yuklemek icin genel eylem etiketi.
  ///
  /// In tr, this message translates to:
  /// **'Daha fazla yükle'**
  String get commonLoadMore;

  /// No description provided for @commonReset.
  ///
  /// In tr, this message translates to:
  /// **'Sıfırla'**
  String get commonReset;

  /// No description provided for @commonApply.
  ///
  /// In tr, this message translates to:
  /// **'Uygula'**
  String get commonApply;

  /// No description provided for @commonLoading.
  ///
  /// In tr, this message translates to:
  /// **'Yükleniyor...'**
  String get commonLoading;

  /// No description provided for @commonRefreshing.
  ///
  /// In tr, this message translates to:
  /// **'Yenileniyor...'**
  String get commonRefreshing;

  /// No description provided for @commonOpen.
  ///
  /// In tr, this message translates to:
  /// **'Açık'**
  String get commonOpen;

  /// No description provided for @commonClosed.
  ///
  /// In tr, this message translates to:
  /// **'Kapalı'**
  String get commonClosed;

  /// No description provided for @commonUnknown.
  ///
  /// In tr, this message translates to:
  /// **'Belirtilmemiş'**
  String get commonUnknown;

  /// No description provided for @cafeNoRatingsYet.
  ///
  /// In tr, this message translates to:
  /// **'Henüz puan yok'**
  String get cafeNoRatingsYet;

  /// No description provided for @commonNoData.
  ///
  /// In tr, this message translates to:
  /// **'Belirtilmemiş'**
  String get commonNoData;

  /// No description provided for @commonCategory.
  ///
  /// In tr, this message translates to:
  /// **'Kategori'**
  String get commonCategory;

  /// No description provided for @cafeCategoryNormal.
  ///
  /// In tr, this message translates to:
  /// **'Standart kafe'**
  String get cafeCategoryNormal;

  /// No description provided for @cafeCategoryLounge.
  ///
  /// In tr, this message translates to:
  /// **'Kafe lounge'**
  String get cafeCategoryLounge;

  /// No description provided for @commonDetails.
  ///
  /// In tr, this message translates to:
  /// **'Detay'**
  String get commonDetails;

  /// No description provided for @commonSettings.
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar'**
  String get commonSettings;

  /// No description provided for @commonTheme.
  ///
  /// In tr, this message translates to:
  /// **'Tema'**
  String get commonTheme;

  /// No description provided for @commonAbout.
  ///
  /// In tr, this message translates to:
  /// **'Hakkında'**
  String get commonAbout;

  /// No description provided for @commonLight.
  ///
  /// In tr, this message translates to:
  /// **'Açık'**
  String get commonLight;

  /// No description provided for @commonDark.
  ///
  /// In tr, this message translates to:
  /// **'Koyu'**
  String get commonDark;

  /// No description provided for @commonSystem.
  ///
  /// In tr, this message translates to:
  /// **'Sistem'**
  String get commonSystem;

  /// No description provided for @commonLanguage.
  ///
  /// In tr, this message translates to:
  /// **'Dil'**
  String get commonLanguage;

  /// No description provided for @commonSystemLanguage.
  ///
  /// In tr, this message translates to:
  /// **'Sistem dili'**
  String get commonSystemLanguage;

  /// No description provided for @commonTurkish.
  ///
  /// In tr, this message translates to:
  /// **'Türkçe'**
  String get commonTurkish;

  /// No description provided for @commonEnglish.
  ///
  /// In tr, this message translates to:
  /// **'İngilizce'**
  String get commonEnglish;

  /// No description provided for @errorGenericTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bir sorun oluştu'**
  String get errorGenericTitle;

  /// Cihaz cevrimdisiyken ve uygulama onbellekteki verileri gosterirken acilan banner mesaji.
  ///
  /// In tr, this message translates to:
  /// **'Çevrimdışısın. Önbellekteki veriler gösteriliyor ve değişiklikler eşitleme için kuyruklanıyor.'**
  String get offlineBannerMessage;

  /// No description provided for @navHome.
  ///
  /// In tr, this message translates to:
  /// **'Ana Sayfa'**
  String get navHome;

  /// No description provided for @navExplore.
  ///
  /// In tr, this message translates to:
  /// **'Keşfet'**
  String get navExplore;

  /// No description provided for @navMap.
  ///
  /// In tr, this message translates to:
  /// **'Harita'**
  String get navMap;

  /// No description provided for @navFavorites.
  ///
  /// In tr, this message translates to:
  /// **'Favoriler'**
  String get navFavorites;

  /// No description provided for @navProfile.
  ///
  /// In tr, this message translates to:
  /// **'Profil'**
  String get navProfile;

  /// No description provided for @districtKadikoy.
  ///
  /// In tr, this message translates to:
  /// **'Kadıköy'**
  String get districtKadikoy;

  /// No description provided for @districtBesiktas.
  ///
  /// In tr, this message translates to:
  /// **'Beşiktaş'**
  String get districtBesiktas;

  /// No description provided for @districtUskudar.
  ///
  /// In tr, this message translates to:
  /// **'Üsküdar'**
  String get districtUskudar;

  /// No description provided for @districtSisli.
  ///
  /// In tr, this message translates to:
  /// **'Şişli'**
  String get districtSisli;

  /// No description provided for @districtFatih.
  ///
  /// In tr, this message translates to:
  /// **'Fatih'**
  String get districtFatih;

  /// No description provided for @districtBeyoglu.
  ///
  /// In tr, this message translates to:
  /// **'Beyoğlu'**
  String get districtBeyoglu;

  /// No description provided for @districtBakirkoy.
  ///
  /// In tr, this message translates to:
  /// **'Bakırköy'**
  String get districtBakirkoy;

  /// No description provided for @wifiWeak.
  ///
  /// In tr, this message translates to:
  /// **'Zayıf'**
  String get wifiWeak;

  /// No description provided for @wifiAverage.
  ///
  /// In tr, this message translates to:
  /// **'Orta'**
  String get wifiAverage;

  /// No description provided for @wifiStrong.
  ///
  /// In tr, this message translates to:
  /// **'Güçlü'**
  String get wifiStrong;

  /// No description provided for @outletLow.
  ///
  /// In tr, this message translates to:
  /// **'Az'**
  String get outletLow;

  /// No description provided for @outletMedium.
  ///
  /// In tr, this message translates to:
  /// **'Orta'**
  String get outletMedium;

  /// No description provided for @outletHigh.
  ///
  /// In tr, this message translates to:
  /// **'Çok'**
  String get outletHigh;

  /// No description provided for @quietnessBusy.
  ///
  /// In tr, this message translates to:
  /// **'Kalabalık'**
  String get quietnessBusy;

  /// No description provided for @quietnessBalanced.
  ///
  /// In tr, this message translates to:
  /// **'Dengeli'**
  String get quietnessBalanced;

  /// No description provided for @quietnessQuiet.
  ///
  /// In tr, this message translates to:
  /// **'Sessiz'**
  String get quietnessQuiet;

  /// No description provided for @smokingAllowed.
  ///
  /// In tr, this message translates to:
  /// **'Serbest'**
  String get smokingAllowed;

  /// No description provided for @smokingOutdoorOnly.
  ///
  /// In tr, this message translates to:
  /// **'Dış mekan'**
  String get smokingOutdoorOnly;

  /// No description provided for @smokingNotAllowed.
  ///
  /// In tr, this message translates to:
  /// **'Yasak'**
  String get smokingNotAllowed;

  /// No description provided for @dayMonday.
  ///
  /// In tr, this message translates to:
  /// **'Pazartesi'**
  String get dayMonday;

  /// No description provided for @dayTuesday.
  ///
  /// In tr, this message translates to:
  /// **'Salı'**
  String get dayTuesday;

  /// No description provided for @dayWednesday.
  ///
  /// In tr, this message translates to:
  /// **'Çarşamba'**
  String get dayWednesday;

  /// No description provided for @dayThursday.
  ///
  /// In tr, this message translates to:
  /// **'Perşembe'**
  String get dayThursday;

  /// No description provided for @dayFriday.
  ///
  /// In tr, this message translates to:
  /// **'Cuma'**
  String get dayFriday;

  /// No description provided for @daySaturday.
  ///
  /// In tr, this message translates to:
  /// **'Cumartesi'**
  String get daySaturday;

  /// No description provided for @daySunday.
  ///
  /// In tr, this message translates to:
  /// **'Pazar'**
  String get daySunday;

  /// No description provided for @categoryStudy.
  ///
  /// In tr, this message translates to:
  /// **'Çalışmaya uygun'**
  String get categoryStudy;

  /// No description provided for @categoryBestCoffee.
  ///
  /// In tr, this message translates to:
  /// **'En iyi kahve'**
  String get categoryBestCoffee;

  /// No description provided for @categoryAffordable.
  ///
  /// In tr, this message translates to:
  /// **'Uygun fiyatlı'**
  String get categoryAffordable;

  /// No description provided for @categoryAesthetic.
  ///
  /// In tr, this message translates to:
  /// **'Estetik'**
  String get categoryAesthetic;

  /// No description provided for @categoryQuiet.
  ///
  /// In tr, this message translates to:
  /// **'Sessiz'**
  String get categoryQuiet;

  /// No description provided for @categoryOutdoor.
  ///
  /// In tr, this message translates to:
  /// **'Açık hava'**
  String get categoryOutdoor;

  /// No description provided for @sortTopRated.
  ///
  /// In tr, this message translates to:
  /// **'En yüksek puan'**
  String get sortTopRated;

  /// No description provided for @sortNearest.
  ///
  /// In tr, this message translates to:
  /// **'En yakın'**
  String get sortNearest;

  /// No description provided for @sortCheapest.
  ///
  /// In tr, this message translates to:
  /// **'En uygun fiyat'**
  String get sortCheapest;

  /// No description provided for @sortStudy.
  ///
  /// In tr, this message translates to:
  /// **'Çalışmaya uygun'**
  String get sortStudy;

  /// No description provided for @sortAesthetic.
  ///
  /// In tr, this message translates to:
  /// **'En estetik'**
  String get sortAesthetic;

  /// No description provided for @preferenceWifi.
  ///
  /// In tr, this message translates to:
  /// **'Güçlü Wi‑Fi'**
  String get preferenceWifi;

  /// No description provided for @preferenceQuiet.
  ///
  /// In tr, this message translates to:
  /// **'Sessiz ortam'**
  String get preferenceQuiet;

  /// No description provided for @preferenceOutlet.
  ///
  /// In tr, this message translates to:
  /// **'Priz imkanı'**
  String get preferenceOutlet;

  /// No description provided for @preferenceStudy.
  ///
  /// In tr, this message translates to:
  /// **'Çalışmaya uygun'**
  String get preferenceStudy;

  /// No description provided for @preferenceAesthetic.
  ///
  /// In tr, this message translates to:
  /// **'Estetik ambiyans'**
  String get preferenceAesthetic;

  /// No description provided for @preferenceOutdoor.
  ///
  /// In tr, this message translates to:
  /// **'Açık hava'**
  String get preferenceOutdoor;

  /// No description provided for @preferencePetFriendly.
  ///
  /// In tr, this message translates to:
  /// **'Evcil hayvan dostu'**
  String get preferencePetFriendly;

  /// No description provided for @preferenceBudget.
  ///
  /// In tr, this message translates to:
  /// **'Uygun fiyat'**
  String get preferenceBudget;

  /// No description provided for @homeTitle.
  ///
  /// In tr, this message translates to:
  /// **'İstanbul\'da kafe bul'**
  String get homeTitle;

  /// No description provided for @homeSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Şehirdeki iyi kafeleri keşfet.'**
  String get homeSubtitle;

  /// No description provided for @homeSearchHint.
  ///
  /// In tr, this message translates to:
  /// **'Kafe ara...'**
  String get homeSearchHint;

  /// No description provided for @homePopularDistricts.
  ///
  /// In tr, this message translates to:
  /// **'Popüler semtler'**
  String get homePopularDistricts;

  /// No description provided for @homeCategories.
  ///
  /// In tr, this message translates to:
  /// **'Kategoriler'**
  String get homeCategories;

  /// No description provided for @homeFeatured.
  ///
  /// In tr, this message translates to:
  /// **'Öne çıkan kafeler'**
  String get homeFeatured;

  /// No description provided for @homeSponsoredCafes.
  ///
  /// In tr, this message translates to:
  /// **'Sponsorlu kafeler'**
  String get homeSponsoredCafes;

  /// No description provided for @homeSponsoredBadge.
  ///
  /// In tr, this message translates to:
  /// **'Sponsorlu'**
  String get homeSponsoredBadge;

  /// No description provided for @homeViewAll.
  ///
  /// In tr, this message translates to:
  /// **'Tümünü gör'**
  String get homeViewAll;

  /// No description provided for @homeEmptyTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kafe bulunamadı'**
  String get homeEmptyTitle;

  /// No description provided for @homeEmptyMessage.
  ///
  /// In tr, this message translates to:
  /// **'Arama kriterlerini değiştirerek tekrar deneyin.'**
  String get homeEmptyMessage;

  /// No description provided for @homeMockDataInfo.
  ///
  /// In tr, this message translates to:
  /// **'Supabase hazır olana kadar örnek kafe verileri gösteriliyor.'**
  String get homeMockDataInfo;

  /// No description provided for @homeMockFallbackInfo.
  ///
  /// In tr, this message translates to:
  /// **'Canlı veri alınamadı. Uygulama şu an örnek verilerle çalışıyor.'**
  String get homeMockFallbackInfo;

  /// No description provided for @exploreTitle.
  ///
  /// In tr, this message translates to:
  /// **'Keşfet'**
  String get exploreTitle;

  /// No description provided for @exploreResultCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} kafe'**
  String exploreResultCount(int count);

  /// No description provided for @exploreEmptyTitle.
  ///
  /// In tr, this message translates to:
  /// **'Filtrelere uygun kafe bulunamadı'**
  String get exploreEmptyTitle;

  /// No description provided for @exploreEmptyMessage.
  ///
  /// In tr, this message translates to:
  /// **'Arama veya filtreleri gevşeterek tekrar deneyin.'**
  String get exploreEmptyMessage;

  /// No description provided for @exploreEmptyCompareMessage.
  ///
  /// In tr, this message translates to:
  /// **'Geçerli filtrelere uygun kafe yok, ancak seçtiğin kafeler karşılaştırmaya hazır.'**
  String get exploreEmptyCompareMessage;

  /// No description provided for @favoritesTitle.
  ///
  /// In tr, this message translates to:
  /// **'Favoriler'**
  String get favoritesTitle;

  /// No description provided for @favoritesCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} kayıtlı'**
  String favoritesCount(int count);

  /// No description provided for @favoritesLoading.
  ///
  /// In tr, this message translates to:
  /// **'Favoriler yükleniyor'**
  String get favoritesLoading;

  /// No description provided for @favoritesEmptyTitle.
  ///
  /// In tr, this message translates to:
  /// **'Henüz favori kafen yok'**
  String get favoritesEmptyTitle;

  /// No description provided for @favoritesEmptyMessage.
  ///
  /// In tr, this message translates to:
  /// **'Beğendiğin kafeleri kaydet, buradan kolayca ulaş.'**
  String get favoritesEmptyMessage;

  /// No description provided for @favoritesExploreAction.
  ///
  /// In tr, this message translates to:
  /// **'Kafeleri keşfet'**
  String get favoritesExploreAction;

  /// No description provided for @profileGuestTitle.
  ///
  /// In tr, this message translates to:
  /// **'Giriş yapılmadı'**
  String get profileGuestTitle;

  /// No description provided for @profileGuestAction.
  ///
  /// In tr, this message translates to:
  /// **'Giriş yap'**
  String get profileGuestAction;

  /// No description provided for @profileSectionAccount.
  ///
  /// In tr, this message translates to:
  /// **'Hesap'**
  String get profileSectionAccount;

  /// Profil degisikligi cevrimdisi kuyruga alindiginda gosterilen basari mesaji.
  ///
  /// In tr, this message translates to:
  /// **'Değişikliklerin çevrimdışı kaydedildi ve bağlantı gelince otomatik eşitlenecek.'**
  String get profileSyncQueued;

  /// Hala kuyrukta bekleyen cevrimdisi degisiklik sayisini gosteren durum metni.
  ///
  /// In tr, this message translates to:
  /// **'{count} değişiklik eşitleme bekliyor.'**
  String profileSyncPending(int count);

  /// Otomatik esitlemesi basarisiz olan kuyruktaki degisiklik sayisini gosteren durum metni.
  ///
  /// In tr, this message translates to:
  /// **'{count} değişiklik otomatik olarak eşitlenemedi.'**
  String profileSyncDeadLetters(int count);

  /// No description provided for @profileEditIntro.
  ///
  /// In tr, this message translates to:
  /// **'Profil bilgilerini buradan güncelleyebilirsin.'**
  String get profileEditIntro;

  /// No description provided for @profilePhotoLabel.
  ///
  /// In tr, this message translates to:
  /// **'Profil fotoğrafı'**
  String get profilePhotoLabel;

  /// No description provided for @profilePhotoHint.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf ekleyerek profilini daha kolay tanınır hale getir.'**
  String get profilePhotoHint;

  /// No description provided for @profilePhotoPending.
  ///
  /// In tr, this message translates to:
  /// **'Yeni fotoğraf seçildi. Kaydet dediğinde profiline yüklenecek.'**
  String get profilePhotoPending;

  /// No description provided for @profilePhotoPreviewReady.
  ///
  /// In tr, this message translates to:
  /// **'Önizleme hazır. Kaydettiğinde fotoğraf yüklenecek.'**
  String get profilePhotoPreviewReady;

  /// No description provided for @profilePhotoReplaceHint.
  ///
  /// In tr, this message translates to:
  /// **'Mevcut fotoğrafını değiştirebilir veya kaldırabilirsin.'**
  String get profilePhotoReplaceHint;

  /// No description provided for @profilePhotoPickHint.
  ///
  /// In tr, this message translates to:
  /// **'Galeriden fotoğraf seçerek kaydetmeden önce önizleyebilirsin.'**
  String get profilePhotoPickHint;

  /// No description provided for @profilePhotoEdit.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğrafı düzenle'**
  String get profilePhotoEdit;

  /// No description provided for @profilePhotoRemove.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğrafı kaldır'**
  String get profilePhotoRemove;

  /// No description provided for @profilePhotoChooseGallery.
  ///
  /// In tr, this message translates to:
  /// **'Galeriden seç'**
  String get profilePhotoChooseGallery;

  /// No description provided for @profilePhotoPickFailed.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf seçilemedi. Lütfen tekrar dene.'**
  String get profilePhotoPickFailed;

  /// No description provided for @profileUsernameHint.
  ///
  /// In tr, this message translates to:
  /// **'3-24 karakter'**
  String get profileUsernameHint;

  /// No description provided for @profileEdit.
  ///
  /// In tr, this message translates to:
  /// **'Profili düzenle'**
  String get profileEdit;

  /// No description provided for @profileAdminPanel.
  ///
  /// In tr, this message translates to:
  /// **'Yönetim paneli'**
  String get profileAdminPanel;

  /// No description provided for @profileManagerBadge.
  ///
  /// In tr, this message translates to:
  /// **'Yönetici'**
  String get profileManagerBadge;

  /// No description provided for @profileEmail.
  ///
  /// In tr, this message translates to:
  /// **'E-posta'**
  String get profileEmail;

  /// No description provided for @profileUsername.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı adı'**
  String get profileUsername;

  /// No description provided for @profileFullName.
  ///
  /// In tr, this message translates to:
  /// **'Ad soyad'**
  String get profileFullName;

  /// No description provided for @profileSignOut.
  ///
  /// In tr, this message translates to:
  /// **'Çıkış yap'**
  String get profileSignOut;

  /// No description provided for @authWelcome.
  ///
  /// In tr, this message translates to:
  /// **'Hoş geldin'**
  String get authWelcome;

  /// No description provided for @authSignUpTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kayıt ol'**
  String get authSignUpTitle;

  /// No description provided for @authDarkMode.
  ///
  /// In tr, this message translates to:
  /// **'Koyu'**
  String get authDarkMode;

  /// No description provided for @authSignUpSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Hesap oluşturmak için bilgilerini gir.'**
  String get authSignUpSubtitle;

  /// No description provided for @authSignInSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'E-posta veya kullanıcı adınla giriş yap.'**
  String get authSignInSubtitle;

  /// No description provided for @authUsername.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı adı'**
  String get authUsername;

  /// No description provided for @authFirstName.
  ///
  /// In tr, this message translates to:
  /// **'Ad'**
  String get authFirstName;

  /// No description provided for @authLastName.
  ///
  /// In tr, this message translates to:
  /// **'Soyad'**
  String get authLastName;

  /// No description provided for @authEmail.
  ///
  /// In tr, this message translates to:
  /// **'E-posta'**
  String get authEmail;

  /// No description provided for @authEmailOrUsername.
  ///
  /// In tr, this message translates to:
  /// **'E-posta veya kullanıcı adı'**
  String get authEmailOrUsername;

  /// No description provided for @authPassword.
  ///
  /// In tr, this message translates to:
  /// **'Şifre (en az 6 karakter)'**
  String get authPassword;

  /// No description provided for @authEmailRequired.
  ///
  /// In tr, this message translates to:
  /// **'E-posta adresini gir.'**
  String get authEmailRequired;

  /// No description provided for @authIdentifierRequired.
  ///
  /// In tr, this message translates to:
  /// **'E-posta veya kullanıcı adını gir.'**
  String get authIdentifierRequired;

  /// No description provided for @authResetNeedsEmail.
  ///
  /// In tr, this message translates to:
  /// **'Şifreni sıfırlamak için e-posta adresini gir.'**
  String get authResetNeedsEmail;

  /// No description provided for @authPasswordRequired.
  ///
  /// In tr, this message translates to:
  /// **'Şifreni gir.'**
  String get authPasswordRequired;

  /// No description provided for @authPasswordTooShort.
  ///
  /// In tr, this message translates to:
  /// **'Şifre en az 6 karakter olmalı.'**
  String get authPasswordTooShort;

  /// No description provided for @authShowPassword.
  ///
  /// In tr, this message translates to:
  /// **'Şifreyi göster'**
  String get authShowPassword;

  /// No description provided for @authHidePassword.
  ///
  /// In tr, this message translates to:
  /// **'Şifreyi gizle'**
  String get authHidePassword;

  /// No description provided for @authForgotPassword.
  ///
  /// In tr, this message translates to:
  /// **'Şifremi unuttum'**
  String get authForgotPassword;

  /// No description provided for @authResetPasswordSent.
  ///
  /// In tr, this message translates to:
  /// **'Şifre sıfırlama bağlantısı gönderildi. Gelen kutunu kontrol et.'**
  String get authResetPasswordSent;

  /// No description provided for @authSignIn.
  ///
  /// In tr, this message translates to:
  /// **'Giriş yap'**
  String get authSignIn;

  /// No description provided for @authSignUp.
  ///
  /// In tr, this message translates to:
  /// **'Kayıt ol'**
  String get authSignUp;

  /// No description provided for @authHasAccount.
  ///
  /// In tr, this message translates to:
  /// **'Zaten hesabım var'**
  String get authHasAccount;

  /// No description provided for @authCreateAccount.
  ///
  /// In tr, this message translates to:
  /// **'Yeni hesap oluştur'**
  String get authCreateAccount;

  /// No description provided for @authRetryIn.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar dene ({seconds}s)'**
  String authRetryIn(int seconds);

  /// No description provided for @authTooManyAttempts.
  ///
  /// In tr, this message translates to:
  /// **'Çok fazla deneme. {seconds} saniye sonra tekrar dene.'**
  String authTooManyAttempts(int seconds);

  /// No description provided for @authSignUpSuccess.
  ///
  /// In tr, this message translates to:
  /// **'Hesabın oluşturuldu. E-posta adresini doğrulamak için gelen kutunu kontrol et.'**
  String get authSignUpSuccess;

  /// No description provided for @authGenericError.
  ///
  /// In tr, this message translates to:
  /// **'Bir şeyler ters gitti.'**
  String get authGenericError;

  /// Yorum cevrimdisi kuyruga alindiginda gosterilen basari mesaji.
  ///
  /// In tr, this message translates to:
  /// **'Yorumun çevrimdışı kaydedildi ve bağlantı gelince otomatik eşitlenecek.'**
  String get reviewsQueuedSuccess;

  /// No description provided for @onboardingBrand.
  ///
  /// In tr, this message translates to:
  /// **'İstanbul Kafe'**
  String get onboardingBrand;

  /// No description provided for @onboardingTitle.
  ///
  /// In tr, this message translates to:
  /// **'İstanbul\'da bir sonraki favori kafeni keşfet'**
  String get onboardingTitle;

  /// No description provided for @onboardingSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Senin için en önemli şeyleri seç, önerileri buna göre düzenleyelim.'**
  String get onboardingSubtitle;

  /// No description provided for @onboardingContinue.
  ///
  /// In tr, this message translates to:
  /// **'Keşfetmeye başla'**
  String get onboardingContinue;

  /// No description provided for @filterTitle.
  ///
  /// In tr, this message translates to:
  /// **'Filtreler'**
  String get filterTitle;

  /// No description provided for @filterDistrict.
  ///
  /// In tr, this message translates to:
  /// **'İlçe'**
  String get filterDistrict;

  /// No description provided for @filterPrice.
  ///
  /// In tr, this message translates to:
  /// **'Fiyat'**
  String get filterPrice;

  /// No description provided for @filterMinRating.
  ///
  /// In tr, this message translates to:
  /// **'Min. puan'**
  String get filterMinRating;

  /// No description provided for @filterMinRatingOption.
  ///
  /// In tr, this message translates to:
  /// **'Puan {rating}+'**
  String filterMinRatingOption(String rating);

  /// No description provided for @filterWifi.
  ///
  /// In tr, this message translates to:
  /// **'Wi‑Fi'**
  String get filterWifi;

  /// No description provided for @filterOutlet.
  ///
  /// In tr, this message translates to:
  /// **'Priz'**
  String get filterOutlet;

  /// No description provided for @filterQuietness.
  ///
  /// In tr, this message translates to:
  /// **'Sessizlik'**
  String get filterQuietness;

  /// No description provided for @filterSmoking.
  ///
  /// In tr, this message translates to:
  /// **'Sigara'**
  String get filterSmoking;

  /// No description provided for @filterOpenNow.
  ///
  /// In tr, this message translates to:
  /// **'Şu an açık'**
  String get filterOpenNow;

  /// No description provided for @filterStudyFriendly.
  ///
  /// In tr, this message translates to:
  /// **'Çalışmaya uygun'**
  String get filterStudyFriendly;

  /// No description provided for @filterPetFriendly.
  ///
  /// In tr, this message translates to:
  /// **'Evcil hayvan dostu'**
  String get filterPetFriendly;

  /// No description provided for @filterOutdoorSeating.
  ///
  /// In tr, this message translates to:
  /// **'Açık hava oturma'**
  String get filterOutdoorSeating;

  /// No description provided for @filterApplyCount.
  ///
  /// In tr, this message translates to:
  /// **'Uygula ({count} filtre)'**
  String filterApplyCount(int count);

  /// No description provided for @filterPresetsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kayıtlı filtreler'**
  String get filterPresetsTitle;

  /// No description provided for @filterPresetNameHint.
  ///
  /// In tr, this message translates to:
  /// **'Geçerli filtreleri bir hazır ayar olarak kaydet'**
  String get filterPresetNameHint;

  /// No description provided for @filterPresetNameEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Hazır ayar adı boş olamaz.'**
  String get filterPresetNameEmpty;

  /// No description provided for @filterPresetNeedFilters.
  ///
  /// In tr, this message translates to:
  /// **'Kaydetmeden önce en az bir filtre ekleyin.'**
  String get filterPresetNeedFilters;

  /// No description provided for @filterPresetUpdated.
  ///
  /// In tr, this message translates to:
  /// **'Hazır ayar güncellendi.'**
  String get filterPresetUpdated;

  /// No description provided for @filterPresetSaved.
  ///
  /// In tr, this message translates to:
  /// **'Hazır ayar kaydedildi.'**
  String get filterPresetSaved;

  /// No description provided for @filterPresetEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Henüz hazır ayar yok. Tekrar kullanmak için geçerli filtreleri kaydedin.'**
  String get filterPresetEmpty;

  /// No description provided for @mapPreparing.
  ///
  /// In tr, this message translates to:
  /// **'Harita görünümü hazırlanıyor'**
  String get mapPreparing;

  /// No description provided for @mapLocateMe.
  ///
  /// In tr, this message translates to:
  /// **'Konumumu bul'**
  String get mapLocateMe;

  /// No description provided for @mapEmptyTitle.
  ///
  /// In tr, this message translates to:
  /// **'Haritada gösterilecek kafe yok'**
  String get mapEmptyTitle;

  /// No description provided for @mapNearbyEmptyMessage.
  ///
  /// In tr, this message translates to:
  /// **'Yakındaki harita alanında kafe bulunamadı. Daha geniş keşif için bir ilçe seçin.'**
  String get mapNearbyEmptyMessage;

  /// No description provided for @mapNoResultsForFiltersMessage.
  ///
  /// In tr, this message translates to:
  /// **'İstanbul genelinde daha fazla kafe görmek için filtreleri sıfırlamayı deneyin.'**
  String get mapNoResultsForFiltersMessage;

  /// No description provided for @mapDataUnavailableOverlayMessage.
  ///
  /// In tr, this message translates to:
  /// **'Kafe verileri hâlâ yükleniyor veya şu anda kullanılamıyor.'**
  String get mapDataUnavailableOverlayMessage;

  /// No description provided for @mapNearbyRadiusMessage.
  ///
  /// In tr, this message translates to:
  /// **'{radius} içindeki kafeler gösteriliyor. Daha geniş keşif için bir ilçe seçin.'**
  String mapNearbyRadiusMessage(String radius);

  /// No description provided for @mapEmptyMessage.
  ///
  /// In tr, this message translates to:
  /// **'Veri geldikçe burada yer işaretleri görünecek.'**
  String get mapEmptyMessage;

  /// No description provided for @mapUnavailableMessage.
  ///
  /// In tr, this message translates to:
  /// **'Bu özellik şu anda kullanılamıyor.'**
  String get mapUnavailableMessage;

  /// No description provided for @mapNoPhotos.
  ///
  /// In tr, this message translates to:
  /// **'Henüz fotoğraf eklenmemiş'**
  String get mapNoPhotos;

  /// No description provided for @mapPhotoCount.
  ///
  /// In tr, this message translates to:
  /// **'{current}/{total}'**
  String mapPhotoCount(int current, int total);

  /// No description provided for @mapDevModeInfo.
  ///
  /// In tr, this message translates to:
  /// **'Geliştirme haritası aktif. {count} kafe sahte pinlerle gösteriliyor.'**
  String mapDevModeInfo(int count);

  /// No description provided for @mapDevModeHint.
  ///
  /// In tr, this message translates to:
  /// **'Google Maps API anahtarı hazır olduğunda bu ekran gerçek harita ile değiştirilebilir.'**
  String get mapDevModeHint;

  /// No description provided for @mapFilterCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} filtre'**
  String mapFilterCount(int count);

  /// No description provided for @mapRadiusSmall.
  ///
  /// In tr, this message translates to:
  /// **'1 km'**
  String get mapRadiusSmall;

  /// No description provided for @mapRadiusMedium.
  ///
  /// In tr, this message translates to:
  /// **'2 km'**
  String get mapRadiusMedium;

  /// No description provided for @mapRadiusLarge.
  ///
  /// In tr, this message translates to:
  /// **'4 km'**
  String get mapRadiusLarge;

  /// No description provided for @mapDevLabel.
  ///
  /// In tr, this message translates to:
  /// **'İstanbul geliştirme haritası'**
  String get mapDevLabel;

  /// No description provided for @cafeDetailNotFound.
  ///
  /// In tr, this message translates to:
  /// **'Bu kafe bulunamadı veya veri henüz yüklenmedi.'**
  String get cafeDetailNotFound;

  /// No description provided for @cafeDetailDetails.
  ///
  /// In tr, this message translates to:
  /// **'Detaylar'**
  String get cafeDetailDetails;

  /// No description provided for @cafeDetailContributionTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bu kafeyi birlikte iyileştirelim'**
  String get cafeDetailContributionTitle;

  /// No description provided for @cafeDetailContributionSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Wi‑Fi, ses seviyesi, priz ve çalışma konforu gibi gerçek detaylar ekleyin.'**
  String get cafeDetailContributionSubtitle;

  /// No description provided for @cafeDetailHours.
  ///
  /// In tr, this message translates to:
  /// **'Çalışma saatleri'**
  String get cafeDetailHours;

  /// No description provided for @cafeDetailHoursEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Saat bilgisi henüz eklenmemiş.'**
  String get cafeDetailHoursEmpty;

  /// No description provided for @cafeDetailMenuHighlights.
  ///
  /// In tr, this message translates to:
  /// **'Menü öne çıkanlar'**
  String get cafeDetailMenuHighlights;

  /// No description provided for @cafeDetailDescriptionFallback.
  ///
  /// In tr, this message translates to:
  /// **'Bu kafe için henüz açıklama eklenmemiş.'**
  String get cafeDetailDescriptionFallback;

  /// No description provided for @cafeDetailSave.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get cafeDetailSave;

  /// No description provided for @cafeDetailSaved.
  ///
  /// In tr, this message translates to:
  /// **'Kaydedildi'**
  String get cafeDetailSaved;

  /// No description provided for @cafeDetailCompare.
  ///
  /// In tr, this message translates to:
  /// **'Karşılaştır'**
  String get cafeDetailCompare;

  /// No description provided for @cafeDetailCompared.
  ///
  /// In tr, this message translates to:
  /// **'Eklendi'**
  String get cafeDetailCompared;

  /// No description provided for @cafeDetailOpenOnMap.
  ///
  /// In tr, this message translates to:
  /// **'Haritada aç'**
  String get cafeDetailOpenOnMap;

  /// No description provided for @metadataJustNow.
  ///
  /// In tr, this message translates to:
  /// **'az önce'**
  String get metadataJustNow;

  /// No description provided for @metadataMinutesAgo.
  ///
  /// In tr, this message translates to:
  /// **'{count}dk önce'**
  String metadataMinutesAgo(int count);

  /// No description provided for @metadataHoursAgo.
  ///
  /// In tr, this message translates to:
  /// **'{count}sa önce'**
  String metadataHoursAgo(int count);

  /// No description provided for @metadataDaysAgo.
  ///
  /// In tr, this message translates to:
  /// **'{count}g önce'**
  String metadataDaysAgo(int count);

  /// No description provided for @metricWifi.
  ///
  /// In tr, this message translates to:
  /// **'Wi‑Fi'**
  String get metricWifi;

  /// No description provided for @metricOutlet.
  ///
  /// In tr, this message translates to:
  /// **'Priz'**
  String get metricOutlet;

  /// No description provided for @metricQuietness.
  ///
  /// In tr, this message translates to:
  /// **'Sessizlik'**
  String get metricQuietness;

  /// No description provided for @metricPrice.
  ///
  /// In tr, this message translates to:
  /// **'Fiyat'**
  String get metricPrice;

  /// No description provided for @metricSeating.
  ///
  /// In tr, this message translates to:
  /// **'Oturma'**
  String get metricSeating;

  /// No description provided for @metricAmbiance.
  ///
  /// In tr, this message translates to:
  /// **'Ambiyans'**
  String get metricAmbiance;

  /// No description provided for @metricStudyFriendly.
  ///
  /// In tr, this message translates to:
  /// **'Çalışmaya uygun'**
  String get metricStudyFriendly;

  /// No description provided for @metricPetFriendly.
  ///
  /// In tr, this message translates to:
  /// **'Evcil hayvan'**
  String get metricPetFriendly;

  /// No description provided for @metricOutdoor.
  ///
  /// In tr, this message translates to:
  /// **'Açık hava'**
  String get metricOutdoor;

  /// No description provided for @metricSmoking.
  ///
  /// In tr, this message translates to:
  /// **'Sigara'**
  String get metricSmoking;

  /// No description provided for @metricAvailable.
  ///
  /// In tr, this message translates to:
  /// **'Var'**
  String get metricAvailable;

  /// No description provided for @metricYes.
  ///
  /// In tr, this message translates to:
  /// **'Evet'**
  String get metricYes;

  /// No description provided for @metricFriendly.
  ///
  /// In tr, this message translates to:
  /// **'Dostu'**
  String get metricFriendly;

  /// No description provided for @cafeCardSemanticLabel.
  ///
  /// In tr, this message translates to:
  /// **'{name} kafe kartı'**
  String cafeCardSemanticLabel(String name);

  /// No description provided for @cafeCardCompare.
  ///
  /// In tr, this message translates to:
  /// **'Karşılaştır'**
  String get cafeCardCompare;

  /// No description provided for @cafeCardCompared.
  ///
  /// In tr, this message translates to:
  /// **'Eklendi'**
  String get cafeCardCompared;

  /// No description provided for @cafeCardSave.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get cafeCardSave;

  /// No description provided for @cafeCardSaved.
  ///
  /// In tr, this message translates to:
  /// **'Kaydedildi'**
  String get cafeCardSaved;

  /// No description provided for @compareTitle.
  ///
  /// In tr, this message translates to:
  /// **'Karşılaştır'**
  String get compareTitle;

  /// No description provided for @compareCategory.
  ///
  /// In tr, this message translates to:
  /// **'Kategori'**
  String get compareCategory;

  /// No description provided for @compareAddCafeAction.
  ///
  /// In tr, this message translates to:
  /// **'Karşılaştırmaya kafe ekle'**
  String get compareAddCafeAction;

  /// No description provided for @compareOpenCafeAction.
  ///
  /// In tr, this message translates to:
  /// **'Kafeyi aç'**
  String get compareOpenCafeAction;

  /// No description provided for @compareSelectedCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} kafe seçildi'**
  String compareSelectedCount(int count);

  /// No description provided for @compareEmptyMessage.
  ///
  /// In tr, this message translates to:
  /// **'Karşılaştırmak için kafe ekle.'**
  String get compareEmptyMessage;

  /// No description provided for @compareEmptyAddCafes.
  ///
  /// In tr, this message translates to:
  /// **'Kafe ekle'**
  String get compareEmptyAddCafes;

  /// No description provided for @compareEmptyExploreCafes.
  ///
  /// In tr, this message translates to:
  /// **'Kafeleri keşfet'**
  String get compareEmptyExploreCafes;

  /// No description provided for @compareUnresolvedMessage.
  ///
  /// In tr, this message translates to:
  /// **'Bu seçili kafe yüklenemedi.'**
  String get compareUnresolvedMessage;

  /// No description provided for @compareUnresolvedCount.
  ///
  /// In tr, this message translates to:
  /// **'{count, plural, =1{1 seçili kafe yüklenemedi.} other{{count} seçili kafe yüklenemedi.}}'**
  String compareUnresolvedCount(int count);

  /// No description provided for @compareCompactHint.
  ///
  /// In tr, this message translates to:
  /// **'En iyi değerler hızlı karşılaştırma için vurgulanır.'**
  String get compareCompactHint;

  /// No description provided for @compareFeature.
  ///
  /// In tr, this message translates to:
  /// **'Özellik'**
  String get compareFeature;

  /// No description provided for @compareRating.
  ///
  /// In tr, this message translates to:
  /// **'Puan'**
  String get compareRating;

  /// No description provided for @compareCommunityRating.
  ///
  /// In tr, this message translates to:
  /// **'Topluluk puanı'**
  String get compareCommunityRating;

  /// No description provided for @compareGoogleRating.
  ///
  /// In tr, this message translates to:
  /// **'Google puanı'**
  String get compareGoogleRating;

  /// No description provided for @compareGoogleReviews.
  ///
  /// In tr, this message translates to:
  /// **'Google yorumları'**
  String get compareGoogleReviews;

  /// No description provided for @compareDistance.
  ///
  /// In tr, this message translates to:
  /// **'Mesafe'**
  String get compareDistance;

  /// No description provided for @compareFeatures.
  ///
  /// In tr, this message translates to:
  /// **'Özellikler'**
  String get compareFeatures;

  /// No description provided for @compareHighlights.
  ///
  /// In tr, this message translates to:
  /// **'Önerilenler'**
  String get compareHighlights;

  /// No description provided for @compareOpeningStatus.
  ///
  /// In tr, this message translates to:
  /// **'Açılış durumu'**
  String get compareOpeningStatus;

  /// No description provided for @compareHoursUnavailable.
  ///
  /// In tr, this message translates to:
  /// **'Saat bilgisi yok'**
  String get compareHoursUnavailable;

  /// No description provided for @compareAddAnotherPrompt.
  ///
  /// In tr, this message translates to:
  /// **'Başka bir kafe ekle'**
  String get compareAddAnotherPrompt;

  /// No description provided for @compareUnresolvedSlot.
  ///
  /// In tr, this message translates to:
  /// **'Kafe kullanılamıyor'**
  String get compareUnresolvedSlot;

  /// No description provided for @compareAddressDistrict.
  ///
  /// In tr, this message translates to:
  /// **'Adres / ilçe'**
  String get compareAddressDistrict;

  /// No description provided for @comparePrice.
  ///
  /// In tr, this message translates to:
  /// **'Fiyat'**
  String get comparePrice;

  /// No description provided for @compareNoAppReviewsYet.
  ///
  /// In tr, this message translates to:
  /// **'Henüz uygulama yorumu yok'**
  String get compareNoAppReviewsYet;

  /// No description provided for @compareGoogleRatingUnavailable.
  ///
  /// In tr, this message translates to:
  /// **'Google puanı mevcut değil'**
  String get compareGoogleRatingUnavailable;

  /// No description provided for @compareWifi.
  ///
  /// In tr, this message translates to:
  /// **'Wi‑Fi'**
  String get compareWifi;

  /// No description provided for @compareOutlet.
  ///
  /// In tr, this message translates to:
  /// **'Priz'**
  String get compareOutlet;

  /// No description provided for @compareQuietness.
  ///
  /// In tr, this message translates to:
  /// **'Sessizlik'**
  String get compareQuietness;

  /// No description provided for @compareAmbiance.
  ///
  /// In tr, this message translates to:
  /// **'Ambiyans'**
  String get compareAmbiance;

  /// No description provided for @compareSeatingComfort.
  ///
  /// In tr, this message translates to:
  /// **'Oturma konforu'**
  String get compareSeatingComfort;

  /// No description provided for @compareStudyFriendly.
  ///
  /// In tr, this message translates to:
  /// **'Çalışmaya uygun'**
  String get compareStudyFriendly;

  /// No description provided for @comparePetFriendly.
  ///
  /// In tr, this message translates to:
  /// **'Evcil hayvan'**
  String get comparePetFriendly;

  /// No description provided for @compareOutdoor.
  ///
  /// In tr, this message translates to:
  /// **'Açık hava'**
  String get compareOutdoor;

  /// No description provided for @compareSmoking.
  ///
  /// In tr, this message translates to:
  /// **'Sigara'**
  String get compareSmoking;

  /// No description provided for @compareDistrict.
  ///
  /// In tr, this message translates to:
  /// **'İlçe'**
  String get compareDistrict;

  /// No description provided for @compareYes.
  ///
  /// In tr, this message translates to:
  /// **'Evet'**
  String get compareYes;

  /// No description provided for @compareNo.
  ///
  /// In tr, this message translates to:
  /// **'Hayır'**
  String get compareNo;

  /// No description provided for @compareAvailable.
  ///
  /// In tr, this message translates to:
  /// **'Var'**
  String get compareAvailable;

  /// No description provided for @compareUnavailable.
  ///
  /// In tr, this message translates to:
  /// **'Yok'**
  String get compareUnavailable;

  /// No description provided for @compareEmptyFeatureCommunityRating.
  ///
  /// In tr, this message translates to:
  /// **'Uygulama yorumlarÄ±ndan gelen kullanÄ±cÄ± puanÄ±.'**
  String get compareEmptyFeatureCommunityRating;

  /// No description provided for @compareEmptyFeaturePrice.
  ///
  /// In tr, this message translates to:
  /// **'Tipik bir ziyaret iÃ§in tahmini fiyat seviyesi.'**
  String get compareEmptyFeaturePrice;

  /// No description provided for @compareEmptyFeatureDistrict.
  ///
  /// In tr, this message translates to:
  /// **'Kafenin konum bÃ¶lgesi ve adres baÄŸlamÄ±.'**
  String get compareEmptyFeatureDistrict;

  /// No description provided for @compareEmptyFeatureWifi.
  ///
  /// In tr, this message translates to:
  /// **'Kafenin Ã§alÄ±ÅŸmaya veya ders Ã§alÄ±ÅŸmaya uygunluÄŸu.'**
  String get compareEmptyFeatureWifi;

  /// No description provided for @compareEmptyFeatureAmbiance.
  ///
  /// In tr, this message translates to:
  /// **'Genel atmosfer ve konfor sinyalleri.'**
  String get compareEmptyFeatureAmbiance;

  /// No description provided for @compareEmptyFeatureOutlet.
  ///
  /// In tr, this message translates to:
  /// **'DizÃ¼stÃ¼ ve telefonlar iÃ§in ÅŸarj imkanÄ±.'**
  String get compareEmptyFeatureOutlet;

  /// No description provided for @settingsAboutDescription.
  ///
  /// In tr, this message translates to:
  /// **'İstanbul\'daki en iyi kafeleri keşfet, karşılaştır ve favorilerine ekle.'**
  String get settingsAboutDescription;

  /// No description provided for @adminTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yönetim paneli'**
  String get adminTitle;

  /// No description provided for @adminBlockedTitle.
  ///
  /// In tr, this message translates to:
  /// **'Erişim engellendi'**
  String get adminBlockedTitle;

  /// No description provided for @adminBlockedMessage.
  ///
  /// In tr, this message translates to:
  /// **'Bu sayfa yalnızca yöneticiler tarafından görüntülenebilir.'**
  String get adminBlockedMessage;

  /// No description provided for @adminUsersTab.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcılar ({count})'**
  String adminUsersTab(int count);

  /// No description provided for @adminCafesTab.
  ///
  /// In tr, this message translates to:
  /// **'Kafeler ({count})'**
  String adminCafesTab(int count);

  /// No description provided for @adminSearchUsers.
  ///
  /// In tr, this message translates to:
  /// **'İsim, kullanıcı adı veya e-posta ara...'**
  String get adminSearchUsers;

  /// No description provided for @adminRoleAll.
  ///
  /// In tr, this message translates to:
  /// **'Tümü'**
  String get adminRoleAll;

  /// No description provided for @adminRoleAdmin.
  ///
  /// In tr, this message translates to:
  /// **'Yönetici'**
  String get adminRoleAdmin;

  /// No description provided for @adminRoleUser.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı'**
  String get adminRoleUser;

  /// No description provided for @adminNoResults.
  ///
  /// In tr, this message translates to:
  /// **'Sonuç bulunamadı.'**
  String get adminNoResults;

  /// No description provided for @adminUnnamedUser.
  ///
  /// In tr, this message translates to:
  /// **'İsimsiz kullanıcı'**
  String get adminUnnamedUser;

  /// No description provided for @adminAddCafe.
  ///
  /// In tr, this message translates to:
  /// **'Yeni kafe ekle'**
  String get adminAddCafe;

  /// No description provided for @adminEdit.
  ///
  /// In tr, this message translates to:
  /// **'Düzenle'**
  String get adminEdit;

  /// No description provided for @profileEditTitle.
  ///
  /// In tr, this message translates to:
  /// **'Profili düzenle'**
  String get profileEditTitle;

  /// No description provided for @profileEditFirstNameRequired.
  ///
  /// In tr, this message translates to:
  /// **'Ad alanı boş bırakılamaz.'**
  String get profileEditFirstNameRequired;

  /// No description provided for @profileEditLastNameRequired.
  ///
  /// In tr, this message translates to:
  /// **'Soyad alanı boş bırakılamaz.'**
  String get profileEditLastNameRequired;

  /// No description provided for @profileEditUsernameRequired.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı adı boş bırakılamaz.'**
  String get profileEditUsernameRequired;

  /// No description provided for @profileEditUsernameInvalid.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı adı 3-24 karakter olmalı.'**
  String get profileEditUsernameInvalid;

  /// No description provided for @profileEditEmailRequired.
  ///
  /// In tr, this message translates to:
  /// **'E-posta alanı boş bırakılamaz.'**
  String get profileEditEmailRequired;

  /// No description provided for @profileEditEmailInvalid.
  ///
  /// In tr, this message translates to:
  /// **'Geçerli bir e-posta girin.'**
  String get profileEditEmailInvalid;

  /// No description provided for @profileEditUnavailable.
  ///
  /// In tr, this message translates to:
  /// **'Supabase ayarlanmadan profil güncellenemez.'**
  String get profileEditUnavailable;

  /// No description provided for @profileEditSuccess.
  ///
  /// In tr, this message translates to:
  /// **'Profil güncellendi.'**
  String get profileEditSuccess;

  /// No description provided for @profileEditEmailHint.
  ///
  /// In tr, this message translates to:
  /// **'E-posta değişikliği doğrulama gerektirir'**
  String get profileEditEmailHint;

  /// No description provided for @cafeFormName.
  ///
  /// In tr, this message translates to:
  /// **'Kafe adı'**
  String get cafeFormName;

  /// No description provided for @cafeFormDistrict.
  ///
  /// In tr, this message translates to:
  /// **'İlçe'**
  String get cafeFormDistrict;

  /// No description provided for @cafeFormNeighborhood.
  ///
  /// In tr, this message translates to:
  /// **'Mahalle'**
  String get cafeFormNeighborhood;

  /// No description provided for @cafeFormAddress.
  ///
  /// In tr, this message translates to:
  /// **'Adres'**
  String get cafeFormAddress;

  /// No description provided for @cafeFormDescription.
  ///
  /// In tr, this message translates to:
  /// **'Açıklama'**
  String get cafeFormDescription;

  /// No description provided for @cafeFormPrice.
  ///
  /// In tr, this message translates to:
  /// **'Fiyat'**
  String get cafeFormPrice;

  /// No description provided for @cafeFormPriceUnknown.
  ///
  /// In tr, this message translates to:
  /// **'Belirtilmemiş'**
  String get cafeFormPriceUnknown;

  /// No description provided for @cafeFormWifi.
  ///
  /// In tr, this message translates to:
  /// **'Wi‑Fi'**
  String get cafeFormWifi;

  /// No description provided for @cafeFormOutlet.
  ///
  /// In tr, this message translates to:
  /// **'Priz'**
  String get cafeFormOutlet;

  /// No description provided for @cafeFormQuietness.
  ///
  /// In tr, this message translates to:
  /// **'Sessizlik'**
  String get cafeFormQuietness;

  /// No description provided for @cafeFormStudyFriendly.
  ///
  /// In tr, this message translates to:
  /// **'Çalışmaya uygun'**
  String get cafeFormStudyFriendly;

  /// No description provided for @cafeFormPetFriendly.
  ///
  /// In tr, this message translates to:
  /// **'Evcil hayvan dostu'**
  String get cafeFormPetFriendly;

  /// No description provided for @cafeFormOutdoorSeating.
  ///
  /// In tr, this message translates to:
  /// **'Açık hava oturma'**
  String get cafeFormOutdoorSeating;

  /// No description provided for @cafeFormSmoking.
  ///
  /// In tr, this message translates to:
  /// **'Sigara'**
  String get cafeFormSmoking;

  /// No description provided for @cafeFormTags.
  ///
  /// In tr, this message translates to:
  /// **'Etiketler (virgülle ayır)'**
  String get cafeFormTags;

  /// No description provided for @cafeFormPhotos.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf URL\'leri'**
  String get cafeFormPhotos;

  /// No description provided for @cafeFormPhotosHint.
  ///
  /// In tr, this message translates to:
  /// **'Görsel URL\'lerini virgül veya yeni satır ile ayırarak ekleyin.'**
  String get cafeFormPhotosHint;

  /// No description provided for @cafeFormSaving.
  ///
  /// In tr, this message translates to:
  /// **'Kaydediliyor...'**
  String get cafeFormSaving;

  /// No description provided for @errorPhotoUrlsInvalid.
  ///
  /// In tr, this message translates to:
  /// **'Geçerli görsel URL\'leri girin veya alanı boş bırakın.'**
  String get errorPhotoUrlsInvalid;

  /// No description provided for @cafeAddTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yeni kafe ekle'**
  String get cafeAddTitle;

  /// No description provided for @cafeAddNameRequired.
  ///
  /// In tr, this message translates to:
  /// **'Kafe adı boş bırakılamaz.'**
  String get cafeAddNameRequired;

  /// No description provided for @cafeAddUnavailable.
  ///
  /// In tr, this message translates to:
  /// **'Supabase ayarlanmadan kafe eklenemez.'**
  String get cafeAddUnavailable;

  /// No description provided for @cafeAddSuccess.
  ///
  /// In tr, this message translates to:
  /// **'Kafe eklendi.'**
  String get cafeAddSuccess;

  /// No description provided for @cafeAddFailed.
  ///
  /// In tr, this message translates to:
  /// **'Ekleme başarısız oldu.'**
  String get cafeAddFailed;

  /// No description provided for @cafeEditTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kafe düzenle'**
  String get cafeEditTitle;

  /// No description provided for @cafeEditUnavailable.
  ///
  /// In tr, this message translates to:
  /// **'Supabase ayarlanmadan kafe güncellenemez.'**
  String get cafeEditUnavailable;

  /// No description provided for @cafeEditSuccess.
  ///
  /// In tr, this message translates to:
  /// **'Kafe güncellendi.'**
  String get cafeEditSuccess;

  /// No description provided for @cafeEditFailed.
  ///
  /// In tr, this message translates to:
  /// **'Güncelleme başarısız.'**
  String get cafeEditFailed;

  /// No description provided for @reviewsSectionTitle.
  ///
  /// In tr, this message translates to:
  /// **'Uygulama yorumları'**
  String get reviewsSectionTitle;

  /// No description provided for @reviewsWriteAction.
  ///
  /// In tr, this message translates to:
  /// **'Yorum yaz'**
  String get reviewsWriteAction;

  /// No description provided for @reviewsEditAction.
  ///
  /// In tr, this message translates to:
  /// **'Yorumu düzenle'**
  String get reviewsEditAction;

  /// No description provided for @reviewsSignInAction.
  ///
  /// In tr, this message translates to:
  /// **'Yorum için giriş yap'**
  String get reviewsSignInAction;

  /// No description provided for @reviewsEmptyState.
  ///
  /// In tr, this message translates to:
  /// **'Henüz uygulama yorumu yok. İlk yorumu sen bırak!'**
  String get reviewsEmptyState;

  /// No description provided for @reviewsLoadError.
  ///
  /// In tr, this message translates to:
  /// **'Yorumlar yüklenemedi.'**
  String get reviewsLoadError;

  /// No description provided for @reviewsDeleteTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yorumu sil'**
  String get reviewsDeleteTitle;

  /// No description provided for @reviewsDeleteMessage.
  ///
  /// In tr, this message translates to:
  /// **'Bu yorumu silmek istediğine emin misin?'**
  String get reviewsDeleteMessage;

  /// No description provided for @reviewsDeleteCancel.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get reviewsDeleteCancel;

  /// No description provided for @reviewsDeleteConfirm.
  ///
  /// In tr, this message translates to:
  /// **'Sil'**
  String get reviewsDeleteConfirm;

  /// No description provided for @reviewsDeleteSuccess.
  ///
  /// In tr, this message translates to:
  /// **'Yorum silindi.'**
  String get reviewsDeleteSuccess;

  /// No description provided for @reviewsDeleteError.
  ///
  /// In tr, this message translates to:
  /// **'Yorum silinemedi.'**
  String get reviewsDeleteError;

  /// No description provided for @reviewsFormTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bu kafeyi değerlendir'**
  String get reviewsFormTitle;

  /// No description provided for @reviewsFormUpdateTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yorumunu güncelle'**
  String get reviewsFormUpdateTitle;

  /// No description provided for @reviewsFormRatingHint.
  ///
  /// In tr, this message translates to:
  /// **'Devam etmek için bir puan seç.'**
  String get reviewsFormRatingHint;

  /// No description provided for @reviewsFormCommentLabel.
  ///
  /// In tr, this message translates to:
  /// **'Yorum (isteğe bağlı)'**
  String get reviewsFormCommentLabel;

  /// No description provided for @reviewsFormCommentHint.
  ///
  /// In tr, this message translates to:
  /// **'İstersen neleri beğendiğini veya beğenmediğini yaz.'**
  String get reviewsFormCommentHint;

  /// No description provided for @reviewsFormCommentHelper.
  ///
  /// In tr, this message translates to:
  /// **'Yorum zorunlu değil. Yalnızca puan vererek de gönderebilirsin.'**
  String get reviewsFormCommentHelper;

  /// No description provided for @reviewsFormSubmit.
  ///
  /// In tr, this message translates to:
  /// **'Yorumu gönder'**
  String get reviewsFormSubmit;

  /// No description provided for @reviewsFormUpdate.
  ///
  /// In tr, this message translates to:
  /// **'Yorumu güncelle'**
  String get reviewsFormUpdate;

  /// No description provided for @reviewsFormSubmitting.
  ///
  /// In tr, this message translates to:
  /// **'Gönderiliyor...'**
  String get reviewsFormSubmitting;

  /// No description provided for @reviewsFormUpdating.
  ///
  /// In tr, this message translates to:
  /// **'Güncelleniyor...'**
  String get reviewsFormUpdating;

  /// No description provided for @reviewsSubmitSuccess.
  ///
  /// In tr, this message translates to:
  /// **'Yorumun gönderildi.'**
  String get reviewsSubmitSuccess;

  /// No description provided for @reviewsUpdateSuccess.
  ///
  /// In tr, this message translates to:
  /// **'Yorumun güncellendi.'**
  String get reviewsUpdateSuccess;

  /// No description provided for @reviewsRefreshWarning.
  ///
  /// In tr, this message translates to:
  /// **'Yorumun kaydedildi ama yorum listesi henüz yenilenemedi.'**
  String get reviewsRefreshWarning;

  /// No description provided for @reviewsAuthRequired.
  ///
  /// In tr, this message translates to:
  /// **'Yorum göndermeden önce giriş yapman gerekiyor.'**
  String get reviewsAuthRequired;

  /// No description provided for @reviewsRatingRequired.
  ///
  /// In tr, this message translates to:
  /// **'Göndermeden önce bir puan seç.'**
  String get reviewsRatingRequired;

  /// No description provided for @reviewsValidationError.
  ///
  /// In tr, this message translates to:
  /// **'Yorum doğrulanamadı.'**
  String get reviewsValidationError;

  /// No description provided for @reviewsConflictError.
  ///
  /// In tr, this message translates to:
  /// **'Bu kafe için zaten bir yorumun var.'**
  String get reviewsConflictError;

  /// No description provided for @reviewsUnavailable.
  ///
  /// In tr, this message translates to:
  /// **'Yorum servisi şu anda kullanılamıyor.'**
  String get reviewsUnavailable;

  /// No description provided for @placeholderNotImplemented.
  ///
  /// In tr, this message translates to:
  /// **'Bu ekran henüz hazır değil.'**
  String get placeholderNotImplemented;

  /// No description provided for @errorCafeListLoadFailed.
  ///
  /// In tr, this message translates to:
  /// **'Kafe listesi yüklenemedi.'**
  String get errorCafeListLoadFailed;

  /// No description provided for @errorCafeDetailLoadFailed.
  ///
  /// In tr, this message translates to:
  /// **'Kafe bilgileri yüklenemedi.'**
  String get errorCafeDetailLoadFailed;

  /// No description provided for @errorCafeUpdateFailed.
  ///
  /// In tr, this message translates to:
  /// **'Kafe güncellenemedi.'**
  String get errorCafeUpdateFailed;

  /// No description provided for @errorCafeAddFailed.
  ///
  /// In tr, this message translates to:
  /// **'Kafe eklenemedi.'**
  String get errorCafeAddFailed;

  /// No description provided for @errorCafeNameRequired.
  ///
  /// In tr, this message translates to:
  /// **'Kafe adı gereklidir.'**
  String get errorCafeNameRequired;

  /// No description provided for @errorCafeNameInvalid.
  ///
  /// In tr, this message translates to:
  /// **'Kafe adı geçersiz.'**
  String get errorCafeNameInvalid;

  /// No description provided for @errorNeighborhoodInvalid.
  ///
  /// In tr, this message translates to:
  /// **'Mahalle bilgisi geçersiz.'**
  String get errorNeighborhoodInvalid;

  /// No description provided for @errorAddressInvalid.
  ///
  /// In tr, this message translates to:
  /// **'Adres bilgisi geçersiz.'**
  String get errorAddressInvalid;

  /// No description provided for @errorDescriptionInvalid.
  ///
  /// In tr, this message translates to:
  /// **'Açıklama geçersiz.'**
  String get errorDescriptionInvalid;

  /// No description provided for @errorUserListLoadFailed.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı listesi yüklenemedi.'**
  String get errorUserListLoadFailed;

  /// No description provided for @errorRoleChangeFailedNoPermissions.
  ///
  /// In tr, this message translates to:
  /// **'Rol değişikliği uygulanamadı. Yönetici yetkiniz olmayabilir.'**
  String get errorRoleChangeFailedNoPermissions;

  /// No description provided for @errorPermissionDenied.
  ///
  /// In tr, this message translates to:
  /// **'Bu işlem için yetkiniz yok.'**
  String get errorPermissionDenied;

  /// No description provided for @errorRequestTimedOut.
  ///
  /// In tr, this message translates to:
  /// **'İstek zaman aşımına uğradı. Lütfen tekrar deneyin.'**
  String get errorRequestTimedOut;

  /// No description provided for @errorNetworkUnavailable.
  ///
  /// In tr, this message translates to:
  /// **'Ağ hatası nedeniyle işlem tamamlanamadı.'**
  String get errorNetworkUnavailable;

  /// No description provided for @errorDataConflict.
  ///
  /// In tr, this message translates to:
  /// **'İstek mevcut verilerle çakışıyor.'**
  String get errorDataConflict;

  /// No description provided for @errorValidationFailed.
  ///
  /// In tr, this message translates to:
  /// **'Gönderilen bilgiler geçersiz.'**
  String get errorValidationFailed;

  /// No description provided for @errorRecordNotFound.
  ///
  /// In tr, this message translates to:
  /// **'İstenen kayıt bulunamadı.'**
  String get errorRecordNotFound;

  /// No description provided for @errorParseFailed.
  ///
  /// In tr, this message translates to:
  /// **'Sunucudan beklenmeyen veri alındı.'**
  String get errorParseFailed;

  /// No description provided for @errorServiceUnavailable.
  ///
  /// In tr, this message translates to:
  /// **'Bu hizmet şu anda kullanılamıyor.'**
  String get errorServiceUnavailable;

  /// No description provided for @errorAuthInvalidCredentials.
  ///
  /// In tr, this message translates to:
  /// **'E-posta, kullanıcı adı veya şifre hatalı.'**
  String get errorAuthInvalidCredentials;

  /// No description provided for @errorAuthRateLimited.
  ///
  /// In tr, this message translates to:
  /// **'Çok fazla deneme var. Lütfen biraz bekleyip tekrar deneyin.'**
  String get errorAuthRateLimited;

  /// No description provided for @errorAuthEmailRegistered.
  ///
  /// In tr, this message translates to:
  /// **'Bu e-posta adresi zaten kayıtlı.'**
  String get errorAuthEmailRegistered;

  /// No description provided for @errorAuthPasswordResetFailed.
  ///
  /// In tr, this message translates to:
  /// **'Şifre sıfırlama şu anda başlatılamadı.'**
  String get errorAuthPasswordResetFailed;

  /// No description provided for @errorUsernameInvalid.
  ///
  /// In tr, this message translates to:
  /// **'Bu kullanıcı adı geçersiz.'**
  String get errorUsernameInvalid;

  /// No description provided for @errorUsernameTaken.
  ///
  /// In tr, this message translates to:
  /// **'Bu kullanıcı adı zaten alınmış.'**
  String get errorUsernameTaken;

  /// No description provided for @errorProfileUpdateFailed.
  ///
  /// In tr, this message translates to:
  /// **'Profil güncellenemedi.'**
  String get errorProfileUpdateFailed;

  /// No description provided for @errorAvatarEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Boş fotoğraf yüklenemez.'**
  String get errorAvatarEmpty;

  /// No description provided for @errorAvatarUploadFailed.
  ///
  /// In tr, this message translates to:
  /// **'Profil fotoğrafı yüklenemedi.'**
  String get errorAvatarUploadFailed;

  /// No description provided for @errorProfileLoadFailed.
  ///
  /// In tr, this message translates to:
  /// **'Profil yüklenemedi.'**
  String get errorProfileLoadFailed;

  /// No description provided for @errorReviewSubmitFailed.
  ///
  /// In tr, this message translates to:
  /// **'Yorum gönderilemedi.'**
  String get errorReviewSubmitFailed;

  /// No description provided for @errorReviewRatingOutOfRange.
  ///
  /// In tr, this message translates to:
  /// **'Lütfen 1 ile 5 arasında bir puan seçin.'**
  String get errorReviewRatingOutOfRange;

  /// No description provided for @errorReviewProfanityBlocked.
  ///
  /// In tr, this message translates to:
  /// **'Lütfen yorumlarda saygılı olun ve küfür kullanmayın.'**
  String get errorReviewProfanityBlocked;

  /// No description provided for @errorReviewTextTooLong.
  ///
  /// In tr, this message translates to:
  /// **'Yorum metni 2000 karakterden uzun olamaz.'**
  String get errorReviewTextTooLong;

  /// No description provided for @errorReviewDuplicateText.
  ///
  /// In tr, this message translates to:
  /// **'Bu kafe için aynı yorum metnini zaten gönderdiniz.'**
  String get errorReviewDuplicateText;

  /// No description provided for @errorReviewSubmissionRateLimited.
  ///
  /// In tr, this message translates to:
  /// **'Yeni bir yorum göndermeden önce 30 saniye bekleyin.'**
  String get errorReviewSubmissionRateLimited;

  /// No description provided for @errorReviewNotOwner.
  ///
  /// In tr, this message translates to:
  /// **'Yalnızca kendi yorumunuzu değiştirebilirsiniz.'**
  String get errorReviewNotOwner;

  /// No description provided for @errorReviewProfileMissing.
  ///
  /// In tr, this message translates to:
  /// **'Bu yorum için profiliniz bulunamadı.'**
  String get errorReviewProfileMissing;

  /// No description provided for @errorReviewFieldMissing.
  ///
  /// In tr, this message translates to:
  /// **'Zorunlu bir yorum alanı eksikti.'**
  String get errorReviewFieldMissing;
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
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
