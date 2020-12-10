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

#import <XCTest/XCTest.h>

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"
#import "FirebaseSegmentation/Sources/Public/FIRSegmentation.h"

@interface FIRSegmentation (ForTest)
- (instancetype)initWithAppName:(NSString *)appName FIROptions:(FIROptions *)options;
@end

@interface SEGInitializationTests : XCTestCase {
  FIRSegmentation *_segmentation;
}

@end

@implementation SEGInitializationTests

- (void)setUp {
  FIROptions *options = [[FIROptions alloc] initInternalWithOptionsDictionary:@{
    @"API_KEY" : @"AIzaSy-ApiKeyWithValidFormat_0123456789",
    @"PROJECT_ID" : @"test-firebase-project-id",
  }];
  options.APIKey = @"AIzaSy-ApiKeyWithValidFormat_0123456789";
  options.projectID = @"test-firebase-project-id";
  _segmentation = [[FIRSegmentation alloc] initWithAppName:@"test-firebase-app-name"
                                                FIROptions:options];
}

- (void)tearDown {
  // Put teardown code here. This method is called after the invocation of each test method in the
  // class.
}

- (void)testExample {
  [_segmentation setCustomInstallationID:@"test-custom-id"
                              completion:^(NSError *error){

                              }];
}

@end
