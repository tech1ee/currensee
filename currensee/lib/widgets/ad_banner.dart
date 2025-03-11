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
      _loadAd();
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
      _loadAd();
    }
  }

  void _loadAd() {
    final adService = AdService();
    
    _bannerAd = adService.loadBannerAd()
      ..load().then((_) {
        setState(() {
          _isAdLoaded = true;
        });
      }).catchError((error) {
        debugPrint('Failed to load banner ad: $error');
        setState(() {
          _isAdLoaded = false;
        });
      });
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
      return const SizedBox.shrink(); // No space taken if premium or ad not loaded
    }
    
    return Container(
      alignment: Alignment.center,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
} 