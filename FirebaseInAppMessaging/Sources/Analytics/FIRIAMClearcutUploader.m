/*
 * Copyright 2018 Google
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

#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <UIKit/UIKit.h>
#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

#import "FirebaseInAppMessaging/Sources/FIRCore+InAppMessaging.h"
#import "FirebaseInAppMessaging/Sources/Private/Analytics/FIRIAMClearcutUploader.h"
#import "FirebaseInAppMessaging/Sources/Private/Util/FIRIAMTimeFetcher.h"

#import "FirebaseInAppMessaging/Sources/Analytics/FIRIAMClearcutHttpRequestSender.h"
#import "FirebaseInAppMessaging/Sources/Analytics/FIRIAMClearcutLogStorage.h"

// a macro for turning a millisecond value into seconds
#define MILLS_TO_SECONDS(x) (((long)x) / 1000)

@implementation FIRIAMClearcutStrategy
- (instancetype)initWithMinWaitTimeInMills:(NSInteger)minWaitTimeInMills
                        maxWaitTimeInMills:(NSInteger)maxWaitTimeInMills
                 failureBackoffTimeInMills:(NSInteger)failureBackoffTimeInMills
                             batchSendSize:(NSInteger)batchSendSize {
  if (self = [super init]) {
    _minimalWaitTimeInMills = minWaitTimeInMills;
    _maximumWaitTimeInMills = maxWaitTimeInMills;
    _failureBackoffTimeInMills = failureBackoffTimeInMills;
    _batchSendSize = batchSendSize;
  }
  return self;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"min wait time in seconds:%ld;max wait time in seconds:%ld;"
                                     "failure backoff time in seconds:%ld;batch send size:%d",
                                    MILLS_TO_SECONDS(self.minimalWaitTimeInMills),
                                    MILLS_TO_SECONDS(self.maximumWaitTimeInMills),
                                    MILLS_TO_SECONDS(self.failureBackoffTimeInMills),
                                    (int)self.batchSendSize];
}
@end

@interface FIRIAMClearcutUploader () {
  dispatch_queue_t _queue;
  BOOL _nextSendScheduled;
}

@property(readwrite, nonatomic) FIRIAMClearcutHttpRequestSender *requestSender;
@property(nonatomic, assign) int64_t nextValidSendTimeInMills;

@property(nonatomic, readonly) id<FIRIAMTimeFetcher> timeFetcher;
@property(nonatomic, readonly) FIRIAMClearcutLogStorage *logStorage;

@property(nonatomic, readonly) FIRIAMClearcutStrategy *strategy;
@property(nonatomic, readonly) NSUserDefaults *userDefaults;
@end

static NSString *FIRIAM_UserDefaultsKeyForNextValidClearcutUploadTimeInMills =
    @"firebase-iam-next-clearcut-upload-timestamp-in-mills";

/**
 * The high level behavior in this implementation is like this
 *  1 New records always pushed into FIRIAMClearcutLogStorage first.
 *  2 Upload log records in batches.
 *  3 If prior upload was successful, next upload would wait for the time parsed out of the
 *      clearcut response body.
 *  4 If prior upload failed, next upload attempt would wait for failureBackoffTimeInMills defined
 *      in strategy
 *  5 When app
 */

@implementation FIRIAMClearcutUploader

- (instancetype)initWithRequestSender:(FIRIAMClearcutHttpRequestSender *)requestSender
                          timeFetcher:(id<FIRIAMTimeFetcher>)timeFetcher
                           logStorage:(FIRIAMClearcutLogStorage *)logStorage
                        usingStrategy:(FIRIAMClearcutStrategy *)strategy
                    usingUserDefaults:(nullable NSUserDefaults *)userDefaults {
  if (self = [super init]) {
    _nextSendScheduled = NO;
    _timeFetcher = timeFetcher;
    _requestSender = requestSender;
    _logStorage = logStorage;
    _strategy = strategy;
    _queue = dispatch_queue_create("com.google.firebase.inappmessaging.clearcut_upload", NULL);
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(scheduleNextSendFromForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
#if defined(__IPHONE_13_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
    if (@available(iOS 13.0, *)) {
      [[NSNotificationCenter defaultCenter] addObserver:self
                                               selector:@selector(scheduleNextSendFromForeground:)
                                                   name:UISceneWillEnterForegroundNotification
                                                 object:nil];
    }
#endif  // defined(__IPHONE_13_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
    _userDefaults = userDefaults ? userDefaults : [NSUserDefaults standardUserDefaults];
    // it would be 0 if it does not exist, which is equvilent to saying that
    // you can send now
    _nextValidSendTimeInMills = (int64_t)
        [_userDefaults doubleForKey:FIRIAM_UserDefaultsKeyForNextValidClearcutUploadTimeInMills];

    NSArray<FIRIAMClearcutLogRecord *> *availableLogs =
        [logStorage popStillValidRecordsForUpTo:strategy.batchSendSize];
    if (availableLogs.count) {
      [self scheduleNextSend];
    }

    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM260001",
                @"FIRIAMClearcutUploader created with strategy as %@", self.strategy);
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)scheduleNextSendFromForeground:(NSNotification *)notification {
  FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM260010",
              @"App foregrounded, FIRIAMClearcutUploader will seed next send");
  [self scheduleNextSend];
}

- (void)addNewLogRecord:(FIRIAMClearcutLogRecord *)record {
  FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM260002",
              @"New log record sent to clearcut uploader");

  [self.logStorage pushRecords:@[ record ]];
  [self scheduleNextSend];
}

- (void)attemptUploading {
  NSArray<FIRIAMClearcutLogRecord *> *availableLogs =
      [self.logStorage popStillValidRecordsForUpTo:self.strategy.batchSendSize];

  if (availableLogs.count > 0) {
    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM260011", @"Deliver %d clearcut records",
                (int)availableLogs.count);
    [self.requestSender
        sendClearcutHttpRequestForLogs:availableLogs
                        withCompletion:^(BOOL success, BOOL shouldRetryLogs,
                                         int64_t waitTimeInMills) {
                          if (success) {
                            FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM260003",
                                        @"Delivering %d clearcut records was successful",
                                        (int)availableLogs.count);
                            // make sure the effective wait time is between two bounds
                            // defined in strategy
                            waitTimeInMills =
                                MAX(self.strategy.minimalWaitTimeInMills, waitTimeInMills);

                            waitTimeInMills =
                                MIN(waitTimeInMills, self.strategy.maximumWaitTimeInMills);
                          } else {
                            // failed to deliver
                            FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM260004",
                                        @"Failed to attempt the delivery of %d clearcut "
                                        @"records and should-retry for them is %@",
                                        (int)availableLogs.count, shouldRetryLogs ? @"YES" : @"NO");
                            if (shouldRetryLogs) {
                              /**
                               * Note that there is a chance that the app crashes before we can
                               * call pushRecords: on the logStorage below which means we lost
                               * these log records permanently. This is a trade-off between handling
                               * duplicate records on server side vs taking the risk of lossing
                               * data. This implementation picks the latter.
                               */
                              FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM260007",
                                          @"Push failed log records back to storage");
                              [self.logStorage pushRecords:availableLogs];
                            }

                            waitTimeInMills = (int64_t)self.strategy.failureBackoffTimeInMills;
                          }

                          FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM260005",
                                      @"Wait for at least %ld seconds before next upload attempt",
                                      MILLS_TO_SECONDS(waitTimeInMills));

                          self.nextValidSendTimeInMills =
                              (int64_t)[self.timeFetcher currentTimestampInSeconds] * 1000 +
                              waitTimeInMills;

                          // persisted so that it can be recovered next time the app runs
                          [self.userDefaults
                              setDouble:(double)self.nextValidSendTimeInMills
                                 forKey:
                                     FIRIAM_UserDefaultsKeyForNextValidClearcutUploadTimeInMills];

                          @synchronized(self) {
                            self->_nextSendScheduled = NO;
                          }
                          [self scheduleNextSend];
                        }];

  } else {
    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM260007", @"No clearcut records to be uploaded");
    @synchronized(self) {
      _nextSendScheduled = NO;
    }
  }
}

- (void)scheduleNextSend {
  @synchronized(self) {
    if (_nextSendScheduled) {
      return;
    }
  }

  int64_t delayTimeInMills =
      self.nextValidSendTimeInMills - (int64_t)[self.timeFetcher currentTimestampInSeconds] * 1000;

  if (delayTimeInMills <= 0) {
    delayTimeInMills = 0;  // no need to delay since we can send now
  }

  FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM260006",
              @"Next upload attempt scheduled in %d seconds", (int)delayTimeInMills / 1000);

  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delayTimeInMills * (int64_t)NSEC_PER_MSEC),
                 _queue, ^{
                   [self attemptUploading];
                 });
  @synchronized(self) {
    _nextSendScheduled = YES;
  }
}

@end

#endif  // TARGET_OS_IOS
