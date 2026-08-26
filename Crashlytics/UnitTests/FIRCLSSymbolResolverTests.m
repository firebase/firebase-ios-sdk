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

// -loadedBinaryImageForPC: is internal to FIRCLSSymbolResolver, but it is the only way to
// observe which records survived filtering.
@interface FIRCLSSymbolResolver (Testing)
- (NSDictionary*)loadedBinaryImageForPC:(uintptr_t)pc;
@end

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
#if SWIFT_PACKAGE
  NSBundle* bundle = SWIFTPM_MODULE_BUNDLE;
  return [bundle.resourcePath stringByAppendingPathComponent:@"Data"];
#else
  NSBundle* bundle = [NSBundle bundleForClass:[self class]];
  return bundle.resourcePath;
#endif
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

- (void)testLoadingBinaryImagesWithStringBaseValue {
  FIRCLSSymbolResolver* resolver = [[FIRCLSSymbolResolver alloc] init];

  NSString* binaryImagePath =
      [self pathForResource:@"binary_images_with_string_base_entry.clsrecord"];

  XCTAssert([resolver loadBinaryImagesFromFile:binaryImagePath]);

  // The record with the string base covers 0x105a3c000 and up, it should have been skipped.
  XCTAssertNil([resolver loadedBinaryImageForPC:4395000000]);

  XCTAssertNotNil([resolver loadedBinaryImageForPC:4389027840]);
}

@end
