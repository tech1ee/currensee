// Custom Firebase.h header to fix import issues
#ifndef Firebase_h
#define Firebase_h

// Import FirebaseCore directly to avoid circular imports
#if __has_include(<FirebaseCore/FirebaseCore.h>)
  #import <FirebaseCore/FirebaseCore.h>
#endif

// Import FirebaseCrashlytics directly
#if __has_include(<FirebaseCrashlytics/FirebaseCrashlytics.h>)
  #import <FirebaseCrashlytics/FirebaseCrashlytics.h>
#endif

// Import FirebaseAnalytics directly
#if __has_include(<FirebaseAnalytics/FirebaseAnalytics.h>)
  #import <FirebaseAnalytics/FirebaseAnalytics.h>
#endif

#endif /* Firebase_h */ 