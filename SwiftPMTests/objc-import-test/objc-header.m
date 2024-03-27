// Copyright 2020 Google LLC
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

#import "Firebase.h"
#import "FirebaseABTesting/FirebaseABTesting.h"
#import "FirebaseAppCheck/FirebaseAppCheck.h"
#if TARGET_OS_IOS && !TARGET_OS_MACCATALYST
#import "FirebaseAppDistribution/FirebaseAppDistribution.h"
#endif
#import "FirebaseCore/FirebaseCore.h"
#import "FirebaseCrashlytics/FirebaseCrashlytics.h"
#import "FirebaseDatabase/FirebaseDatabase.h"
#import "FirebaseDynamicLinks/FirebaseDynamicLinks.h"
#import "FirebaseFirestore/FirebaseFirestore.h"
#import "FirebaseInstallations/FirebaseInstallations.h"
#import "FirebaseMessaging/FirebaseMessaging.h"
#if (TARGET_OS_IOS && !TARGET_OS_MACCATALYST) || TARGET_OS_TV
#import "FirebaseInAppMessaging/FirebaseInAppMessaging.h"
#import "FirebasePerformance/FirebasePerformance.h"
#endif
#import "FirebaseRemoteConfig/FirebaseRemoteConfig.h"

#import <Firebase.h>
#import <FirebaseABTesting/FirebaseABTesting.h>
#import <TargetConditionals.h>
#if TARGET_OS_IOS && !TARGET_OS_MACCATALYST
#import <FirebaseAppDistribution/FirebaseAppDistribution.h>
#endif
#import <FirebaseCore/FirebaseCore.h>
#import <FirebaseCrashlytics/FirebaseCrashlytics.h>
#import <FirebaseDatabase/FirebaseDatabase.h>
#import <FirebaseDynamicLinks/FirebaseDynamicLinks.h>
#import <FirebaseFirestore/FirebaseFirestore.h>
#if TARGET_OS_IOS || TARGET_OS_TV
#import <FirebaseInAppMessaging/FirebaseInAppMessaging.h>
#endif
#import <FirebaseInstallations/FirebaseInstallations.h>
#import <FirebaseMessaging/FirebaseMessaging.h>
#if (TARGET_OS_IOS && !TARGET_OS_MACCATALYST) || TARGET_OS_TV
#import <FirebasePerformance/FirebasePerformance.h>
#endif
#import <FirebaseRemoteConfig/FirebaseRemoteConfig.h>
