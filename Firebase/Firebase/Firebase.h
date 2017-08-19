/*
 * Copyright 2017 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#if !defined(__has_include)
  #error "Firebase.h won't import anything if your compiler doesn't support __has_include. Please \
          import the headers individually."
#else
  #if __has_include(<FirebaseCommunity/FirebaseCore.h>)
    #import <FirebaseCommunity/FirebaseCore.h>
  #endif

  #if __has_include(<FirebaseAnalytics/FirebaseAnalytics.h>)
    #import <FirebaseAnalytics/FirebaseAnalytics.h>
  #endif

  #if __has_include(<FirebaseCommunity/FirebaseAuth.h>)
    #import <FirebaseCommunity/FirebaseAuth.h>
  #endif

  #if __has_include(<FirebaseCrash/FirebaseCrash.h>)
    #import <FirebaseCrash/FirebaseCrash.h>
  #endif

  #if __has_include(<FirebaseCommunity/FirebaseDatabase.h>)
    #import <FirebaseCommunity/FirebaseDatabase.h>
  #endif

  #if __has_include(<FirebaseDynamicLinks/FirebaseDynamicLinks.h>)
    #import <FirebaseDynamicLinks/FirebaseDynamicLinks.h>
  #endif

  #if __has_include(<Firebase/FirebaseInstanceID.h>)
    #import <Firebase/FirebaseInstanceID.h>
  #endif

  #if __has_include(<FirebaseInvites/FirebaseInvites.h>)
    #import <FirebaseInvites/FirebaseInvites.h>
  #endif

  #if __has_include(<FirebaseCommunity/FirebaseMessaging.h>)
    #import <FirebaseCommunity/FirebaseMessaging.h>
  #endif

  #if __has_include(<FirebaseRemoteConfig/FirebaseRemoteConfig.h>)
    #import <FirebaseRemoteConfig/FirebaseRemoteConfig.h>
  #endif

  #if __has_include(<FirebaseCommunity/FirebaseStorage.h>)
    #import <FirebaseCommunity/FirebaseStorage.h>
  #endif

  #if __has_include(<GoogleMobileAds/GoogleMobileAds.h>)
    #import <GoogleMobileAds/GoogleMobileAds.h>
  #endif

  #if __has_include(<Fabric/Fabric.h>)
    #import <Fabric/Fabric.h>
  #endif

  #if __has_include(<Crashlytics/Crashlytics.h>)
    #import <Crashlytics/Crashlytics.h>
  #endif

#endif  // defined(__has_include)
