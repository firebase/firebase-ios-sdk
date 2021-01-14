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

#import "FirebasePerformance/Sources/AppActivity/FPRScreenTraceTracker.h"

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <stdatomic.h>

#import "FirebasePerformance/Sources/Common/FPRConstants.h"
#import "FirebasePerformance/Sources/Timer/FIRTrace+Internal.h"

@class UIViewController;

NS_ASSUME_NONNULL_BEGIN

/** Prefix string for screen traces. */
FOUNDATION_EXTERN NSString *const kFPRPrefixForScreenTraceName;

/** Counter name for frozen frames. */
FOUNDATION_EXTERN NSString *const kFPRFrozenFrameCounterName;

/** Counter name for slow frames. */
FOUNDATION_EXTERN NSString *const kFPRSlowFrameCounterName;

/** Counter name for total frames. */
FOUNDATION_EXTERN NSString *const kFPRTotalFramesCounterName;

/** Slow frame threshold (for time difference between current and previous frame render time)
 *  in sec.
 */
FOUNDATION_EXTERN CFTimeInterval const kFPRSlowFrameThreshold;

/** Frozen frame threshold (for time difference between current and previous frame render time)
 *  in sec.
 */
FOUNDATION_EXTERN CFTimeInterval const kFPRFrozenFrameThreshold;

@interface FPRScreenTraceTracker ()

/** A map table of that has the viewControllers as the keys and their associated trace as the value.
 *  The key is weakly retained and the value is strongly retained.
 */
@property(nonatomic) NSMapTable<UIViewController *, FIRTrace *> *activeScreenTraces;

/** A list of all UIViewController instances that were visible before app was backgrounded. The
 *  viewControllers are reatined weakly.
 */
@property(nonatomic, nullable) NSPointerArray *previouslyVisibleViewControllers;

/** Serial queue on which all operations that need to be thread safe in this class take place. */
@property(nonatomic) dispatch_queue_t screenTraceTrackerSerialQueue;

/** The display link that provides us with the frame rate data. */
@property(nonatomic) CADisplayLink *displayLink;

/** Dispatch group which allows us to make this class testable. Instead of waiting an arbitrary
 *  amount of time for an asynchronous task to finish before asserting its behavior, we can wait
 *  on this dispatch group to finish executing before testing the behavior of any asynchronous
 *  task. Consequently, all asynchronous tasks in this class should use this dispatch group.
 */
@property(nonatomic) dispatch_group_t screenTraceTrackerDispatchGroup;

/** The frozen frames counter. */
@property(atomic) int_fast64_t frozenFramesCount;

/** The total frames counter. */
@property(atomic) int_fast64_t totalFramesCount;

/** The slow frames counter. */
@property(atomic) int_fast64_t slowFramesCount;

/** Handles the appDidBecomeActive notification. Restores the screen traces that were active before
 *  the app was backgrounded.
 *
 *  @param notification The NSNotification object.
 */
- (void)appDidBecomeActiveNotification:(NSNotification *)notification;

/** Handles the appWillResignActive notification. Saves the names of the screen traces that are
 *  currently active and stops all of them.
 *
 *  @param notification The NSNotification object.
 */
- (void)appWillResignActiveNotification:(NSNotification *)notification;

/** The method that is invoked by the CADisplayLink when a new frame is rendered. */
- (void)displayLinkStep;

/** Tells the screen trace tracker that the given viewController appeared. This should be called
 *  from the main thread.
 *
 * @param viewController The UIViewController instance that appeared.
 */
- (void)viewControllerDidAppear:(UIViewController *)viewController;

/** Tells the screen trace tracker that the given viewController disappeared. This should be called
 *  from the main thread.
 *
 * @param viewController The UIViewController instance that disappeared.
 */
- (void)viewControllerDidDisappear:(id)viewController;

@end

NS_ASSUME_NONNULL_END
