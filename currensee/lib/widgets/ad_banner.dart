import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';

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
    if (!widget.isPremium) {
      _loadBannerAd();
    }
  }

  @override
  void didUpdateWidget(AdBannerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // If user upgraded to premium, dispose of the ad
    if (widget.isPremium && !oldWidget.isPremium) {
      _disposeAd();
    }
    
    // If user downgraded from premium, load the ad
    if (!widget.isPremium && oldWidget.isPremium) {
      _loadBannerAd();
    }
  }

  void _loadBannerAd() {
    final adService = AdService();
    _bannerAd = BannerAd(
      adUnitId: adService.testBannerAdUnitId,
      size: AdSize.mediumRectangle, // Bigger ad size (300x250)
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          print('Ad failed to load: $error');
          ad.dispose();
        },
      ),
    );

    _bannerAd?.load();
  }

  void _disposeAd() {
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
    if (widget.isPremium || !_isAdLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      alignment: Alignment.center,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: AdWidget(ad: _bannerAd!),
    );
  }
} 