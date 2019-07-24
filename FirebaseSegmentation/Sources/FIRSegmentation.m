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

#import "FIRAppInternal.h"
#import "FIRComponentContainer.h"
#import "FIROptionsInternal.h"
#import "FIRLogger.h"
#import "FIRSegmentationComponent.h"

FIRLoggerService kFIRLoggerSegmentation = @"[Firebase/Segmentation]";

@implementation FIRSegmentation {
  NSString *_appName;
}

+ (nonnull FIRSegmentation *)segmentation {
  if (![FIRApp isDefaultAppConfigured]) {
    FIRLogError(kFIRLoggerSegmentation,
                @"I-SEG000001",
                @"FIRApp not configured. Please make sure you have called [FIRApp configure]");
  }

  return [FIRSegmentation segmentationWithApp:[FIRApp defaultApp]];
}

+ (nonnull FIRSegmentation *)segmentationWithApp:(nonnull FIRApp *)firebaseApp {
  // Use the provider to generate and return instances of FIRRemoteConfig for this specific app and
  // namespace. This will ensure the app is configured before Remote Config can return an instance.
  id<FIRSegmentationProvider> provider = FIR_COMPONENT(FIRSegmentationProvider,
                                                       firebaseApp.container);
  return [provider segmentation];
}

- (void)setCustomInstallationID:(NSString *)customInstallationID
                     completion:(void (^)(NSError *))completionHandler {

}

/// Designated initializer
- (instancetype)initWithAppName:(NSString *)appName
                     FIROptions:(FIROptions *)options {
  self = [super init];
  if (self) {
    _appName = appName;
  }
  return self;
}
@end
