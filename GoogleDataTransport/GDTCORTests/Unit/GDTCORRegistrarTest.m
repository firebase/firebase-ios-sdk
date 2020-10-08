/*
 * Copyright 2018 Google
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

#import "GoogleDataTransport/GDTCORTests/Unit/GDTCORTestCase.h"

#import "GoogleDataTransport/GDTCORLibrary/Internal/GDTCORRegistrar.h"

#import "GoogleDataTransport/GDTCORLibrary/Private/GDTCORRegistrar_Private.h"
#import "GoogleDataTransport/GDTCORTests/Unit/Helpers/GDTCORTestUploader.h"

@interface GDTCORRegistrarTest : GDTCORTestCase

@property(nonatomic) GDTCORTarget target;

@end

@implementation GDTCORRegistrarTest

- (void)setUp {
  [super setUp];
  _target = kGDTCORTargetTest;
}

/** Tests the default initializer. */
- (void)testInit {
  XCTAssertNotNil([[GDTCORRegistrarTest alloc] init]);
}

/** Test registering an uploader. */
- (void)testRegisterUpload {
  GDTCORRegistrar *registrar = [GDTCORRegistrar sharedInstance];
  GDTCORTestUploader *uploader = [[GDTCORTestUploader alloc] init];
  XCTAssertNoThrow([registrar registerUploader:uploader target:self.target]);
  XCTAssertEqual(uploader, registrar.targetToUploader[@(_target)]);
}

// TODO(mikehaney24): Add test for registering a storage.

@end
