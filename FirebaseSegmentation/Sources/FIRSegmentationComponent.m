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

#import "FirebaseSegmentation/Sources/Private/FIRSegmentationComponent.h"

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"
#import "FirebaseSegmentation/Sources/Private/FIRSegmentationInternal.h"
#import "FirebaseSegmentation/Sources/SEGSegmentationConstants.h"

@implementation FIRSegmentationComponent

/// Default method for retrieving a Segmentation instance, or creating one if it doesn't exist.
- (FIRSegmentation *)segmentation {
  // Validate the required information is available.
  FIROptions *options = self.app.options;
  NSString *errorPropertyName;
  if (options.googleAppID.length == 0) {
    errorPropertyName = @"googleAppID";
  } else if (options.GCMSenderID.length == 0) {
    errorPropertyName = @"GCMSenderID";
  }

  if (errorPropertyName) {
    [NSException
         raise:kFirebaseSegmentationErrorDomain
        format:@"%@",
               [NSString
                   stringWithFormat:
                       @"Firebase Segmentation is missing the required %@ property from the "
                       @"configured FirebaseApp and will not be able to function properly. Please "
                       @"fix this issue to ensure that Firebase is correctly configured.",
                       errorPropertyName]];
  }

  FIRSegmentation *instance = self.segmentationInstance;
  if (!instance) {
    instance = [[FIRSegmentation alloc] initWithAppName:self.app.name FIROptions:self.app.options];
    self.segmentationInstance = instance;
  }

  return instance;
}

/// Default initializer.
- (instancetype)initWithApp:(FIRApp *)app {
  self = [super init];
  if (self) {
    _app = app;
    if (!_segmentationInstance) {
      _segmentationInstance = [[FIRSegmentation alloc] initWithAppName:app.name
                                                            FIROptions:app.options];
    }
  }
  return self;
}

#pragma mark - Lifecycle

+ (void)load {
  // Register as an internal library to be part of the initialization process. The name comes from
  // go/firebase-sdk-platform-info.
  [FIRApp registerInternalLibrary:self withName:@"fire-seg"];
}

#pragma mark - Interoperability

+ (NSArray<FIRComponent *> *)componentsToRegister {
  FIRComponent *segProvider = [FIRComponent
      componentWithProtocol:@protocol(FIRSegmentationProvider)
        instantiationTiming:FIRInstantiationTimingAlwaysEager
               dependencies:@[]
              creationBlock:^id _Nullable(FIRComponentContainer *container, BOOL *isCacheable) {
                // Cache the component so instances of Segmentation are cached.
                *isCacheable = YES;
                return [[FIRSegmentationComponent alloc] initWithApp:container.app];
              }];
  return @[ segProvider ];
}

@synthesize instances;

@end
