import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../constants/app_constants.dart';

class AdService {
  // Singleton pattern
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  static const String _testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;

  String get testBannerAdUnitId => _testBannerAdUnitId;
  String get testInterstitialAdUnitId => _testInterstitialAdUnitId;

  // Initialize the AdMob SDK
  Future<void> initialize() async {
    if (kIsWeb) return; // Skip initialization on web
    
    await MobileAds.instance.initialize();
  }

  // Get banner ad unit ID based on platform
  String get bannerAdUnitId {
    if (kIsWeb) return '';
    
    if (Platform.isAndroid) {
      return AppConstants.bannerAdUnitIdAndroid;
    } else if (Platform.isIOS) {
      return AppConstants.bannerAdUnitIdiOS;
    }
    
    return '';
  }

  // Get interstitial ad unit ID based on platform
  String get interstitialAdUnitId {
    if (kIsWeb) return '';
    
    if (Platform.isAndroid) {
      return AppConstants.interstitialAdUnitIdAndroid;
    } else if (Platform.isIOS) {
      return AppConstants.interstitialAdUnitIdiOS;
    }
    
    return '';
  }

  // Load a banner ad
  BannerAd loadBannerAd() {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('Banner ad loaded successfully');
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Banner ad failed to load: $error');
        },
      ),
    )..load();
  }

  // Load an interstitial ad
  void loadInterstitialAd() {
    if (kIsWeb) return;
    
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
          debugPrint('Interstitial ad loaded successfully');
          
          // Add listener for ad closed event
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              _isInterstitialAdReady = false;
              ad.dispose();
              loadInterstitialAd(); // Load the next ad
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              _isInterstitialAdReady = false;
              ad.dispose();
              loadInterstitialAd(); // Try to load another ad
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isInterstitialAdReady = false;
          debugPrint('Interstitial ad failed to load: $error');
        },
      ),
    );
  }

  // Show the interstitial ad if it's ready
  void showInterstitialAd() {
    if (_isInterstitialAdReady && _interstitialAd != null) {
      _interstitialAd!.show();
    } else {
      debugPrint('Interstitial ad not ready yet');
      // Reload the ad for next time
      loadInterstitialAd();
    }
  }

  // Show interstitial ad only for non-premium users
  void showInterstitialAdIfNotPremium(bool isPremium) {
    if (!isPremium) {
      showInterstitialAd();
    }
  }

  // Dispose of any ads when done
  void dispose() {
    _interstitialAd?.dispose();
  }
} 