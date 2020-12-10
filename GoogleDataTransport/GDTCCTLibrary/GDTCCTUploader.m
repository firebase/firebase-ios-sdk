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

#import "GoogleDataTransport/GDTCCTLibrary/Private/GDTCCTUploader.h"

#import "GoogleDataTransport/GDTCORLibrary/Internal/GDTCORPlatform.h"
#import "GoogleDataTransport/GDTCORLibrary/Internal/GDTCORRegistrar.h"
#import "GoogleDataTransport/GDTCORLibrary/Public/GoogleDataTransport/GDTCORConsoleLogger.h"
#import "GoogleDataTransport/GDTCORLibrary/Public/GoogleDataTransport/GDTCOREvent.h"

#import "GoogleDataTransport/GDTCCTLibrary/Private/GDTCCTUploadOperation.h"

NS_ASSUME_NONNULL_BEGIN

static NSString *const kINTServerURL =
    @"https://dummyapiverylong-dummy.dummy.com/dummy/api/very/long";

// TODO: Implement.
#if !NDEBUG
NSNotificationName const GDTCCTUploadCompleteNotification = @"com.GDTCCTUploader.UploadComplete";
#endif  // #if !NDEBUG

@interface GDTCCTUploader () <NSURLSessionDelegate, GDTCCTUploadMetadataProvider>

@property(nonatomic, readonly) NSOperationQueue *uploadOperationQueue;
@property(nonatomic, readonly) dispatch_queue_t uploadQueue;

@end

@implementation GDTCCTUploader

static NSURL *_testServerURL = nil;

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
    _uploadQueue = dispatch_queue_create("com.google.GDTCCTUploader", DISPATCH_QUEUE_SERIAL);
    _uploadOperationQueue = [[NSOperationQueue alloc] init];
    _uploadOperationQueue.maxConcurrentOperationCount = 1;
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

  id<GDTCORStoragePromiseProtocol> storage = GDTCORStoragePromiseInstanceForTarget(target);
  if (storage == nil) {
    GDTCORLogError(GDTCORMCEGeneralError,
                   @"Failed to upload target: %ld - could not find corresponding storage instance.",
                   (long)target);
    return;
  }

  GDTCCTUploadOperation *uploadOperation =
      [[GDTCCTUploadOperation alloc] initWithTarget:target
                                         conditions:conditions
                                          uploadURL:[[self class] serverURLForTarget:target]
                                              queue:self.uploadQueue
                                            storage:storage
                                   metadataProvider:self];

  __weak __auto_type weakSelf = self;
  __weak GDTCCTUploadOperation *weakOperation = uploadOperation;
  uploadOperation.completionBlock = ^{
    // TODO: Strongify references?
    if (weakOperation.uploadAttempted) {
      // Ignore all upload requests received when the upload was in progress.
      [weakSelf.uploadOperationQueue cancelAllOperations];

      // TODO: Should we reconsider GDTCCTUploadCompleteNotification? Maybe a completion handler
      // instead?
#if !NDEBUG
      [[NSNotificationCenter defaultCenter] postNotificationName:GDTCCTUploadCompleteNotification
                                                          object:nil];
#endif  // #if !NDEBUG
    }

#if !NDEBUG
    if (weakSelf.uploadOperationQueue.operationCount == 0) {
      [[NSNotificationCenter defaultCenter] postNotificationName:GDTCCTUploadCompleteNotification
                                                          object:nil];
    }
#endif  // #if !NDEBUG
  };

  [self.uploadOperationQueue addOperation:uploadOperation];
}

#pragma mark - URLs

/**
 *
 */
- (nullable NSURL *)serverURLForTarget:(GDTCORTarget)target {
+ (void)setTestServerURL:(NSURL *_Nullable)serverURL {
  _testServerURL = serverURL;
}

+ (NSURL *_Nullable)testServerURL {
  return _testServerURL;
}

+ (NSDictionary<NSNumber *, NSURL *> *)uploadURLs {
  // These strings should be interleaved to construct the real URL. This is just to (hopefully)
  // fool github URL scanning bots.
  static NSURL *CCTServerURL;
  static dispatch_once_t CCTOnceToken;
  dispatch_once(&CCTOnceToken, ^{
    const char *p1 = "hts/frbslgiggolai.o/0clgbth";
    const char *p2 = "tp:/ieaeogn.ogepscmvc/o/ac";
    const char URL[54] = {p1[0],  p2[0],  p1[1],  p2[1],  p1[2],  p2[2],  p1[3],  p2[3],  p1[4],
                          p2[4],  p1[5],  p2[5],  p1[6],  p2[6],  p1[7],  p2[7],  p1[8],  p2[8],
                          p1[9],  p2[9],  p1[10], p2[10], p1[11], p2[11], p1[12], p2[12], p1[13],
                          p2[13], p1[14], p2[14], p1[15], p2[15], p1[16], p2[16], p1[17], p2[17],
                          p1[18], p2[18], p1[19], p2[19], p1[20], p2[20], p1[21], p2[21], p1[22],
                          p2[22], p1[23], p2[23], p1[24], p2[24], p1[25], p2[25], p1[26], '\0'};
    CCTServerURL = [NSURL URLWithString:[NSString stringWithUTF8String:URL]];
  });

  static NSURL *FLLServerURL;
  static dispatch_once_t FLLOnceToken;
  dispatch_once(&FLLOnceToken, ^{
    const char *p1 = "hts/frbslgigp.ogepscmv/ieo/eaybtho";
    const char *p2 = "tp:/ieaeogn-agolai.o/1frlglgc/aclg";
    const char URL[69] = {p1[0],  p2[0],  p1[1],  p2[1],  p1[2],  p2[2],  p1[3],  p2[3],  p1[4],
                          p2[4],  p1[5],  p2[5],  p1[6],  p2[6],  p1[7],  p2[7],  p1[8],  p2[8],
                          p1[9],  p2[9],  p1[10], p2[10], p1[11], p2[11], p1[12], p2[12], p1[13],
                          p2[13], p1[14], p2[14], p1[15], p2[15], p1[16], p2[16], p1[17], p2[17],
                          p1[18], p2[18], p1[19], p2[19], p1[20], p2[20], p1[21], p2[21], p1[22],
                          p2[22], p1[23], p2[23], p1[24], p2[24], p1[25], p2[25], p1[26], p2[26],
                          p1[27], p2[27], p1[28], p2[28], p1[29], p2[29], p1[30], p2[30], p1[31],
                          p2[31], p1[32], p2[32], p1[33], p2[33], '\0'};
    FLLServerURL = [NSURL URLWithString:[NSString stringWithUTF8String:URL]];
  });

  static NSURL *CSHServerURL;
  static dispatch_once_t CSHOnceToken;
  dispatch_once(&CSHOnceToken, ^{
    // These strings should be interleaved to construct the real URL. This is just to (hopefully)
    // fool github URL scanning bots.
    const char *p1 = "hts/cahyiseot-agolai.o/1frlglgc/aclg";
    const char *p2 = "tp:/rsltcrprsp.ogepscmv/ieo/eaybtho";
    const char URL[72] = {p1[0],  p2[0],  p1[1],  p2[1],  p1[2],  p2[2],  p1[3],  p2[3],  p1[4],
                          p2[4],  p1[5],  p2[5],  p1[6],  p2[6],  p1[7],  p2[7],  p1[8],  p2[8],
                          p1[9],  p2[9],  p1[10], p2[10], p1[11], p2[11], p1[12], p2[12], p1[13],
                          p2[13], p1[14], p2[14], p1[15], p2[15], p1[16], p2[16], p1[17], p2[17],
                          p1[18], p2[18], p1[19], p2[19], p1[20], p2[20], p1[21], p2[21], p1[22],
                          p2[22], p1[23], p2[23], p1[24], p2[24], p1[25], p2[25], p1[26], p2[26],
                          p1[27], p2[27], p1[28], p2[28], p1[29], p2[29], p1[30], p2[30], p1[31],
                          p2[31], p1[32], p2[32], p1[33], p2[33], p1[34], p2[34], p1[35], '\0'};
    CSHServerURL = [NSURL URLWithString:[NSString stringWithUTF8String:URL]];
  });
  static NSDictionary<NSNumber *, NSURL *> *uploadURLs;
  static dispatch_once_t URLOnceToken;
  dispatch_once(&URLOnceToken, ^{
    uploadURLs = @{
      @(kGDTCORTargetCCT) : CCTServerURL,
      @(kGDTCORTargetFLL) : FLLServerURL,
      @(kGDTCORTargetCSH) : CSHServerURL,
      @(kGDTCORTargetINT) : [NSURL URLWithString:kINTServerURL]
    };
  });
  return uploadURLs;
}

+ (nullable NSURL *)serverURLForTarget:(GDTCORTarget)target {
#if !NDEBUG
  if (_testServerURL) {
    return _testServerURL;
  }
#endif  // !NDEBUG

  NSDictionary<NSNumber *, NSURL *> *uploadURLs = [self uploadURLs];
  return uploadURLs[@(target)];
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _uploaderQueue = dispatch_queue_create("com.google.GDTCCTUploader", DISPATCH_QUEUE_SERIAL);
  }
  return self;
}

- (NSURLSession *)uploaderSession {
  if (_uploaderSession == nil) {
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    _uploaderSession = [NSURLSession sessionWithConfiguration:config
                                                     delegate:self
                                                delegateQueue:nil];
  }
  return _uploaderSession;
}

- (NSString *)FLLAndCSHAndINTAPIKey {
  static NSString *defaultServerKey;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    // These strings should be interleaved to construct the real key.
    const char *p1 = "AzSBG0honD6A-PxV5nBc";
    const char *p2 = "Iay44Iwtu2vV0AOrz1C";
    const char defaultKey[40] = {p1[0],  p2[0],  p1[1],  p2[1],  p1[2],  p2[2],  p1[3],  p2[3],
                                 p1[4],  p2[4],  p1[5],  p2[5],  p1[6],  p2[6],  p1[7],  p2[7],
                                 p1[8],  p2[8],  p1[9],  p2[9],  p1[10], p2[10], p1[11], p2[11],
                                 p1[12], p2[12], p1[13], p2[13], p1[14], p2[14], p1[15], p2[15],
                                 p1[16], p2[16], p1[17], p2[17], p1[18], p2[18], p1[19], '\0'};
    defaultServerKey = [NSString stringWithUTF8String:defaultKey];
  });
  return defaultServerKey;
}

#pragma mark - GDTCCTUploadMetadataProvider

// TODO: Implement
- (nullable GDTCORClock *)nextUploadTimeForTarget:(GDTCORTarget)target {
  return nil;
}

- (void)setNextUploadTime:(nullable GDTCORClock *)time forTarget:(GDTCORTarget)target {
}

- (nullable NSString *)APIKeyForTarget:(GDTCORTarget)target {
  if (target == kGDTCORTargetFLL || target == kGDTCORTargetCSH) {
    return [self FLLAndCSHAndINTAPIKey];
  }

  if (target == kGDTCORTargetINT) {
    return [self FLLAndCSHAndINTAPIKey];
  }

  return nil;
}

#if !NDEBUG

- (void)waitForUploadFinished:(dispatch_block_t)completion {
  [self.uploadOperationQueue addOperationWithBlock:completion];
}

#endif  // !NDEBUG

@end

NS_ASSUME_NONNULL_END
