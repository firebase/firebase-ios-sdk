/*
 * Copyright 2020 Google LLC
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

#import "GoogleDataTransport/GDTCCTLibrary/Private/GDTCCTUploadOperation.h"

#import <FBLPromises/FBLPromises.h>

#import "GoogleDataTransport/GDTCORLibrary/Internal/GDTCORPlatform.h"
#import "GoogleDataTransport/GDTCORLibrary/Internal/GDTCORRegistrar.h"
#import "GoogleDataTransport/GDTCORLibrary/Internal/GDTCORStorageProtocol.h"
#import "GoogleDataTransport/GDTCORLibrary/Private/GDTCORUploadBatch.h"
#import "GoogleDataTransport/GDTCORLibrary/Public/GoogleDataTransport/GDTCORConsoleLogger.h"
#import "GoogleDataTransport/GDTCORLibrary/Public/GoogleDataTransport/GDTCOREvent.h"

#import <nanopb/pb.h>
#import <nanopb/pb_decode.h>
#import <nanopb/pb_encode.h>

#import "GoogleDataTransport/GDTCCTLibrary/Private/GDTCCTCompressionHelper.h"
#import "GoogleDataTransport/GDTCCTLibrary/Private/GDTCCTNanopbHelpers.h"
#import "GoogleUtilities/Environment/URLSessionPromiseWrapper/GULURLSessionDataResponse.h"
#import "GoogleUtilities/Environment/URLSessionPromiseWrapper/NSURLSession+GULPromises.h"

#import "GoogleDataTransport/GDTCCTLibrary/Protogen/nanopb/cct.nanopb.h"

NS_ASSUME_NONNULL_BEGIN

#ifdef GDTCOR_VERSION
#define STR(x) STR_EXPAND(x)
#define STR_EXPAND(x) #x
static NSString *const kGDTCCTSupportSDKVersion = @STR(GDTCOR_VERSION);
#else
static NSString *const kGDTCCTSupportSDKVersion = @"UNKNOWN";
#endif  // GDTCOR_VERSION

/** */
static NSInteger kWeekday;

typedef void (^GDTCCTUploaderURLTaskCompletion)(NSNumber *batchID,
                                                NSSet<GDTCOREvent *> *_Nullable events,
                                                NSData *_Nullable data,
                                                NSURLResponse *_Nullable response,
                                                NSError *_Nullable error);

typedef void (^GDTCCTUploaderEventBatchBlock)(NSNumber *_Nullable batchID,
                                              NSSet<GDTCOREvent *> *_Nullable events);

@interface GDTCCTUploadOperation () <NSURLSessionDelegate>

/// Redeclared as readwrite.
@property(nullable, nonatomic, readwrite) NSURLSessionUploadTask *currentTask;

@property(nonatomic, readonly) GDTCORTarget target;
@property(nonatomic, readonly) GDTCORUploadConditions conditions;
@property(nonatomic, readonly) NSURL *uploadURL;
@property(nonatomic, readonly) id<GDTCORStoragePromiseProtocol> storage;
@property(nonatomic, readonly) id<GDTCCTUploadMetadataProvider> metadataProvider;

@property(nonatomic, readwrite, getter=isExecuting) BOOL executing;
@property(nonatomic, readwrite, getter=isFinished) BOOL finished;

@property(nonatomic, readwrite) BOOL uploadAttempted;

@end

@implementation GDTCCTUploadOperation

- (instancetype)initWithTarget:(GDTCORTarget)target
                    conditions:(GDTCORUploadConditions)conditions
                     uploadURL:(NSURL *)uploadURL
                         queue:(dispatch_queue_t)queue
                       storage:(id<GDTCORStoragePromiseProtocol>)storage
              metadataProvider:(id<GDTCCTUploadMetadataProvider>)metadataProvider {
  self = [super init];
  if (self) {
    _uploaderQueue = queue;
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    _uploaderSession = [NSURLSession sessionWithConfiguration:config
                                                     delegate:self
                                                delegateQueue:nil];
    _target = target;
    _conditions = conditions;
    _uploadURL = uploadURL;
    _storage = storage;
    _metadataProvider = metadataProvider;
  }
  return self;
}

- (void)uploadTarget:(GDTCORTarget)target withConditions:(GDTCORUploadConditions)conditions {
  __block GDTCORBackgroundIdentifier backgroundTaskID = GDTCORBackgroundIdentifierInvalid;

  dispatch_block_t backgroundTaskCompletion = ^{
    // End the background task if there was one.
    if (backgroundTaskID != GDTCORBackgroundIdentifierInvalid) {
      [[GDTCORApplication sharedApplication] endBackgroundTask:backgroundTaskID];
      backgroundTaskID = GDTCORBackgroundIdentifierInvalid;
    }
  };

  backgroundTaskID = [[GDTCORApplication sharedApplication]
      beginBackgroundTaskWithName:@"GDTCCTUploader-upload"
                expirationHandler:^{
                  if (backgroundTaskID != GDTCORBackgroundIdentifierInvalid) {
                    // Cancel the upload and complete delivery.
                    [self.currentTask cancel];

                    // End the background task.
                    backgroundTaskCompletion();
                  }
                }];

  id<GDTCORStoragePromiseProtocol> storage = self.storage;

  // 1. Check if the conditions for the target are suitable.
  [self isReadyToUploadTarget:target conditions:conditions]
      .thenOn(self.uploaderQueue,
              ^id(id result) {
                // 2. Remove previously attempted batches
                return [storage removeAllBatchesForTarget:target deleteEvents:NO];
              })
      .thenOn(self.uploaderQueue,
              ^FBLPromise<NSNumber *> *(id result) {
                // There may be a big amount of events stored, so creating a batch may be an
                // expensive operation.

                // 3. Do a lightweight check if there are any events for the target first to
                // finish early if there are no.
                return [storage hasEventsForTarget:target];
              })
      .validateOn(self.uploaderQueue,
                  ^BOOL(NSNumber *hasEvents) {
                    // Stop operation if there are no events to upload.
                    return hasEvents.boolValue;
                  })
      .thenOn(self.uploaderQueue,
              ^FBLPromise<GDTCORUploadBatch *> *(id result) {
                if (self.isCancelled) {
                  return nil;
                }

                self.uploadAttempted = YES;

                // 4. Fetch events to upload.
                GDTCORStorageEventSelector *eventSelector = [self eventSelectorTarget:target
                                                                       withConditions:conditions];
                return [storage batchWithEventSelector:eventSelector
                                       batchExpiration:[NSDate dateWithTimeIntervalSinceNow:600]];
              })
      .thenOn(self.uploaderQueue,
              ^FBLPromise *(GDTCORUploadBatch *batch) {
                // 5. Perform upload URL request.
                return [self sendURLRequestWithBatchID:batch.batchID
                                                events:batch.events
                                                target:target
                                               storage:storage];
              })
      .thenOn(self.uploaderQueue,
              ^id(id result) {
                // 6. Finish operation.
                [self finishOperation];
                return nil;
              })
      .catchOn(self.uploaderQueue, ^(NSError *error) {
        // TODO: Maybe report the error to the client.
        [self finishOperation];
      });
}

#pragma mark - Upload implementation details

- (FBLPromise<NSNull *> *)sendURLRequestWithBatchID:(nullable NSNumber *)batchID
                                             events:(nullable NSSet<GDTCOREvent *> *)events
                                             target:(GDTCORTarget)target
                                            storage:(id<GDTCORStorageProtocol>)storage {
  // TODO: Break down upload operation on stages with promises.
  return [FBLPromise onQueue:self.uploaderQueue
              wrapCompletion:^(FBLPromiseCompletion _Nonnull handler) {
                [self uploadBatchWithID:batchID
                                 events:events
                                 target:target
                                storage:storage
                             completion:handler];
              }];
}

/** Performs URL request, handles the result and updates the uploader state. */
- (void)uploadBatchWithID:(nullable NSNumber *)batchID
                   events:(nullable NSSet<GDTCOREvent *> *)events
                   target:(GDTCORTarget)target
                  storage:(id<GDTCORStorageProtocol>)storage
               completion:(dispatch_block_t)completion {
  [self
      sendURLRequestForBatchWithID:batchID
                            events:events
                            target:target
                 completionHandler:^(NSNumber *_Nonnull batchID,
                                     NSSet<GDTCOREvent *> *_Nullable events, NSData *_Nullable data,
                                     NSURLResponse *_Nullable response, NSError *_Nullable error) {
                   dispatch_async(self.uploaderQueue, ^{
                     [self handleURLResponse:response
                                        data:data
                                       error:error
                                      target:target
                                     storage:storage
                                     batchID:batchID];
                     completion();
                   });
                 }];
}

/** Composes and sends URL request. */
- (FBLPromise<GULURLSessionDataResponse *> *)sendURLRequestForBatchWithID:(nullable NSNumber *)batchID
                              events:(nullable NSSet<GDTCOREvent *> *)events
                              target:(GDTCORTarget)target {
  return [FBLPromise onQueue:self.uploaderQueue do:^NSURLRequest * {
    // 1. Prepare URL request.
    NSData *requestProtoData = [self constructRequestProtoWithEvents:events];
    NSData *gzippedData = [GDTCCTCompressionHelper gzippedData:requestProtoData];
    BOOL usingGzipData = gzippedData != nil && gzippedData.length < requestProtoData.length;
    NSData *dataToSend = usingGzipData ? gzippedData : requestProtoData;
    NSURLRequest *request = [self constructRequestForTarget:target data:dataToSend];
    GDTCORLogDebug(@"CTT: request containing %lu events created: %@", (unsigned long)events.count,
                   request);
    return request;
  }]
  .thenOn(self.uploaderQueue, ^FBLPromise<GULURLSessionDataResponse *> *(NSURLRequest *request) {
    // 2. Send URL request.
    return [self.uploaderSession gul_dataTaskPromiseWithRequest:request];
  });
}

/** Validates events and sends URL request and calls completion with the result. Modifies uploading
 * state in the case of the failure.*/
- (void)sendURLRequestForBatchWithID:(nullable NSNumber *)batchID
                              events:(nullable NSSet<GDTCOREvent *> *)events
                              target:(GDTCORTarget)target
                   completionHandler:(GDTCCTUploaderURLTaskCompletion)completionHandler {
  dispatch_async(self.uploaderQueue, ^{
    NSData *requestProtoData = [self constructRequestProtoWithEvents:events];
    NSData *gzippedData = [GDTCCTCompressionHelper gzippedData:requestProtoData];
    BOOL usingGzipData = gzippedData != nil && gzippedData.length < requestProtoData.length;
    NSData *dataToSend = usingGzipData ? gzippedData : requestProtoData;
    NSURLRequest *request = [self constructRequestForTarget:target data:dataToSend];
    GDTCORLogDebug(@"CTT: request containing %lu events created: %@", (unsigned long)events.count,
                   request);
    NSSet<GDTCOREvent *> *eventsForDebug;
#if !NDEBUG
    eventsForDebug = events;
#endif
    self.currentTask = [self.uploaderSession
        uploadTaskWithRequest:request
                     fromData:dataToSend
            completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response,
                                NSError *_Nullable error) {
              completionHandler(batchID, eventsForDebug, data, response, error);
            }];
    GDTCORLogDebug(@"%@", @"CCT: The upload task is about to begin.");
    [self.currentTask resume];
  });
}

/** Handles URL request response. */
- (void)handleURLResponse:(nullable NSURLResponse *)response
                     data:(nullable NSData *)data
                    error:(nullable NSError *)error
                   target:(GDTCORTarget)target
                  storage:(id<GDTCORStorageProtocol>)storage
                  batchID:(NSNumber *)batchID {
  GDTCORLogDebug(@"%@", @"CCT: request completed");
  if (error) {
    GDTCORLogWarning(GDTCORMCWUploadFailed, @"There was an error uploading events: %@", error);
  }
  NSError *decodingError;
  GDTCORClock *futureUploadTime;
  if (data) {
    gdt_cct_LogResponse logResponse = GDTCCTDecodeLogResponse(data, &decodingError);
    if (!decodingError && logResponse.has_next_request_wait_millis) {
      GDTCORLogDebug(@"CCT: The backend responded asking to not upload for %lld millis from now.",
                     logResponse.next_request_wait_millis);
      futureUploadTime =
          [GDTCORClock clockSnapshotInTheFuture:logResponse.next_request_wait_millis];
    } else if (decodingError) {
      GDTCORLogDebug(@"There was a response decoding error: %@", decodingError);
    }
    pb_release(gdt_cct_LogResponse_fields, &logResponse);
  }
  if (!futureUploadTime) {
    GDTCORLogDebug(@"%@", @"CCT: The backend response failed to parse, so the next request "
                          @"won't occur until 15 minutes from now");
    // 15 minutes from now.
    futureUploadTime = [GDTCORClock clockSnapshotInTheFuture:15 * 60 * 1000];
  }

  [self.metadataProvider setNextUploadTime:futureUploadTime forTarget:target];

  // Only retry if one of these codes is returned, or there was an error.
  if (error || ((NSHTTPURLResponse *)response).statusCode == 429 ||
      ((NSHTTPURLResponse *)response).statusCode == 503) {
    // Move the events back to the main storage to be uploaded on the next attempt.
    [storage removeBatchWithID:batchID deleteEvents:NO onComplete:nil];
  } else {
    GDTCORLogDebug(@"%@", @"CCT: package delivered");
    [storage removeBatchWithID:batchID deleteEvents:YES onComplete:nil];
  }

  self.currentTask = nil;
}

#pragma mark - Private helper methods

/** @return A resolved promise if is ready and a rejected promise if not. */
- (FBLPromise<NSNull *> *)isReadyToUploadTarget:(GDTCORTarget)target
                                     conditions:(GDTCORUploadConditions)conditions {
  FBLPromise<NSNull *> *promise = [FBLPromise pendingPromise];
  if ([self readyToUploadTarget:target conditions:conditions]) {
    [promise fulfill:[NSNull null]];
  } else {
    // TODO: Do we need a more comprehensive message here?
    [promise reject:[self genericRejectedPromiseErrorWithReason:@"Is not ready."]];
  }
  return promise;
}

// TODO: Move to a separate class/extension/file.
- (NSError *)genericRejectedPromiseErrorWithReason:(NSString *)reason {
  return [NSError errorWithDomain:@"GDTCCTUploader"
                             code:-1
                         userInfo:@{NSLocalizedFailureReasonErrorKey : reason}];
}

/** */
- (BOOL)readyToUploadTarget:(GDTCORTarget)target conditions:(GDTCORUploadConditions)conditions {
  // Not ready to upload with no network connection.
  // TODO: Reconsider using reachability to prevent an upload attempt.
  // See https://developer.apple.com/videos/play/wwdc2019/712/ (49:40) for more details.
  if (conditions & GDTCORUploadConditionNoNetwork) {
    GDTCORLogDebug(@"%@", @"CCT: Not ready to upload without a network connection.");
    return NO;
  }

  // Upload events when there are with no additional conditions for kGDTCORTargetCSH.
  if (target == kGDTCORTargetCSH) {
    GDTCORLogDebug(@"%@", @"CCT: kGDTCORTargetCSH events are allowed to be "
                          @"uploaded straight away.");
    return YES;
  }

  if (target == kGDTCORTargetINT) {
    GDTCORLogDebug(@"%@", @"CCT: kGDTCORTargetINT events are allowed to be "
                          @"uploaded straight away.");
    return YES;
  }

  // Upload events with no additional conditions if high priority.
  if ((conditions & GDTCORUploadConditionHighPriority) == GDTCORUploadConditionHighPriority) {
    GDTCORLogDebug(@"%@", @"CCT: a high priority event is allowing an upload");
    return YES;
  }

  // Check next upload time for the target.
  BOOL isAfterNextUploadTime = YES;
  GDTCORClock *nextUploadTime = [self.metadataProvider nextUploadTimeForTarget:target];
  if (nextUploadTime) {
    isAfterNextUploadTime = [[GDTCORClock snapshot] isAfter:nextUploadTime];
  }

  if (isAfterNextUploadTime) {
    GDTCORLogDebug(@"CCT: can upload to target %ld because the request wait time has transpired",
                   (long)target);
  } else {
    GDTCORLogDebug(@"CCT: can't upload to target %ld because the backend asked to wait",
                   (long)target);
  }

  return isAfterNextUploadTime;
}

/** Constructs data given an upload package.
 *
 * @param events The events used to construct the request proto bytes.
 * @return Proto bytes representing a gdt_cct_LogRequest object.
 */
- (nonnull NSData *)constructRequestProtoWithEvents:(NSSet<GDTCOREvent *> *)events {
  // Segment the log events by log type.
  NSMutableDictionary<NSString *, NSMutableSet<GDTCOREvent *> *> *logMappingIDToLogSet =
      [[NSMutableDictionary alloc] init];
  [events enumerateObjectsUsingBlock:^(GDTCOREvent *_Nonnull event, BOOL *_Nonnull stop) {
    NSMutableSet *logSet = logMappingIDToLogSet[event.mappingID];
    logSet = logSet ? logSet : [[NSMutableSet alloc] init];
    [logSet addObject:event];
    logMappingIDToLogSet[event.mappingID] = logSet;
  }];

  gdt_cct_BatchedLogRequest batchedLogRequest =
      GDTCCTConstructBatchedLogRequest(logMappingIDToLogSet);

  NSData *data = GDTCCTEncodeBatchedLogRequest(&batchedLogRequest);
  pb_release(gdt_cct_BatchedLogRequest_fields, &batchedLogRequest);
  return data ? data : [[NSData alloc] init];
}

/** Constructs a request to FLL given a URL and request body data.
 *
 * @param target The target backend to send the request to.
 * @param data The request body data.
 * @return A new NSURLRequest ready to be sent to FLL.
 */
- (nullable NSURLRequest *)constructRequestForTarget:(GDTCORTarget)target data:(NSData *)data {
  if (data == nil || data.length == 0) {
    GDTCORLogDebug(@"There was no data to construct a request for target %ld.", (long)target);
    return nil;
  }
  NSURL *URL = self.uploadURL;
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
  NSString *targetString;
  switch (target) {
    case kGDTCORTargetCCT:
      targetString = @"cct";
      break;

    case kGDTCORTargetFLL:
      targetString = @"fll";
      break;

    case kGDTCORTargetCSH:
      targetString = @"csh";
      break;
    case kGDTCORTargetINT:
      targetString = @"int";
      break;

    default:
      targetString = @"unknown";
      break;
  }
  NSString *userAgent =
      [NSString stringWithFormat:@"datatransport/%@ %@support/%@ apple/", kGDTCORVersion,
                                 targetString, kGDTCCTSupportSDKVersion];

  [request setValue:[self.metadataProvider APIKeyForTarget:target]
      forHTTPHeaderField:@"X-Goog-Api-Key"];

  if ([GDTCCTCompressionHelper isGzipped:data]) {
    [request setValue:@"gzip" forHTTPHeaderField:@"Content-Encoding"];
  }
  [request setValue:@"application/x-protobuf" forHTTPHeaderField:@"Content-Type"];
  [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
  [request setValue:userAgent forHTTPHeaderField:@"User-Agent"];
  request.HTTPMethod = @"POST";
  [request setHTTPBody:data];
  return request;
}

/** */
- (nullable GDTCORStorageEventSelector *)eventSelectorTarget:(GDTCORTarget)target
                                              withConditions:(GDTCORUploadConditions)conditions {
  if ((conditions & GDTCORUploadConditionHighPriority) == GDTCORUploadConditionHighPriority) {
    return [GDTCORStorageEventSelector eventSelectorForTarget:target];
  }
  NSMutableSet<NSNumber *> *qosTiers = [[NSMutableSet alloc] init];
  if (conditions & GDTCORUploadConditionWifiData) {
    [qosTiers addObjectsFromArray:@[
      @(GDTCOREventQoSFast), @(GDTCOREventQoSWifiOnly), @(GDTCOREventQosDefault),
      @(GDTCOREventQoSTelemetry), @(GDTCOREventQoSUnknown)
    ]];
  }
  if (conditions & GDTCORUploadConditionMobileData) {
    [qosTiers addObjectsFromArray:@[ @(GDTCOREventQoSFast), @(GDTCOREventQosDefault) ]];
  }

  return [[GDTCORStorageEventSelector alloc] initWithTarget:target
                                                   eventIDs:nil
                                                 mappingIDs:nil
                                                   qosTiers:qosTiers];
}

#pragma mark - GDTCORLifecycleProtocol

- (void)appWillForeground:(GDTCORApplication *)app {
  dispatch_async(_uploaderQueue, ^{
    NSDateComponents *dateComponents = [[NSDateComponents alloc] init];
    NSCalendar *gregorianCalendar =
        [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDate *date = [gregorianCalendar dateFromComponents:dateComponents];
    kWeekday = [gregorianCalendar component:NSCalendarUnitWeekday fromDate:date];
  });
}

- (void)appWillTerminate:(GDTCORApplication *)application {
  dispatch_sync(_uploaderQueue, ^{
    [self.currentTask cancel];
  });
}

#pragma mark - NSURLSessionDelegate

- (void)URLSession:(NSURLSession *)session
                          task:(NSURLSessionTask *)task
    willPerformHTTPRedirection:(NSHTTPURLResponse *)response
                    newRequest:(NSURLRequest *)request
             completionHandler:(void (^)(NSURLRequest *_Nullable))completionHandler {
  if (!completionHandler) {
    return;
  }
  if (response.statusCode == 302 || response.statusCode == 301) {
    // TODO: Take a redirect URL from the response.
    //    if ([request.URL isEqual:[self serverURLForTarget:kGDTCORTargetFLL]]) {
    //      NSURLRequest *newRequest = [self constructRequestForTarget:kGDTCORTargetCCT
    //                                                            data:task.originalRequest.HTTPBody];
    //      completionHandler(newRequest);
    //    }
  } else {
    completionHandler(request);
  }
}

#pragma mark - NSOperation methods

@synthesize executing = _executing;
@synthesize finished = _finished;

- (BOOL)isAsynchronous {
  return YES;
}

- (void)startOperation {
  [self willChangeValueForKey:@"isExecuting"];
  [self willChangeValueForKey:@"isFinished"];
  _executing = YES;
  _finished = NO;
  [self didChangeValueForKey:@"isExecuting"];
  [self didChangeValueForKey:@"isFinished"];
}

- (void)finishOperation {
  [self willChangeValueForKey:@"isExecuting"];
  [self willChangeValueForKey:@"isFinished"];
  _executing = NO;
  _finished = YES;
  [self didChangeValueForKey:@"isExecuting"];
  [self didChangeValueForKey:@"isFinished"];
}

- (void)main {
  [self startOperation];

  [self uploadTarget:self.target withConditions:self.conditions];
}

@end

NS_ASSUME_NONNULL_END
