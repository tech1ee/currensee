#!/bin/bash

echo "📱 Fixing Google Mobile Ads SDK compatibility issues"

# Find the Google Mobile Ads path in pub cache
GOOGLE_ADS_PATH="$HOME/.pub-cache/hosted/pub.dev/google_mobile_ads-5.3.1/ios/Classes"

if [ -d "$GOOGLE_ADS_PATH" ]; then
  echo "Found Google Mobile Ads plugin at: $GOOGLE_ADS_PATH"
  
  # Create backups of files if they don't exist
  for header in "$GOOGLE_ADS_PATH"/*.h; do
    if [ ! -f "${header}.orig" ]; then
      cp "$header" "${header}.orig"
      echo "Created backup of $(basename "$header")"
    fi
  done
  
  for impl in "$GOOGLE_ADS_PATH"/*.m; do
    if [ ! -f "${impl}.orig" ]; then
      cp "$impl" "${impl}.orig"
      echo "Created backup of $(basename "$impl")"
    fi
  done
  
  # Fix the FLTMediationNetworkExtrasProvider deprecated warnings
  # by adding pragmas to suppress warnings in specific files
  
  # Add pragma to FLTGoogleMobileAdsPlugin.m
  if [ -f "$GOOGLE_ADS_PATH/FLTGoogleMobileAdsPlugin.m" ]; then
    sed -i '' '1s/^/#pragma clang diagnostic push\n#pragma clang diagnostic ignored "-Wdeprecated-declarations"\n/' "$GOOGLE_ADS_PATH/FLTGoogleMobileAdsPlugin.m"
    echo '
#pragma clang diagnostic pop' >> "$GOOGLE_ADS_PATH/FLTGoogleMobileAdsPlugin.m"
    echo "Fixed FLTGoogleMobileAdsPlugin.m"
  fi
  
  # Add pragma to FLTGoogleMobileAdsReaderWriter_Internal.m
  if [ -f "$GOOGLE_ADS_PATH/FLTGoogleMobileAdsReaderWriter_Internal.m" ]; then
    sed -i '' '1s/^/#pragma clang diagnostic push\n#pragma clang diagnostic ignored "-Wdeprecated-declarations"\n/' "$GOOGLE_ADS_PATH/FLTGoogleMobileAdsReaderWriter_Internal.m"
    echo '
#pragma clang diagnostic pop' >> "$GOOGLE_ADS_PATH/FLTGoogleMobileAdsReaderWriter_Internal.m"
    echo "Fixed FLTGoogleMobileAdsReaderWriter_Internal.m"
  fi
  
  # Add pragma to FLTAdInstanceManager_Internal.m
  if [ -f "$GOOGLE_ADS_PATH/FLTAdInstanceManager_Internal.m" ]; then
    sed -i '' '1s/^/#pragma clang diagnostic push\n#pragma clang diagnostic ignored "-Wdeprecated-declarations"\n/' "$GOOGLE_ADS_PATH/FLTAdInstanceManager_Internal.m"
    echo '
#pragma clang diagnostic pop' >> "$GOOGLE_ADS_PATH/FLTAdInstanceManager_Internal.m"
    echo "Fixed FLTAdInstanceManager_Internal.m"
  fi
  
  echo "✅ Google Mobile Ads SDK compatibility fixes applied!"
else
  echo "⚠️ Google Mobile Ads plugin directory not found at: $GOOGLE_ADS_PATH"
  echo "Make sure you have run 'flutter pub get' to download the packages."
fi 