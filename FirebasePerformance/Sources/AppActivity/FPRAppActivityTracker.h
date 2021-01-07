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

#import "FirebasePerformance/Sources/Public/FIRTrace.h"

FOUNDATION_EXTERN NSString *__nonnull const kFPRAppStartTraceName;
FOUNDATION_EXTERN NSString *__nonnull const kFPRAppStartStageNameTimeToUI;
FOUNDATION_EXTERN NSString *__nonnull const kFPRAppStartStageNameTimeToFirstDraw;
FOUNDATION_EXTERN NSString *__nonnull const kFPRAppStartStageNameTimeToUserInteraction;
FOUNDATION_EXTERN NSString *__nonnull const kFPRAppTraceNameForegroundSession;
FOUNDATION_EXTERN NSString *__nonnull const kFPRAppTraceNameBackgroundSession;
FOUNDATION_EXTERN NSString *__nonnull const kFPRAppCounterNameTraceEventsRateLimited;
FOUNDATION_EXTERN NSString *__nonnull const kFPRAppCounterNameNetworkTraceEventsRateLimited;
FOUNDATION_EXTERN NSString *__nonnull const kFPRAppCounterNameTraceNotStopped;

/** Different states of the current application. */
typedef NS_ENUM(NSInteger, FPRApplicationState) {
  FPRApplicationStateUnknown,

  /** Application in foreground. */
  FPRApplicationStateForeground,

  /** Application in background. */
  FPRApplicationStateBackground,
};

/** This class is used to track the app activity and create internal traces to capture the
 *  performance metrics.
 */
@interface FPRAppActivityTracker : NSObject

/** The trace that tracks the currently active session of the app. *Do not stop this trace*. This is
 *  an active trace that needs to be running. Stopping this trace might impact the overall
 *  performance metrics captured for the active session. All other operations can be performed.
 */
@property(nonatomic, nullable, readonly) FIRTrace *activeTrace;

/** Current running state of the application. */
@property(nonatomic, readonly) FPRApplicationState applicationState;

/** Accesses the singleton instance.
 *  @return Reference to the shared object if successful; <code>nil</code> if not.
 */
+ (nullable instancetype)sharedInstance;

- (nullable instancetype)init NS_UNAVAILABLE;

@end
