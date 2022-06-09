// Copyright 2017 Google
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

#import <Foundation/Foundation.h>

#if TARGET_OS_IOS || TARGET_OS_TV
#import <MobileCoreServices/MobileCoreServices.h>
#elif TARGET_OS_OSX || TARGET_OS_WATCH
#import <CoreServices/CoreServices.h>
#endif

#import "FirebaseStorageInternal/Sources/FIRStorageUtils.h"

#import "FirebaseStorageInternal/Sources/FIRStorageConstants_Private.h"
#import "FirebaseStorageInternal/Sources/FIRStorageErrors.h"
#import "FirebaseStorageInternal/Sources/FIRStorageReference_Private.h"
#import "FirebaseStorageInternal/Sources/FIRStorage_Private.h"
#import "FirebaseStorageInternal/Sources/Public/FirebaseStorageInternal/FIRStoragePath.h"

#if SWIFT_PACKAGE
@import GTMSessionFetcherCore;
#else
#import <GTMSessionFetcher/GTMSessionFetcher.h>
#endif

@implementation FIRStorageUtils

+ (NSTimeInterval)computeRetryIntervalFromRetryTime:(NSTimeInterval)retryTime {
  // GTMSessionFetcher's retry starts at 1 second and then doubles every time. We use this
  // information to compute a best-effort estimate of what to translate the user provided retry
  // time into.

  // Note that this is the same as 2 << (log2(retryTime) - 1), but deemed more readable.
  NSTimeInterval lastInterval = 1.0;
  NSTimeInterval sumOfAllIntervals = 1.0;

  while (sumOfAllIntervals < retryTime) {
    lastInterval *= 2;
    sumOfAllIntervals += lastInterval;
  }

  return lastInterval;
}

@end
