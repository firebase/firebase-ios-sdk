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

#import "GDTCORTests/Integration/Helpers/GDTCORIntegrationTestUploader.h"

#import <GoogleDataTransport/GDTCORAssert.h>
#import <GoogleDataTransport/GDTCORRegistrar.h>
#import <GoogleDataTransport/GDTCORStoredEvent.h>

#import "GDTCORTests/Integration/Helpers/GDTCORIntegrationTestPrioritizer.h"

#import "GDTCORTests/Integration/TestServer/GDTCORTestServer.h"

@implementation GDTCORIntegrationTestUploader {
  /** The current upload task. */
  NSURLSessionUploadTask *_currentUploadTask;

  /** The server URL to upload to. */
  NSURL *_serverURL;
}

- (instancetype)initWithServerURL:(NSURL *)serverURL {
  self = [super init];
  if (self) {
    _serverURL = serverURL;
    [[GDTCORRegistrar sharedInstance] registerUploader:self target:kGDTCORIntegrationTestTarget];
  }
  return self;
}

- (void)uploadPackage:(GDTCORUploadPackage *)package {
  GDTCORFatalAssert(!_currentUploadTask,
                    @"An upload shouldn't be initiated with another in progress.");
  NSURL *serverURL = arc4random_uniform(2) ? [_serverURL URLByAppendingPathComponent:@"log"]
                                           : [_serverURL URLByAppendingPathComponent:@"logBatch"];
  NSURLSession *session = [NSURLSession sharedSession];
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:serverURL];
  request.HTTPMethod = @"POST";
  NSMutableData *uploadData = [[NSMutableData alloc] init];

  NSLog(@"Uploading batch of %lu events: ", (unsigned long)[package events].count);

  // In real usage, you'd create an instance of whatever request proto your server needs.
  for (GDTCORStoredEvent *event in package.events) {
    NSData *fileData = [NSData dataWithContentsOfURL:event.dataFuture.fileURL];
    GDTCORFatalAssert(fileData, @"An event file shouldn't be empty");
    [uploadData appendData:fileData];
  }
  _currentUploadTask = [session
      uploadTaskWithRequest:request
                   fromData:uploadData
          completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response,
                              NSError *_Nullable error) {
            NSLog(@"Batch upload complete.");
            // Remove from the prioritizer if there were no errors.
            GDTCORFatalAssert(!error, @"There should be no errors uploading events: %@", error);
            if (error) {
              [package retryDeliveryInTheFuture];
            } else {
              [package completeDelivery];
            }
            self->_currentUploadTask = nil;
          }];
  [_currentUploadTask resume];
}

- (BOOL)readyToUploadWithConditions:(GDTCORUploadConditions)conditions {
  return _currentUploadTask ? NO : YES;
}

@end
