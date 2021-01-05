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

#import "Crashlytics/Crashlytics/Models/FIRCLSSymbolResolver.h"

#import <XCTest/XCTest.h>

@interface FIRCLSSymbolResolverTests : XCTestCase

@end

@implementation FIRCLSSymbolResolverTests

- (void)setUp {
  [super setUp];
}

- (void)tearDown {
  [super tearDown];
}

- (NSString*)resourcePath {
  return [[NSBundle bundleForClass:[self class]] resourcePath];
}

- (NSString*)pathForResource:(NSString*)name {
  return [[self resourcePath] stringByAppendingPathComponent:name];
}

- (void)testLoadingBinaryImagesWithInvalidFile {
  FIRCLSSymbolResolver* resolver = [[FIRCLSSymbolResolver alloc] init];

  XCTAssertFalse([resolver loadBinaryImagesFromFile:nil]);
  XCTAssertFalse([resolver loadBinaryImagesFromFile:@""]);
}

- (void)testLoadingBinaryImagesWithNullBaseValue {
  FIRCLSSymbolResolver* resolver = [[FIRCLSSymbolResolver alloc] init];

  NSString* binaryImagePath =
      [self pathForResource:@"binary_images_with_null_base_entry.clsrecord"];

  XCTAssert([resolver loadBinaryImagesFromFile:binaryImagePath]);
}

- (void)testLoadingBinaryImagesWithMissingBaseValue {
  FIRCLSSymbolResolver* resolver = [[FIRCLSSymbolResolver alloc] init];

  NSString* binaryImagePath = [self pathForResource:@"binary_images_missing_base_entry.clsrecord"];

  XCTAssert([resolver loadBinaryImagesFromFile:binaryImagePath]);
}

@end
