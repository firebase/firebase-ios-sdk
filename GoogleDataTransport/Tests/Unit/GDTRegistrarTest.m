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

#import "GDTTestCase.h"

#import <GoogleDataTransport/GDTRegistrar.h>

#import "GDTRegistrar_Private.h"
#import "GDTTestPrioritizer.h"
#import "GDTTestUploader.h"

@interface GDTRegistrarTest : GDTTestCase

@property(nonatomic) GDTLogTarget logTarget;

@end

@implementation GDTRegistrarTest

- (void)setUp {
  [super setUp];
  _logTarget = 23;
}

/** Tests the default initializer. */
- (void)testInit {
  XCTAssertNotNil([[GDTRegistrarTest alloc] init]);
}

/** Test registering an uploader. */
- (void)testRegisterUpload {
  GDTRegistrar *registrar = [GDTRegistrar sharedInstance];
  GDTTestUploader *uploader = [[GDTTestUploader alloc] init];
  XCTAssertNoThrow([registrar registerUploader:uploader logTarget:self.logTarget]);
  XCTAssertEqual(uploader, registrar.logTargetToUploader[@(_logTarget)]);
}

/** Test registering a prioritizer. */
- (void)testRegisterPrioritizer {
  GDTRegistrar *registrar = [GDTRegistrar sharedInstance];
  GDTTestPrioritizer *prioritizer = [[GDTTestPrioritizer alloc] init];
  XCTAssertNoThrow([registrar registerPrioritizer:prioritizer logTarget:self.logTarget]);
  XCTAssertEqual(prioritizer, registrar.logTargetToPrioritizer[@(_logTarget)]);
}

@end
