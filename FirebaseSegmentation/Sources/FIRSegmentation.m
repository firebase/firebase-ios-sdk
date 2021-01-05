// Copyright 2019 Google
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

#import "FirebaseSegmentation/Sources/Public/FIRSegmentation.h"

#import "FirebaseCore/Sources/Private/FIRComponentContainer.h"
#import "FirebaseCore/Sources/Private/FIRLogger.h"
#import "FirebaseCore/Sources/Private/FIROptionsInternal.h"
#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"
#import "FirebaseSegmentation/Sources/Private/FIRSegmentationComponent.h"
#import "FirebaseSegmentation/Sources/SEGContentManager.h"

@implementation FIRSegmentation {
  NSString *_firebaseAppName;
  SEGContentManager *_contentManager;
}

+ (nonnull FIRSegmentation *)segmentation {
  if (![FIRApp isDefaultAppConfigured]) {
    [NSException
         raise:kFirebaseSegmentationErrorDomain
        format:@"FIRApp not configured. Please make sure you have called [FIRApp configure]"];
  }

  return [FIRSegmentation segmentationWithApp:[FIRApp defaultApp]];
}

+ (nonnull FIRSegmentation *)segmentationWithApp:(nonnull FIRApp *)firebaseApp {
  // Use the provider to generate and return instances of FIRSegmentation for this specific app and
  // namespace. This will ensure the app is configured before Remote Config can return an instance.
  id<FIRSegmentationProvider> provider =
      FIR_COMPONENT(FIRSegmentationProvider, firebaseApp.container);
  return [provider segmentation];
}

- (void)setCustomInstallationID:(NSString *)customInstallationID
                     completion:(void (^)(NSError *))completionHandler {
  [_contentManager
      associateCustomInstallationIdentiferNamed:customInstallationID
                                    firebaseApp:_firebaseAppName
                                     completion:^(BOOL success, NSDictionary *result) {
                                       if (!success) {
                                         // TODO(dmandar) log; pass along internal error code.
                                         NSError *error = [NSError
                                             errorWithDomain:kFirebaseSegmentationErrorDomain
                                                        code:FIRSegmentationErrorCodeInternal
                                                    userInfo:result];
                                         completionHandler(error);
                                       } else {
                                         completionHandler(nil);
                                       }
                                     }];
}

/// Designated initializer
- (instancetype)initWithAppName:(NSString *)appName FIROptions:(FIROptions *)options {
  self = [super init];
  if (self) {
    _firebaseAppName = appName;

    // Initialize the content manager.
    _contentManager = [SEGContentManager sharedInstanceWithOptions:options];
  }
  return self;
}

@end
