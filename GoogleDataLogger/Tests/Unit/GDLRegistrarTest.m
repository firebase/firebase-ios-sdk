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

#import "GDLTestCase.h"

#import <GoogleDataLogger/GDLRegistrar.h>

#import "GDLRegistrar_Private.h"
#import "GDLTestPrioritizer.h"
#import "GDLTestUploader.h"

@interface GDLRegistrarTest : GDLTestCase

@property(nonatomic) GDLLogTarget logTarget;

@end

@implementation GDLRegistrarTest

- (void)setUp {
  [super setUp];
  _logTarget = 23;
}

/** Tests the default initializer. */
- (void)testInit {
  XCTAssertNotNil([[GDLRegistrarTest alloc] init]);
}

/** Test registering an uploader. */
- (void)testRegisterUpload {
  GDLRegistrar *registrar = [GDLRegistrar sharedInstance];
  GDLTestUploader *uploader = [[GDLTestUploader alloc] init];
  XCTAssertNoThrow([registrar registerUploader:uploader logTarget:self.logTarget]);
  XCTAssertEqual(uploader, registrar.logTargetToUploader[@(_logTarget)]);
}

/** Test registering a prioritizer. */
- (void)testRegisterPrioritizer {
  GDLRegistrar *registrar = [GDLRegistrar sharedInstance];
  GDLTestPrioritizer *prioritizer = [[GDLTestPrioritizer alloc] init];
  XCTAssertNoThrow([registrar registerPrioritizer:prioritizer logTarget:self.logTarget]);
  XCTAssertEqual(prioritizer, registrar.logTargetToPrioritizer[@(_logTarget)]);
}

@end
