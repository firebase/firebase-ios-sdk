// Copyright 2017 Google
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

#import "FirebaseStorageInternal/Sources/Public/FirebaseStorageInternal/FIRStorage.h"
#import "FirebaseStorageInternal/Sources/Public/FirebaseStorageInternal/FIRStorageReference.h"

#import "FirebaseStorageInternal/Sources/FIRStorageConstants_Private.h"
#import "FirebaseStorageInternal/Sources/FIRStoragePath.h"
#import "FirebaseStorageInternal/Sources/FIRStorageReference_Private.h"
#import "FirebaseStorageInternal/Sources/FIRStorageTokenAuthorizer.h"
#import "FirebaseStorageInternal/Sources/FIRStorageUtils.h"
#import "FirebaseStorageInternal/Sources/FIRStorage_Private.h"

#import "FirebaseAppCheck/Interop/FIRAppCheckInterop.h"
#import "FirebaseAuth/Interop/FIRAuthInterop.h"
#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

#if SWIFT_PACKAGE
@import GTMSessionFetcherCore;
#else
#import <GTMSessionFetcher/GTMSessionFetcher.h>
#import <GTMSessionFetcher/GTMSessionFetcherLogging.h>
#endif

static NSMutableDictionary<
    NSString * /* app name */,
    NSMutableDictionary<NSString * /* bucket */, GTMSessionFetcherService *> *> *_fetcherServiceMap;
static GTMSessionFetcherRetryBlock _retryWhenOffline;

@interface FIRIMPLStorage () {
  /// Stored Auth reference, if it exists. This needs to be stored for `copyWithZone:`.
  id<FIRAuthInterop> _Nullable _auth;
  id<FIRAppCheckInterop> _Nullable _appCheck;
  BOOL _usesEmulator;
  NSTimeInterval _maxUploadRetryTime;
  NSTimeInterval _maxDownloadRetryTime;
  NSTimeInterval _maxOperationRetryTime;
}
@end

@implementation FIRIMPLStorage

+ (void)initialize {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    _retryWhenOffline = ^(BOOL suggestedWillRetry, NSError *__nullable error,
                          GTMSessionFetcherRetryResponse response) {
      bool shouldRetry = suggestedWillRetry;
      // GTMSessionFetcher does not consider being offline a retryable error, but we do, so we
      // special-case it here.
      if (!shouldRetry && error) {
        shouldRetry = error.code == NSURLErrorNotConnectedToInternet;
      }
      response(shouldRetry);
    };
    _fetcherServiceMap = [[NSMutableDictionary alloc] init];
  });
}

+ (GTMSessionFetcherService *)fetcherServiceForApp:(FIRApp *)app
                                            bucket:(NSString *)bucket
                                              auth:(nullable id<FIRAuthInterop>)auth
                                          appCheck:(nullable id<FIRAppCheckInterop>)appCheck {
  @synchronized(_fetcherServiceMap) {
    NSMutableDictionary *bucketMap = _fetcherServiceMap[app.name];
    if (!bucketMap) {
      bucketMap = [[NSMutableDictionary alloc] init];
      _fetcherServiceMap[app.name] = bucketMap;
    }

    GTMSessionFetcherService *fetcherService = bucketMap[bucket];
    if (!fetcherService) {
      fetcherService = [[GTMSessionFetcherService alloc] init];
      [fetcherService setRetryEnabled:YES];
      [fetcherService setRetryBlock:_retryWhenOffline];
      [fetcherService setAllowLocalhostRequest:YES];
      FIRStorageTokenAuthorizer *authorizer =
          [[FIRStorageTokenAuthorizer alloc] initWithGoogleAppID:app.options.googleAppID
                                                  fetcherService:fetcherService
                                                    authProvider:auth
                                                        appCheck:appCheck];
      [fetcherService setAuthorizer:authorizer];
      bucketMap[bucket] = fetcherService;
    }
    return fetcherService;
  }
}

+ (void)setGTMSessionFetcherLoggingEnabled:(BOOL)isLoggingEnabled {
  [GTMSessionFetcher setLoggingEnabled:isLoggingEnabled];
}

+ (NSString *)bucketForApp:(FIRApp *)app {
  if (app.options.storageBucket) {
    NSString *url = [app.options.storageBucket isEqualToString:@""]
                        ? @""
                        : [@"gs://" stringByAppendingString:app.options.storageBucket];
    return [self bucketForApp:app URL:url];
  } else {
    NSString *const kAppNotConfiguredMessage =
        @"No default Storage bucket found. Did you configure Firebase Storage properly?";
    [NSException raise:NSInvalidArgumentException format:kAppNotConfiguredMessage];
    return nil;
  }
}

+ (NSString *)bucketForApp:(FIRApp *)app URL:(NSString *)url {
  NSString *bucket;
  if ([url isEqualToString:@""]) {
    bucket = @"";
  } else {
    FIRStoragePath *path;

    @try {
      path = [FIRStoragePath pathFromGSURI:url];
    } @catch (NSException *e) {
      [NSException raise:NSInternalInconsistencyException
                  format:@"URI must be in the form of gs://<bucket>/"];
    }

    if (path.object != nil && ![path.object isEqualToString:@""]) {
      [NSException raise:NSInternalInconsistencyException
                  format:@"Storage bucket cannot be initialized with a path"];
    }

    bucket = path.bucket;
  }
  return bucket;
}

- (instancetype)initWithApp:(FIRApp *)app
                     bucket:(NSString *)bucket
                       auth:(nullable id<FIRAuthInterop>)auth
                   appCheck:(nullable id<FIRAppCheckInterop>)appCheck {
  self = [super init];
  if (self) {
    _app = app;
    _auth = auth;
    _appCheck = appCheck;
    _storageBucket = bucket;
    _host = kFIRStorageHost;
    _scheme = kFIRStorageScheme;
    _port = @(kFIRStoragePort);
    _fetcherServiceForApp = nil;  // Configured in `ensureConfigured()`
    // Must be a serial queue.
    _dispatchQueue = dispatch_queue_create("com.google.firebase.storage", DISPATCH_QUEUE_SERIAL);
    _maxDownloadRetryTime = 600.0;
    _maxDownloadRetryInterval =
        [FIRStorageUtils computeRetryIntervalFromRetryTime:_maxDownloadRetryTime];
    _maxOperationRetryTime = 120.0;
    _maxOperationRetryInterval =
        [FIRStorageUtils computeRetryIntervalFromRetryTime:_maxOperationRetryTime];
    _maxUploadRetryTime = 600.0;
    _maxUploadRetryInterval =
        [FIRStorageUtils computeRetryIntervalFromRetryTime:_maxUploadRetryTime];
  }
  return self;
}

- (instancetype)init {
  NSAssert(false, @"Storage cannot be directly instantiated, use "
                   "Storage.storage() or Storage.storage(app:) instead");
  return nil;
}

#pragma mark - NSObject overrides

- (instancetype)copyWithZone:(NSZone *)zone {
  FIRIMPLStorage *storage = [[[self class] allocWithZone:zone] initWithApp:_app
                                                                    bucket:_storageBucket
                                                                      auth:_auth
                                                                  appCheck:_appCheck];
  storage.callbackQueue = self.callbackQueue;
  return storage;
}

// Two FIRStorage objects are equal if they use the same app
- (BOOL)isEqual:(id)object {
  if (self == object) {
    return YES;
  }

  if (![object isKindOfClass:[FIRIMPLStorage class]]) {
    return NO;
  }

  BOOL isEqualObject = [self isEqualToFIRStorage:(FIRIMPLStorage *)object];
  return isEqualObject;
}

- (BOOL)isEqualToFIRStorage:(FIRIMPLStorage *)storage {
  BOOL isEqual =
      [_app isEqual:storage.app] && [_storageBucket isEqualToString:storage.storageBucket];
  return isEqual;
}

- (NSUInteger)hash {
  NSUInteger hash = [_app hash] ^ [self.callbackQueue hash];
  return hash;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"%@ %p: %@", [self class], self, _app];
}

#pragma mark - Retry time intervals

- (void)setMaxUploadRetryTime:(NSTimeInterval)maxUploadRetryTime {
  @synchronized(self) {
    _maxUploadRetryTime = maxUploadRetryTime;
    _maxUploadRetryInterval =
        [FIRStorageUtils computeRetryIntervalFromRetryTime:maxUploadRetryTime];
  }
}

- (NSTimeInterval)maxDownloadRetryTime {
  @synchronized(self) {
    return _maxDownloadRetryTime;
  }
}

- (void)setMaxDownloadRetryTime:(NSTimeInterval)maxDownloadRetryTime {
  @synchronized(self) {
    _maxDownloadRetryTime = maxDownloadRetryTime;
    _maxDownloadRetryInterval =
        [FIRStorageUtils computeRetryIntervalFromRetryTime:maxDownloadRetryTime];
  }
}

- (NSTimeInterval)maxUploadRetryTime {
  @synchronized(self) {
    return _maxUploadRetryTime;
  }
}

- (void)setMaxOperationRetryTime:(NSTimeInterval)maxOperationRetryTime {
  @synchronized(self) {
    _maxOperationRetryTime = maxOperationRetryTime;
    _maxOperationRetryInterval =
        [FIRStorageUtils computeRetryIntervalFromRetryTime:maxOperationRetryTime];
  }
}

- (NSTimeInterval)maxOperationRetryTime {
  @synchronized(self) {
    return _maxOperationRetryTime;
  }
}

#pragma mark - Public methods

- (FIRIMPLStorageReference *)reference {
  [self ensureConfigured];

  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:_storageBucket object:nil];
  return [[FIRIMPLStorageReference alloc] initWithStorage:self path:path];
}

- (FIRIMPLStorageReference *)referenceForURL:(NSString *)string {
  [self ensureConfigured];

  FIRStoragePath *path = [FIRStoragePath pathFromString:string];

  // If no default bucket exists (empty string), accept anything.
  if ([_storageBucket isEqual:@""]) {
    FIRIMPLStorageReference *reference = [[FIRIMPLStorageReference alloc] initWithStorage:self
                                                                                     path:path];
    return reference;
  }

  // If there exists a default bucket, throw if provided a different bucket.
  if (![path.bucket isEqual:_storageBucket]) {
    NSString *const kInvalidBucketFormat =
        @"Provided bucket: %@ does not match the Storage bucket of the current instance: %@";
    [NSException raise:NSInvalidArgumentException
                format:kInvalidBucketFormat, path.bucket, _storageBucket];
  }

  FIRIMPLStorageReference *reference = [[FIRIMPLStorageReference alloc] initWithStorage:self
                                                                                   path:path];
  return reference;
}

- (FIRIMPLStorageReference *)referenceWithPath:(NSString *)string {
  FIRIMPLStorageReference *reference = [[self reference] child:string];
  return reference;
}

- (dispatch_queue_t)callbackQueue {
  [self ensureConfigured];
  return _fetcherServiceForApp.callbackQueue;
}

- (void)setCallbackQueue:(dispatch_queue_t)callbackQueue {
  [self ensureConfigured];
  _fetcherServiceForApp.callbackQueue = callbackQueue;
}

- (void)useEmulatorWithHost:(NSString *)host port:(NSInteger)port {
  if (host.length == 0) {
    [NSException raise:NSInvalidArgumentException format:@"Cannot connect to nil or empty host."];
  }

  if (port < 0) {
    [NSException raise:NSInvalidArgumentException
                format:@"Port must be greater than or equal to zero."];
  }

  if (_fetcherServiceForApp != nil) {
    [NSException raise:NSInternalInconsistencyException
                format:@"Cannot connect to emulator after Storage SDK initialization. "
                       @"Call useEmulator(host:port:) before creating a Storage "
                       @"reference or trying to load data."];
  }

  _usesEmulator = YES;
  _scheme = @"http";
  _host = host;
  _port = @(port);
}

#pragma mark - Background tasks

+ (void)enableBackgroundTasks:(BOOL)isEnabled {
  [NSException raise:NSGenericException format:@"enableBackgroundTasks not implemented"];
}

- (NSArray<FIRIMPLStorageUploadTask *> *)uploadTasks {
  [NSException raise:NSGenericException format:@"getUploadTasks not implemented"];
  return nil;
}

- (NSArray<FIRIMPLStorageDownloadTask *> *)downloadTasks {
  [NSException raise:NSGenericException format:@"getDownloadTasks not implemented"];
  return nil;
}

- (void)ensureConfigured {
  if (!_fetcherServiceForApp) {
    _fetcherServiceForApp = [FIRIMPLStorage fetcherServiceForApp:_app
                                                          bucket:_storageBucket
                                                            auth:_auth
                                                        appCheck:_appCheck];
    if (_usesEmulator) {
      _fetcherServiceForApp.allowLocalhostRequest = YES;
      _fetcherServiceForApp.allowedInsecureSchemes = @[ @"http" ];
    }
  }
}

@end
