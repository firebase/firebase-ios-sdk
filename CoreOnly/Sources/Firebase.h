// Copyright 2019 Google
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "FirebaseCore.h"

#if !defined(__has_include)
  #error "Firebase.h won't import anything if your compiler doesn't support __has_include. Please \
          import the headers individually."
#else
  #if __has_include("FirebaseAnalytics.h")
    #import "FirebaseAnalytics.h"
  #endif

  #if __has_include("FirebaseAuth.h")
    #import "FirebaseAuth.h"
  #endif

  #if __has_include("FirebaseCrashlytics.h")
    #import "FirebaseCrashlytics.h"
  #endif

  #if __has_include("FirebaseDatabase.h")
    #import "FirebaseDatabase.h"
  #endif

  #if __has_include("FirebaseDynamicLinks.h")
    #import "FirebaseDynamicLinks.h"
    #if !__has_include("FirebaseAnalytics.h")
      #ifndef FIREBASE_ANALYTICS_SUPPRESS_WARNING
        #warning "FirebaseAnalytics.framework is not included in your target. Please add \
`Firebase/Analytics` to your Podfile or add FirebaseAnalytics.framework to your project to ensure \
Firebase Dynamic Links works as intended."
      #endif // #ifndef FIREBASE_ANALYTICS_SUPPRESS_WARNING
    #endif
  #endif

  #if __has_include("FirebaseFirestore.h")
    #import "FirebaseFirestore.h"
  #endif

  #if __has_include("FirebaseFunctions.h")
    #import "FirebaseFunctions.h"
  #endif

  #if __has_include("FirebaseInAppMessaging.h")
    #import "FirebaseInAppMessaging.h"
    #if !__has_include("FirebaseAnalytics.h")
      #ifndef FIREBASE_ANALYTICS_SUPPRESS_WARNING
        #warning "FirebaseAnalytics.framework is not included in your target. Please add \
`Firebase/Analytics` to your Podfile or add FirebaseAnalytics.framework to your project to ensure \
Firebase In App Messaging works as intended."
      #endif // #ifndef FIREBASE_ANALYTICS_SUPPRESS_WARNING
    #endif
  #endif

  #if __has_include("FirebaseInstanceID.h")
    #import "FirebaseInstanceID.h"
  #endif

  #if __has_include("FirebaseMessaging.h")
    #import "FirebaseMessaging.h"
      #if !__has_include("FirebaseAnalytics.h")
      #ifndef FIREBASE_ANALYTICS_SUPPRESS_WARNING
        #warning "FirebaseAnalytics.framework is not included in your target. Please add \
`Firebase/Analytics` to your Podfile or add FirebaseAnalytics.framework to your project to ensure \
Firebase Messaging works as intended."
      #endif // #ifndef FIREBASE_ANALYTICS_SUPPRESS_WARNING
    #endif
#endif

  #if __has_include("FirebaseMLCommon.h")
    #import "FirebaseMLCommon.h"
  #endif

  #if __has_include("FirebaseMLModelInterpreter.h")
    #import "FirebaseMLModelInterpreter.h"
  #endif

  #if __has_include("FirebaseMLNLLanguageID.h")
    #import "FirebaseMLNLLanguageID.h"
  #endif

  #if __has_include("FirebaseMLNLSmartReply.h")
    #import "FirebaseMLNLSmartReply.h"
  #endif

  #if __has_include("FirebaseMLNLTranslate.h")
    #import "FirebaseMLNLTranslate.h"
  #endif

  #if __has_include("FirebaseMLNaturalLanguage.h")
    #import "FirebaseMLNaturalLanguage.h"
  #endif

  #if __has_include("FirebaseMLVision.h")
    #import "FirebaseMLVision.h"
  #endif

  #if __has_include("FirebaseMLVisionAutoML.h")
    #import "FirebaseMLVisionAutoML.h"
  #endif

  #if __has_include("FirebaseMLVisionBarcodeModel.h")
    #import "FirebaseMLVisionBarcodeModel.h"
  #endif

  #if __has_include("FirebaseMLVisionFaceModel.h")
    #import "FirebaseMLVisionFaceModel.h"
  #endif

  #if __has_include("FirebaseMLVisionLabelModel.h")
    #import "FirebaseMLVisionLabelModel.h"
  #endif

  #if __has_include("FirebaseMLVisionObjectDetection.h")
    #import "FirebaseMLVisionObjectDetection.h"
  #endif

  #if __has_include("FirebaseMLVisionTextModel.h")
    #import "FirebaseMLVisionTextModel.h"
  #endif

  #if __has_include("FirebasePerformance.h")
    #import "FirebasePerformance.h"
    #if !__has_include("FirebaseAnalytics.h")
      #ifndef FIREBASE_ANALYTICS_SUPPRESS_WARNING
        #warning "FirebaseAnalytics.framework is not included in your target. Please add \
`Firebase/Analytics` to your Podfile or add FirebaseAnalytics.framework to your project to ensure \
Firebase Performance works as intended."
      #endif // #ifndef FIREBASE_ANALYTICS_SUPPRESS_WARNING
    #endif
  #endif

  #if __has_include("FirebaseRemoteConfig.h")
    #import "FirebaseRemoteConfig.h"
    #if !__has_include("FirebaseAnalytics.h")
      #ifndef FIREBASE_ANALYTICS_SUPPRESS_WARNING
        #warning "FirebaseAnalytics.framework is not included in your target. Please add \
`Firebase/Analytics` to your Podfile or add FirebaseAnalytics.framework to your project to ensure \
Firebase Remote Config works as intended."
      #endif // #ifndef FIREBASE_ANALYTICS_SUPPRESS_WARNING
    #endif
  #endif

  #if __has_include("FirebaseStorage.h")
    #import "FirebaseStorage.h"
  #endif

  #if __has_include("GoogleMobileAds.h")
    #import "GoogleMobileAds.h"
  #endif

  #if __has_include("Fabric.h")
    #import "Fabric.h"
  #endif

  #if __has_include("Crashlytics.h")
    #import "Crashlytics.h"
  #endif

#endif  // defined(__has_include)
