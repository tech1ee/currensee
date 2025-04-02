import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';
import '../utils/debug_constants.dart';

class AdBannerWidget extends StatefulWidget {
  final bool isPremium;
  
  const AdBannerWidget({
    Key? key,
    required this.isPremium,
  }) : super(key: key);

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    debugPrint('🧩 Ad Banner initState - isPremium: ${widget.isPremium}');
    if (!widget.isPremium) {
      debugPrint('🧩 User is NOT premium, loading ad...');
      _loadBannerAd();
    } else {
      debugPrint('🧩 User IS premium, skipping ad load');
    }
  }

  @override
  void didUpdateWidget(AdBannerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // If user upgraded to premium, dispose of the ad
    if (widget.isPremium && !oldWidget.isPremium) {
      debugPrint('🧩 User upgraded to premium, disposing ad');
      _disposeAd();
    }
    
    // If user downgraded from premium, load the ad
    if (!widget.isPremium && oldWidget.isPremium) {
      debugPrint('🧩 User downgraded from premium, loading ad');
      _loadBannerAd();
    }
  }

  void _loadBannerAd() {
    try {
      debugPrint('🧩 Starting to load banner ad');
      final adService = AdService();
      final adUnitId = adService.bannerAdUnitId;
      debugPrint('🧩 Using ad unit ID: $adUnitId');
      
      _bannerAd = BannerAd(
        adUnitId: adUnitId,
        size: AdSize.mediumRectangle, // Bigger ad size (300x250)
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            debugPrint('🧩 Banner ad loaded successfully! 🎉');
            setState(() {
              _isAdLoaded = true;
            });
          },
          onAdFailedToLoad: (Ad ad, LoadAdError error) {
            debugPrint('🧩 Banner ad failed to load: ${error.message}');
            debugPrint('🧩 Error code: ${error.code}, domain: ${error.domain}');
            ad.dispose();
            setState(() {
              _bannerAd = null;
            });
          },
        ),
      );

      debugPrint('🧩 Calling load() on banner ad');
      _bannerAd?.load();
    } catch (e) {
      debugPrint('🧩 Error setting up banner ad: $e');
    }
  }

  void _disposeAd() {
    debugPrint('🧩 Disposing banner ad');
    _bannerAd?.dispose();
    _bannerAd = null;
    _isAdLoaded = false;
  }

  @override
  void dispose() {
    _disposeAd();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🧩 Ad Banner build - isPremium: ${widget.isPremium}, isAdLoaded: $_isAdLoaded, hasAd: ${_bannerAd != null}');
    
    if (widget.isPremium) {
      debugPrint('🧩 User is premium, not showing ad');
      return const SizedBox.shrink();
    }
    
    if (!_isAdLoaded || _bannerAd == null) {
      debugPrint('🧩 Ad not loaded yet, showing placeholder');
      return Container(
        width: 300,
        height: 250,
        margin: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('Ad space - loading...'),
      );
    }

    debugPrint('🧩 Showing real ad banner');
    return Container(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      alignment: Alignment.center,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: AdWidget(ad: _bannerAd!),
    );
  }
} 