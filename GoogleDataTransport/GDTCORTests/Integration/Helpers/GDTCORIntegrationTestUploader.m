/*
 * Copyright 2019 Google
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

#import "GoogleDataTransport/GDTCORTests/Integration/Helpers/GDTCORIntegrationTestUploader.h"

#import "GoogleDataTransport/GDTCORLibrary/Internal/GDTCORAssert.h"
#import "GoogleDataTransport/GDTCORLibrary/Internal/GDTCORRegistrar.h"
#import "GoogleDataTransport/GDTCORLibrary/Public/GoogleDataTransport/GDTCOREvent.h"

#import "GoogleDataTransport/GDTCORTests/Integration/TestServer/GDTCORTestServer.h"

@implementation GDTCORIntegrationTestUploader {
  /** The current upload task. */
  NSURLSessionUploadTask *_currentUploadTask;

  /** The server URL to upload to. */
  GDTCORTestServer *_testServer;
}

- (instancetype)initWithServer:(GDTCORTestServer *)testServer {
  self = [super init];
  if (self) {
    _testServer = testServer;
    [[GDTCORRegistrar sharedInstance] registerUploader:self target:kGDTCORTargetTest];
  }
  return self;
}

- (void)uploadTarget:(GDTCORTarget)target withConditions:(GDTCORUploadConditions)conditions {
  __block NSSet<GDTCOREvent *> *eventsForTarget;
  id<GDTCORStorageProtocol> storage = GDTCORStorageInstanceForTarget(target);
  GDTCORStorageEventSelector *eventSelector =
      [GDTCORStorageEventSelector eventSelectorForTarget:target];
  [storage
      batchWithEventSelector:eventSelector
             batchExpiration:[NSDate dateWithTimeIntervalSinceNow:60000]
                  onComplete:^(NSNumber *_Nullable batchID,
                               NSSet<GDTCOREvent *> *_Nullable events) {
                    eventsForTarget = events;
                    if (self->_currentUploadTask) {
                      return;
                    }
                    NSURL *serverURL =
                        arc4random_uniform(2)
                            ? [self->_testServer.serverURL URLByAppendingPathComponent:@"log"]
                            : [self->_testServer.serverURL URLByAppendingPathComponent:@"logBatch"];
                    NSURLSession *session = [NSURLSession sharedSession];
                    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:serverURL];
                    request.HTTPMethod = @"POST";
                    NSMutableData *uploadData = [[NSMutableData alloc] init];

                    NSLog(@"Uploading batch of %lu events: ", (unsigned long)eventsForTarget.count);

                    // In real usage, you'd create an instance of whatever request proto your server
                    // needs.
                    for (GDTCOREvent *event in eventsForTarget) {
                      NSData *fileData = event.serializedDataObjectBytes;
                      GDTCORFatalAssert(fileData, @"An event file shouldn't be empty");
                      [uploadData appendData:fileData];
                    }
                    self->_currentUploadTask = [session
                        uploadTaskWithRequest:request
                                     fromData:uploadData
                            completionHandler:^(NSData *_Nullable data,
                                                NSURLResponse *_Nullable response,
                                                NSError *_Nullable error) {
                              NSLog(@"Batch upload complete.");
                              // Remove from the prioritizer if there were no errors.
                              GDTCORFatalAssert(
                                  !error, @"There should be no errors uploading events: %@", error);
                              if (error) {
                                [storage removeBatchWithID:batchID deleteEvents:NO onComplete:nil];
                              } else {
                                [storage removeBatchWithID:batchID deleteEvents:YES onComplete:nil];
                              }
                              self->_currentUploadTask = nil;
                            }];
                    [self->_currentUploadTask resume];
                  }];
}

- (BOOL)readyToUploadTarget:(GDTCORTarget)target conditions:(GDTCORUploadConditions)conditions {
  return _currentUploadTask != nil && _testServer.isRunning;
}

@end
