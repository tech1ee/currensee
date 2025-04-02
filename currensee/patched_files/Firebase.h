// Patched Firebase.h for Crashlytics
#ifndef Firebase_h
#define Firebase_h

#if __has_include(<FirebaseCore/FirebaseCore.h>)
  #import <FirebaseCore/FirebaseCore.h>
#else
  #import "FirebaseCore/FirebaseCore.h"
#endif

#if __has_include(<FirebaseCrashlytics/FirebaseCrashlytics.h>)
  #import <FirebaseCrashlytics/FirebaseCrashlytics.h>
#else
  #import "FirebaseCrashlytics/FirebaseCrashlytics.h"
#endif

#endif /* Firebase_h */
