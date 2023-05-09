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

#import <XCTest/XCTest.h>

#import "AppCheck/Sources/Public/AppCheck/GACAppCheckDebugProvider.h"
#import "AppCheck/Sources/Public/AppCheck/GACAppCheckDebugProviderFactory.h"

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

@interface GACAppCheckDebugProviderFactoryTests : XCTestCase
@end

@implementation GACAppCheckDebugProviderFactoryTests

- (void)testCreateProviderWithApp {
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:@"app_id" GCMSenderID:@"sender_id"];
  options.APIKey = @"api_key";
  options.projectID = @"project_id";
  FIRApp *app = [[FIRApp alloc] initInstanceWithName:@"testInitWithValidApp" options:options];

  GACAppCheckDebugProviderFactory *factory = [[GACAppCheckDebugProviderFactory alloc] init];

  GACAppCheckDebugProvider *createdProvider = [factory createProviderWithApp:app];

  XCTAssert([createdProvider isKindOfClass:[GACAppCheckDebugProvider class]]);
  XCTAssertNotNil([createdProvider currentDebugToken]);
}

@end
