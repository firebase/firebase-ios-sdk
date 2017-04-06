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
  #if __has_include(<Firebase/FirebaseCore.h>)
    #import <Firebase/FirebaseCore.h>
  #endif

  #if __has_include(<FirebaseAnalytics/FirebaseAnalytics.h>)
    #import <FirebaseAnalytics/FirebaseAnalytics.h>
  #endif

  #if __has_include(<FirebaseAppIndexing/FirebaseAppIndexing.h>)
    #import <FirebaseAppIndexing/FirebaseAppIndexing.h>
  #endif

  #if __has_include(<Firebase/FirebaseAuth.h>)
    #import <Firebase/FirebaseAuth.h>
  #endif

  #if __has_include(<FirebaseCrash/FirebaseCrash.h>)
    #import <FirebaseCrash/FirebaseCrash.h>
  #endif

  #if __has_include(<Firebase/FirebaseDatabase.h>)
    #import <Firebase/FirebaseDatabase.h>
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

  #if __has_include(<Firebase/FirebaseMessaging.h>)
    #import <Firebase/FirebaseMessaging.h>
  #endif

  #if __has_include(<FirebaseRemoteConfig/FirebaseRemoteConfig.h>)
    #import <FirebaseRemoteConfig/FirebaseRemoteConfig.h>
  #endif

  #if __has_include(<Firebase/FirebaseStorage.h>)
    #import <Firebase/FirebaseStorage.h>
  #endif

  #if __has_include(<GoogleMobileAds/GoogleMobileAds.h>)
    #import <GoogleMobileAds/GoogleMobileAds.h>
  #endif

#endif  // defined(__has_include)
