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
#import "FirebasePerformance/Sources/AppActivity/FPRScreenTraceTracker+Private.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "FirebasePerformance/Sources/Common/FPRDiagnostics.h"

NSString *const kFPRPrefixForScreenTraceName = @"_st_";
NSString *const kFPRFrozenFrameCounterName = @"_fr_fzn";
NSString *const kFPRSlowFrameCounterName = @"_fr_slo";
NSString *const kFPRTotalFramesCounterName = @"_fr_tot";

// Note: This was previously 60 FPS, but that resulted in 90% +  of all frames collected to be
// flagged as slow frames, and so the threshold for iOS is being changed to 59 FPS.
// TODO(b/73498642): Make these configurable.
CFTimeInterval const kFPRSlowFrameThreshold = 1.0 / 59.0;  // Anything less than 59 FPS is slow.
CFTimeInterval const kFPRFrozenFrameThreshold = 700.0 / 1000.0;

/** Constant that indicates an invalid time. */
CFAbsoluteTime const kFPRInvalidTime = -1.0;

/** Returns the class name without the prefixed module name present in Swift classes
 * (e.g. MyModule.MyViewController -> MyViewController).
 */
static NSString *FPRUnprefixedClassName(Class theClass) {
  NSString *className = NSStringFromClass(theClass);
  NSRange periodRange = [className rangeOfString:@"." options:NSBackwardsSearch];
  if (periodRange.location == NSNotFound) {
    return className;
  }
  return periodRange.location < className.length - 1
             ? [className substringFromIndex:periodRange.location + 1]
             : className;
}

/** Returns the name for the screen trace for a given UIViewController. It does the following:
 *  - Removes module name from swift classes - (e.g. MyModule.MyViewController -> MyViewController)
 *  - Prepends "_st_" to the class name
 *  - Truncates the length if it exceeds the maximum trace length.
 *
 *  @param viewController The view controller whose screen trace name we want. Cannot be nil.
 *  @return An NSString containing the trace name, or a string containing an error if the
 *      class was nil.
 */
static NSString *FPRScreenTraceNameForViewController(UIViewController *viewController) {
  NSString *unprefixedClassName = FPRUnprefixedClassName([viewController class]);
  if (unprefixedClassName.length != 0) {
    NSString *traceName =
        [NSString stringWithFormat:@"%@%@", kFPRPrefixForScreenTraceName, unprefixedClassName];
    return traceName.length > kFPRMaxNameLength ? [traceName substringToIndex:kFPRMaxNameLength]
                                                : traceName;
  } else {
    // This is unlikely, but might happen if there's a regression on iOS where the class name
    // returned for a non-nil class is nil or empty.
    return @"_st_ERROR_NIL_CLASS_NAME";
  }
}

@implementation FPRScreenTraceTracker {
  /** Instance variable storing the total frames observed so far. */
  atomic_int_fast64_t _totalFramesCount;

  /** Instance variable storing the slow frames observed so far. */
  atomic_int_fast64_t _slowFramesCount;

  /** Instance variable storing the frozen frames observed so far. */
  atomic_int_fast64_t _frozenFramesCount;
}

@dynamic totalFramesCount;
@dynamic frozenFramesCount;
@dynamic slowFramesCount;

+ (instancetype)sharedInstance {
  static FPRScreenTraceTracker *instance;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[self alloc] init];
  });
  return instance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    // Weakly retain viewController, use pointer hashing.
    NSMapTableOptions keyOptions = NSMapTableWeakMemory | NSMapTableObjectPointerPersonality;
    // Strongly retain the FIRTrace.
    NSMapTableOptions valueOptions = NSMapTableStrongMemory;
    _activeScreenTraces = [NSMapTable mapTableWithKeyOptions:keyOptions valueOptions:valueOptions];

    _previouslyVisibleViewControllers = nil;  // Will be set when there is data.
    _screenTraceTrackerSerialQueue =
        dispatch_queue_create("com.google.FPRScreenTraceTracker", DISPATCH_QUEUE_SERIAL);
    _screenTraceTrackerDispatchGroup = dispatch_group_create();

    atomic_store_explicit(&_totalFramesCount, 0, memory_order_relaxed);
    atomic_store_explicit(&_frozenFramesCount, 0, memory_order_relaxed);
    atomic_store_explicit(&_slowFramesCount, 0, memory_order_relaxed);
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkStep)];
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];

    // We don't receive background and foreground events from analytics and so we have to listen to
    // them ourselves.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidBecomeActiveNotification:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:[UIApplication sharedApplication]];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appWillResignActiveNotification:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:[UIApplication sharedApplication]];
  }
  return self;
}

- (void)dealloc {
  [_displayLink invalidate];

  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:UIApplicationDidBecomeActiveNotification
                                                object:[UIApplication sharedApplication]];
  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:UIApplicationWillResignActiveNotification
                                                object:[UIApplication sharedApplication]];
}

- (void)appDidBecomeActiveNotification:(NSNotification *)notification {
  // To get the most accurate numbers of total, frozen and slow frames, we need to capture them as
  // soon as we're notified of an event.
  int64_t currentTotalFrames = atomic_load_explicit(&_totalFramesCount, memory_order_relaxed);
  int64_t currentFrozenFrames = atomic_load_explicit(&_frozenFramesCount, memory_order_relaxed);
  int64_t currentSlowFrames = atomic_load_explicit(&_slowFramesCount, memory_order_relaxed);

  dispatch_group_async(self.screenTraceTrackerDispatchGroup, self.screenTraceTrackerSerialQueue, ^{
    for (id viewController in self.previouslyVisibleViewControllers) {
      [self startScreenTraceForViewController:viewController
                           currentTotalFrames:currentTotalFrames
                          currentFrozenFrames:currentFrozenFrames
                            currentSlowFrames:currentSlowFrames];
    }
    self.previouslyVisibleViewControllers = nil;
  });
}

- (void)appWillResignActiveNotification:(NSNotification *)notification {
  // To get the most accurate numbers of total, frozen and slow frames, we need to capture them as
  // soon as we're notified of an event.
  int64_t currentTotalFrames = atomic_load_explicit(&_totalFramesCount, memory_order_relaxed);
  int64_t currentFrozenFrames = atomic_load_explicit(&_frozenFramesCount, memory_order_relaxed);
  int64_t currentSlowFrames = atomic_load_explicit(&_slowFramesCount, memory_order_relaxed);

  dispatch_group_async(self.screenTraceTrackerDispatchGroup, self.screenTraceTrackerSerialQueue, ^{
    self.previouslyVisibleViewControllers = [NSPointerArray weakObjectsPointerArray];
    id visibleViewControllersEnumerator = [self.activeScreenTraces keyEnumerator];
    id visibleViewController = nil;
    while (visibleViewController = [visibleViewControllersEnumerator nextObject]) {
      [self.previouslyVisibleViewControllers addPointer:(__bridge void *)(visibleViewController)];
    }

    for (id visibleViewController in self.previouslyVisibleViewControllers) {
      [self stopScreenTraceForViewController:visibleViewController
                          currentTotalFrames:currentTotalFrames
                         currentFrozenFrames:currentFrozenFrames
                           currentSlowFrames:currentSlowFrames];
    }
  });
}

#pragma mark - Frozen, slow and good frames

- (void)displayLinkStep {
  static CFAbsoluteTime previousTimestamp = kFPRInvalidTime;
  CFAbsoluteTime currentTimestamp = self.displayLink.timestamp;
  RecordFrameType(currentTimestamp, previousTimestamp, &_slowFramesCount, &_frozenFramesCount,
                  &_totalFramesCount);
  previousTimestamp = currentTimestamp;
}

/** This function increments the relevant frame counters based on the current and previous
 *  timestamp provided by the displayLink.
 *
 *  @param currentTimestamp The current timestamp of the displayLink.
 *  @param previousTimestamp The previous timestamp of the displayLink.
 *  @param slowFramesCounter The value of the slowFramesCount before this function was called.
 *  @param frozenFramesCounter The value of the frozenFramesCount before this function was called.
 *  @param totalFramesCounter The value of the totalFramesCount before this function was called.
 */
FOUNDATION_STATIC_INLINE
void RecordFrameType(CFAbsoluteTime currentTimestamp,
                     CFAbsoluteTime previousTimestamp,
                     atomic_int_fast64_t *slowFramesCounter,
                     atomic_int_fast64_t *frozenFramesCounter,
                     atomic_int_fast64_t *totalFramesCounter) {
  CFTimeInterval frameDuration = currentTimestamp - previousTimestamp;
  if (previousTimestamp == kFPRInvalidTime) {
    return;
  }
  if (frameDuration > kFPRSlowFrameThreshold) {
    atomic_fetch_add_explicit(slowFramesCounter, 1, memory_order_relaxed);
  }
  if (frameDuration > kFPRFrozenFrameThreshold) {
    atomic_fetch_add_explicit(frozenFramesCounter, 1, memory_order_relaxed);
  }
  atomic_fetch_add_explicit(totalFramesCounter, 1, memory_order_relaxed);
}

#pragma mark - Helper methods

/** Starts a screen trace for the given UIViewController instance if it doesn't exist. This method
 *  does NOT ensure thread safety - the caller is responsible for making sure that this is invoked
 *  in a thread safe manner.
 *
 *  @param viewController The UIViewController instance for which the trace is to be started.
 *  @param currentTotalFrames The value of the totalFramesCount before this method was called.
 *  @param currentFrozenFrames The value of the frozenFramesCount before this method was called.
 *  @param currentSlowFrames The value of the slowFramesCount before this method was called.
 */
- (void)startScreenTraceForViewController:(UIViewController *)viewController
                       currentTotalFrames:(int64_t)currentTotalFrames
                      currentFrozenFrames:(int64_t)currentFrozenFrames
                        currentSlowFrames:(int64_t)currentSlowFrames {
  if (![self shouldCreateScreenTraceForViewController:viewController]) {
    return;
  }

  // If there's a trace for this viewController, don't do anything.
  if (![self.activeScreenTraces objectForKey:viewController]) {
    NSString *traceName = FPRScreenTraceNameForViewController(viewController);
    FIRTrace *newTrace = [[FIRTrace alloc] initInternalTraceWithName:traceName];
    [newTrace start];
    [newTrace setIntValue:currentTotalFrames forMetric:kFPRTotalFramesCounterName];
    [newTrace setIntValue:currentFrozenFrames forMetric:kFPRFrozenFrameCounterName];
    [newTrace setIntValue:currentSlowFrames forMetric:kFPRSlowFrameCounterName];
    [self.activeScreenTraces setObject:newTrace forKey:viewController];
  }
}

/** Stops a screen trace for the given UIViewController instance if it exist. This method does NOT
 *  ensure thread safety - the caller is responsible for making sure that this is invoked in a
 *  thread safe manner.
 *
 *  @param viewController The UIViewController instance for which the trace is to be stopped.
 *  @param currentTotalFrames The value of the totalFramesCount before this method was called.
 *  @param currentFrozenFrames The value of the frozenFramesCount before this method was called.
 *  @param currentSlowFrames The value of the slowFramesCount before this method was called.
 */
- (void)stopScreenTraceForViewController:(UIViewController *)viewController
                      currentTotalFrames:(int64_t)currentTotalFrames
                     currentFrozenFrames:(int64_t)currentFrozenFrames
                       currentSlowFrames:(int64_t)currentSlowFrames {
  FIRTrace *previousScreenTrace = [self.activeScreenTraces objectForKey:viewController];

  // Get a diff between the counters now and what they were at trace start.
  int64_t actualTotalFrames =
      currentTotalFrames - [previousScreenTrace valueForIntMetric:kFPRTotalFramesCounterName];
  int64_t actualFrozenFrames =
      currentFrozenFrames - [previousScreenTrace valueForIntMetric:kFPRFrozenFrameCounterName];
  int64_t actualSlowFrames =
      currentSlowFrames - [previousScreenTrace valueForIntMetric:kFPRSlowFrameCounterName];

  // Update the values in the trace.
  if (actualTotalFrames != 0) {
    [previousScreenTrace setIntValue:actualTotalFrames forMetric:kFPRTotalFramesCounterName];
  } else {
    [previousScreenTrace deleteMetric:kFPRTotalFramesCounterName];
  }

  if (actualFrozenFrames != 0) {
    [previousScreenTrace setIntValue:actualFrozenFrames forMetric:kFPRFrozenFrameCounterName];
  } else {
    [previousScreenTrace deleteMetric:kFPRFrozenFrameCounterName];
  }

  if (actualSlowFrames != 0) {
    [previousScreenTrace setIntValue:actualSlowFrames forMetric:kFPRSlowFrameCounterName];
  } else {
    [previousScreenTrace deleteMetric:kFPRSlowFrameCounterName];
  }

  if (previousScreenTrace.numberOfCounters > 0) {
    [previousScreenTrace stop];
  } else {
    // The trace did not collect any data. Don't log it.
    [previousScreenTrace cancel];
  }
  [self.activeScreenTraces removeObjectForKey:viewController];
}

#pragma mark - Filtering for screen traces

/** Determines whether to create a screen trace for the given UIViewController instance.
 *
 *  @param viewController The UIViewController instance.
 *  @return YES if a screen trace should be created for the given UIViewController instance,
        NO otherwise.
 */
- (BOOL)shouldCreateScreenTraceForViewController:(UIViewController *)viewController {
  if (viewController == nil) {
    return NO;
  }

  // Ignore non-main bundle view controllers whose class or superclass is an internal iOS view
  // controller. This is borrowed from the logic for tracking screens in Firebase Analytics.
  NSBundle *bundle = [NSBundle bundleForClass:[viewController class]];
  if (bundle != [NSBundle mainBundle]) {
    NSString *className = FPRUnprefixedClassName([viewController class]);
    if ([className hasPrefix:@"_"]) {
      return NO;
    }
    NSString *superClassName = FPRUnprefixedClassName([viewController superclass]);
    if ([superClassName hasPrefix:@"_"]) {
      return NO;
    }
  }

  // We are not creating screen traces for these view controllers because they're container view
  // controllers. They always have a child view controller which will provide better context for a
  // screen trace. We are however capturing traces if a developer subclasses these as there may be
  // some context. Special case: We are not capturing screen traces for any input view
  // controllers.
  return !([viewController isMemberOfClass:[UINavigationController class]] ||
           [viewController isMemberOfClass:[UITabBarController class]] ||
           [viewController isMemberOfClass:[UISplitViewController class]] ||
           [viewController isMemberOfClass:[UIPageViewController class]] ||
           [viewController isKindOfClass:[UIInputViewController class]]);
}

#pragma mark - Screen Traces swizzling hooks

- (void)viewControllerDidAppear:(UIViewController *)viewController {
  // To get the most accurate numbers of total, frozen and slow frames, we need to capture them as
  // soon as we're notified of an event.
  int64_t currentTotalFrames = atomic_load_explicit(&_totalFramesCount, memory_order_relaxed);
  int64_t currentFrozenFrames = atomic_load_explicit(&_frozenFramesCount, memory_order_relaxed);
  int64_t currentSlowFrames = atomic_load_explicit(&_slowFramesCount, memory_order_relaxed);

  dispatch_sync(self.screenTraceTrackerSerialQueue, ^{
    [self startScreenTraceForViewController:viewController
                         currentTotalFrames:currentTotalFrames
                        currentFrozenFrames:currentFrozenFrames
                          currentSlowFrames:currentSlowFrames];
  });
}

- (void)viewControllerDidDisappear:(id)viewController {
  // To get the most accurate numbers of total, frozen and slow frames, we need to capture them as
  // soon as we're notified of an event.
  int64_t currentTotalFrames = atomic_load_explicit(&_totalFramesCount, memory_order_relaxed);
  int64_t currentFrozenFrames = atomic_load_explicit(&_frozenFramesCount, memory_order_relaxed);
  int64_t currentSlowFrames = atomic_load_explicit(&_slowFramesCount, memory_order_relaxed);

  dispatch_sync(self.screenTraceTrackerSerialQueue, ^{
    [self stopScreenTraceForViewController:viewController
                        currentTotalFrames:currentTotalFrames
                       currentFrozenFrames:currentFrozenFrames
                         currentSlowFrames:currentSlowFrames];
  });
}

#pragma mark - Test Helper Methods

- (int_fast64_t)totalFramesCount {
  return atomic_load_explicit(&_totalFramesCount, memory_order_relaxed);
}

- (void)setTotalFramesCount:(int_fast64_t)count {
  atomic_store_explicit(&_totalFramesCount, count, memory_order_relaxed);
}

- (int_fast64_t)slowFramesCount {
  return atomic_load_explicit(&_slowFramesCount, memory_order_relaxed);
}

- (void)setSlowFramesCount:(int_fast64_t)count {
  atomic_store_explicit(&_slowFramesCount, count, memory_order_relaxed);
}

- (int_fast64_t)frozenFramesCount {
  return atomic_load_explicit(&_frozenFramesCount, memory_order_relaxed);
}

- (void)setFrozenFramesCount:(int_fast64_t)count {
  atomic_store_explicit(&_frozenFramesCount, count, memory_order_relaxed);
}

@end
