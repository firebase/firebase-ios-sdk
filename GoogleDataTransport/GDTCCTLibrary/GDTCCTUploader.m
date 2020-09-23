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

#import "GoogleDataTransport/GDTCCTLibrary/Private/GDTCCTUploader.h"

#import "GoogleDataTransport/GDTCORLibrary/Public/GoogleDataTransport/GDTCORConsoleLogger.h"
#import "GoogleDataTransport/GDTCORLibrary/Public/GoogleDataTransport/GDTCOREvent.h"
#import "GoogleDataTransport/GDTCORLibrary/Public/GoogleDataTransport/GDTCORPlatform.h"
#import "GoogleDataTransport/GDTCORLibrary/Public/GoogleDataTransport/GDTCORRegistrar.h"

#import "GoogleDataTransport/GDTCCTLibrary/Private/GDTCCTUploadOperation.h"

@interface GDTCCTUploader () <NSURLSessionDelegate>

@property(nonatomic, readonly) NSOperationQueue *uploadQueue;

@end

@implementation GDTCCTUploader

+ (void)load {
  GDTCCTUploader *uploader = [GDTCCTUploader sharedInstance];
  [[GDTCORRegistrar sharedInstance] registerUploader:uploader target:kGDTCORTargetCCT];
  [[GDTCORRegistrar sharedInstance] registerUploader:uploader target:kGDTCORTargetFLL];
  [[GDTCORRegistrar sharedInstance] registerUploader:uploader target:kGDTCORTargetCSH];
  [[GDTCORRegistrar sharedInstance] registerUploader:uploader target:kGDTCORTargetINT];
}

+ (instancetype)sharedInstance {
  static GDTCCTUploader *sharedInstance;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[GDTCCTUploader alloc] init];
  });
  return sharedInstance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _uploadQueue = [[NSOperationQueue alloc] init];
    _uploadQueue.maxConcurrentOperationCount = 1;
  }
  return self;
}

- (void)uploadTarget:(GDTCORTarget)target withConditions:(GDTCORUploadConditions)conditions {
  // Current GDTCCTUploader expected behaviour:
  // 1. Accept multiple upload request
  // 2. Verify if there are events eligible for upload and start upload for the first suitable
  // target
  // 3. Ignore other requests while an upload is in-progress.

  // TODO: Revisit expected behaviour.
  // Potentially better option:
  // 1. Accept and enqueue all upload requests
  // 2. Notify the client of upload stages
  // 3. Allow the client cancelling upload requests as needed.

  GDTCCTUploadOperation *uploadOperation = [[GDTCCTUploadOperation alloc] init];

  __weak __auto_type weakSelf = self;
  __weak GDTCCTUploadOperation *weakOperation = uploadOperation;
  uploadOperation.completionBlock = ^{
    if (weakOperation.uploadAttempted) {
      // Ignore all upload requests received when the upload was in progress.
      [weakSelf.uploadQueue cancelAllOperations];
    }
  };

  [self.uploadQueue addOperation:uploadOperation];
}

@end
