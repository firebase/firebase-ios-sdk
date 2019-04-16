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

#import "Tests/Integration/Helpers/GDTIntegrationTestUploader.h"

#import "Tests/Integration/Helpers/GDTIntegrationTestPrioritizer.h"

#import "Tests/Integration/TestServer/GDTTestServer.h"

@implementation GDTIntegrationTestUploader {
  /** The current upload task. */
  NSURLSessionUploadTask *_currentUploadTask;

  /** The server URL to upload to. */
  NSURL *_serverURL;
}

- (instancetype)initWithServerURL:(NSURL *)serverURL {
  self = [super init];
  if (self) {
    _serverURL = serverURL;
    [[GDTRegistrar sharedInstance] registerUploader:self target:kGDTIntegrationTestTarget];
  }
  return self;
}

- (void)uploadPackage:(GDTUploadPackage *)package
           onComplete:(GDTUploaderCompletionBlock)onComplete {
  NSAssert(!_currentUploadTask, @"An upload shouldn't be initiated with another in progress.");
  NSURL *serverURL = arc4random_uniform(2) ? [_serverURL URLByAppendingPathComponent:@"log"]
                                           : [_serverURL URLByAppendingPathComponent:@"logBatch"];
  NSURLSession *session = [NSURLSession sharedSession];
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:serverURL];
  request.HTTPMethod = @"POST";
  NSMutableData *uploadData = [[NSMutableData alloc] init];

  NSLog(@"Uploading batch of %lu events: ", (unsigned long)[package events].count);

  // In real usage, you'd create an instance of whatever request proto your server needs.
  for (GDTStoredEvent *event in package.events) {
    NSData *fileData = [NSData dataWithContentsOfURL:event.eventFileURL];
    NSAssert(fileData, @"An event file shouldn't be empty");
    [uploadData appendData:fileData];
  }
  NSURLSessionUploadTask *uploadTask =
      [session uploadTaskWithRequest:request
                            fromData:uploadData
                   completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response,
                                       NSError *_Nullable error) {
                     NSLog(@"Batch upload complete.");
                     // Remove from the prioritizer if there were no errors.
                     NSAssert(!error, @"There should be no errors uploading events: %@", error);
                     if (onComplete) {
                       // In real usage, the server would/should return a desired next upload time.
                       GDTClock *nextUploadTime = [GDTClock clockSnapshotInTheFuture:1000];
                       onComplete(kGDTIntegrationTestTarget, nextUploadTime, error);
                     }
                   }];
  [uploadTask resume];
}

- (void)appWillBackground:(UIApplication *)app {
}

- (void)appWillForeground:(UIApplication *)app {
}

- (void)appWillTerminate:(UIApplication *)application {
}

@end
