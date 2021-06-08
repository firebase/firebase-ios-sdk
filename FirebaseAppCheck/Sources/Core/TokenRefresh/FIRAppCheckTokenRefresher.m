/*
 * Copyright 2021 Google LLC
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

#import "FirebaseAppCheck/Sources/Core/TokenRefresh/FIRAppCheckTokenRefresher.h"

#import "FirebaseAppCheck/Sources/Core/FIRAppCheckSettings.h"
#import "FirebaseAppCheck/Sources/Core/TokenRefresh/FIRAppCheckTimer.h"
#import "FirebaseAppCheck/Sources/Core/TokenRefresh/FIRAppCheckTokenRefreshResult.h"

NS_ASSUME_NONNULL_BEGIN

static const NSTimeInterval kInitialBackoffTimeInterval = 30;
static const NSTimeInterval kMaximumBackoffTimeInterval = 16 * 60;

static const NSTimeInterval kMinimumAutoRefreshTimeInterval = 60; // 1 min.

/// How much time in advance to auto-refresh token before it's expiration. E.g. 0.5 means that the token will be refreshed half way through it's intended time to live.
static const double kAutoRefreshFraction = 0.5;

@interface FIRAppCheckTokenRefresher ()

@property(nonatomic, readonly) dispatch_queue_t refreshQueue;

@property(nonatomic, readonly) id<FIRAppCheckSettingsProtocol> settings;

@property(nonatomic, readonly) FIRTimerProvider timerProvider;
@property(atomic, nullable) id<FIRAppCheckTimerProtocol> timer;
@property(atomic) NSUInteger retryCount;

/// Initial refresh result to be used when `tokenRefreshHandler` has been sent. 
@property(nonatomic, nullable) FIRAppCheckTokenRefreshResult *initialRefreshResult;
@property(nonatomic, readonly) NSTimeInterval tokenExpirationThreshold;

@end

@implementation FIRAppCheckTokenRefresher

@synthesize tokenRefreshHandler = _tokenRefreshHandler;

- (instancetype)initWithRefreshResult:(FIRAppCheckTokenRefreshResult *)refreshResult
                   tokenExpirationThreshold:(NSTimeInterval)tokenExpirationThreshold
                              timerProvider:(FIRTimerProvider)timerProvider
                                   settings:(id<FIRAppCheckSettingsProtocol>)settings {
  self = [super init];
  if (self) {
    _refreshQueue =
        dispatch_queue_create("com.firebase.FIRAppCheckTokenRefresher", DISPATCH_QUEUE_SERIAL);
    _tokenExpirationThreshold = tokenExpirationThreshold;
    _initialRefreshResult = refreshResult;
    _timerProvider = timerProvider;
    _settings = settings;
  }
  return self;
}

- (instancetype)initWithRefreshResult:(FIRAppCheckTokenRefreshResult *)refreshResult
                   tokenExpirationThreshold:(NSTimeInterval)tokenExpirationThreshold
                                   settings:(id<FIRAppCheckSettingsProtocol>)settings {
  return [self initWithRefreshResult:refreshResult
                  tokenExpirationThreshold:tokenExpirationThreshold
                             timerProvider:[FIRAppCheckTimer timerProvider]
                                  settings:settings];
}

- (void)dealloc {
  [self cancelTimer];
}

- (void)setTokenRefreshHandler:(FIRAppCheckTokenRefreshBlock)tokenRefreshHandler {
  @synchronized(self) {
    _tokenRefreshHandler = tokenRefreshHandler;

    // Check if handler is being set for the first time and if yes then schedule first refresh.
    if (tokenRefreshHandler && self.initialRefreshResult &&
        self.settings.isTokenAutoRefreshEnabled) {
      FIRAppCheckTokenRefreshResult *initialTokenRefreshResult = self.initialRefreshResult;
      self.initialRefreshResult = nil;
      [self scheduleWithTokenRefreshResult:initialTokenRefreshResult];
    }
  }
}

- (FIRAppCheckTokenRefreshBlock)tokenRefreshHandler {
  @synchronized(self) {
    return _tokenRefreshHandler;
  }
}

- (void)updateWithRefreshResult:(FIRAppCheckTokenRefreshResult *)refreshResult {
  if (self.settings.isTokenAutoRefreshEnabled) {
    [self scheduleWithTokenRefreshResult:refreshResult];
  }
}

- (void)refresh {
  if (self.tokenRefreshHandler == nil) {
    return;
  }

  if (!self.settings.isTokenAutoRefreshEnabled) {
    return;
  }

  __auto_type __weak weakSelf = self;
  self.tokenRefreshHandler(^(FIRAppCheckTokenRefreshResult *refreshResult) {
    __auto_type strongSelf = weakSelf;
    [strongSelf tokenRefreshedWithResult:refreshResult];
  });
}

- (void)tokenRefreshedWithResult:(FIRAppCheckTokenRefreshResult *)refreshResult {
  switch (refreshResult.status) {
    case FIRAppCheckTokenRefreshStatusNever:
    case FIRAppCheckTokenRefreshStatusSuccess:
      self.retryCount = 0;
      break;

    case FIRAppCheckTokenRefreshStatusFailure:
      self.retryCount += 1;
      break;
  }

  [self scheduleWithTokenRefreshResult:refreshResult];
}

- (void)scheduleWithTokenRefreshResult:(FIRAppCheckTokenRefreshResult *)refreshResult {
  NSDate *refreshDate = [self nextRefreshDateWithTokenRefreshResult:refreshResult];
  [self scheduleRefreshAtDate:refreshDate];
}

- (void)scheduleRefreshAtDate:(NSDate *)refreshDate {
  [self cancelTimer];

  NSTimeInterval scheduleInSec = [refreshDate timeIntervalSinceNow];

  __auto_type __weak weakSelf = self;
  dispatch_block_t refreshHandler = ^{
    __auto_type strongSelf = weakSelf;
    [strongSelf refresh];
  };

  // Refresh straight away if the refresh time is too close.
  if (scheduleInSec <= 0) {
    dispatch_async(self.refreshQueue, refreshHandler);
    return;
  }

  self.timer = self.timerProvider(refreshDate, self.refreshQueue, refreshHandler);
}

- (void)cancelTimer {
  [self.timer invalidate];
}

#pragma mark - Backoff

- (NSDate *)nextRefreshDateWithTokenRefreshResult:(FIRAppCheckTokenRefreshResult *)refreshResult {
  switch (refreshResult.status) {
    case FIRAppCheckTokenRefreshStatusSuccess: {
      NSTimeInterval timeToLive = [refreshResult.tokenExpirationDate timeIntervalSinceDate:refreshResult.tokenReceivedAtDate];
      timeToLive = MAX(timeToLive, 0);

      // Refresh in 50% of TTL + 5 min.
      NSTimeInterval targetRefreshSinceReceivedDate = timeToLive * kAutoRefreshFraction + 5 * 60;
      NSDate *targetRefreshDate =
      [refreshResult.tokenReceivedAtDate dateByAddingTimeInterval:targetRefreshSinceReceivedDate];

      // Don't schedule later than expiration date.
      NSDate *refreshDate = [targetRefreshDate earlierDate:refreshResult.tokenExpirationDate];

      // Don't schedule an update earlier than in 1 min from now.
      if ([refreshDate timeIntervalSinceNow] < kMinimumAutoRefreshTimeInterval) {
        refreshDate = [NSDate dateWithTimeIntervalSinceNow:kMinimumAutoRefreshTimeInterval];
      }
      return refreshDate;
    }
      break;

    case FIRAppCheckTokenRefreshStatusFailure: {
      // Refresh after a timeout.
      NSTimeInterval backoffTime = [[self class] backoffTimeForRetryCount:self.retryCount];
      return [NSDate dateWithTimeIntervalSinceNow:backoffTime];
    }
      break;

    case FIRAppCheckTokenRefreshStatusNever:
      // Refresh ASAP.
      return [NSDate date];
      break;
  }
}


+ (NSTimeInterval)backoffTimeForRetryCount:(NSInteger)retryCount {
  if (retryCount == 0) {
    // No backoff for the first attempt.
    return 0;
  }

  NSTimeInterval exponentialInterval =
      kInitialBackoffTimeInterval * pow(2, retryCount - 1) + [self randomMilliseconds];
  return MIN(exponentialInterval, kMaximumBackoffTimeInterval);
}

+ (NSTimeInterval)randomMilliseconds {
  int32_t random_millis = ABS(arc4random() % 1000);
  return (double)random_millis * 0.001;
}

@end

NS_ASSUME_NONNULL_END
