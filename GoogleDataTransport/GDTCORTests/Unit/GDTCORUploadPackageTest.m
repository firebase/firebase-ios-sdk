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

#import "GDTCORTests/Unit/GDTCORTestCase.h"

#import <GoogleDataTransport/GDTCORClock.h>
#import <GoogleDataTransport/GDTCOREvent.h>
#import <GoogleDataTransport/GDTCORRegistrar.h>
#import <GoogleDataTransport/GDTCORUploadPackage.h>

#import "GDTCORLibrary/Private/GDTCORUploadPackage_Private.h"

#import "GDTCORTests/Unit/Helpers/GDTCOREventGenerator.h"
#import "GDTCORTests/Unit/Helpers/GDTCORTestPrioritizer.h"
#import "GDTCORTests/Unit/Helpers/GDTCORTestUploadPackage.h"
#import "GDTCORTests/Unit/Helpers/GDTCORTestUploader.h"

@interface GDTCORUploadPackageTest : GDTCORTestCase <NSSecureCoding, GDTCORUploadPackageProtocol>

/** If YES, -packageDelivered:successful was called. */
@property(nonatomic) BOOL packageDeliveredCalledSuccessful;

/** If YES, -packageDeliveryFailed: was called. */
@property(nonatomic) BOOL packageDeliveredCalledFailed;

/** If YES, -packageExpired: was called. */
@property(nonatomic) BOOL packageExpiredCalled;

@end

@implementation GDTCORUploadPackageTest

- (void)setUp {
  [super setUp];
  _packageExpiredCalled = NO;
  _packageDeliveredCalledFailed = NO;
  _packageDeliveredCalledSuccessful = NO;
}

- (void)packageDelivered:(GDTCORUploadPackage *)package successful:(BOOL)successful {
  if (successful) {
    self.packageDeliveredCalledSuccessful = YES;
  } else {
    self.packageDeliveredCalledFailed = YES;
  }
}

- (void)packageExpired:(GDTCORUploadPackage *)package {
  self.packageExpiredCalled = YES;
}

+ (BOOL)supportsSecureCoding {
  return YES;
}

- (void)encodeWithCoder:(nonnull NSCoder *)aCoder {
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)aDecoder {
  return [[[self class] alloc] init];
}

/** Tests the default initializer. */
- (void)testInit {
  XCTAssertNotNil([[GDTCORUploadPackage alloc] initWithTarget:kGDTCORTargetTest]);
}

/** Tests copying indicates that the underlying sets of events can't be changed from underneath. */
- (void)testRegisterUpload {
  GDTCORUploadPackage *uploadPackage =
      [[GDTCORUploadPackage alloc] initWithTarget:kGDTCORTargetTest];
  GDTCORUploadPackage *uploadPackageCopy = [uploadPackage copy];
  XCTAssertNotEqual(uploadPackage, uploadPackageCopy);
  XCTAssertEqualObjects(uploadPackage.events, uploadPackageCopy.events);
  XCTAssertEqualObjects(uploadPackage, uploadPackageCopy);

  uploadPackage.events = [NSSet set];
  uploadPackageCopy = [uploadPackage copy];
  XCTAssertNotEqual(uploadPackage, uploadPackageCopy);
  XCTAssertEqualObjects(uploadPackage.events, uploadPackageCopy.events);
  XCTAssertEqualObjects(uploadPackage, uploadPackageCopy);

  NSMutableSet<GDTCOREvent *> *set = [GDTCOREventGenerator generate3Events];
  uploadPackage.events = set;
  uploadPackageCopy = [uploadPackage copy];
  XCTAssertNotEqual(uploadPackage, uploadPackageCopy);
  GDTCOREvent *newEvent = [[GDTCOREventGenerator generate3Events] anyObject];
  [set addObject:newEvent];
  XCTAssertFalse([uploadPackageCopy.events containsObject:newEvent]);
  XCTAssertNotEqualObjects(uploadPackage.events, uploadPackageCopy.events);
  XCTAssertNotEqualObjects(uploadPackage, uploadPackageCopy);
  [set removeObject:newEvent];
  XCTAssertEqualObjects(uploadPackage.events, uploadPackageCopy.events);
  XCTAssertEqualObjects(uploadPackage, uploadPackageCopy);
}

- (void)testEncoding {
  GDTCORUploadPackage *uploadPackage =
      [[GDTCORUploadPackage alloc] initWithTarget:kGDTCORTargetTest];
  NSMutableSet<GDTCOREvent *> *set = [GDTCOREventGenerator generate3Events];
  uploadPackage.events = set;
  uploadPackage.handler = self;
  NSError *error;
  NSData *packageData = GDTCOREncodeArchive(uploadPackage, nil, &error);
  XCTAssertNil(error);
  XCTAssertNotNil(packageData);
  error = nil;
  GDTCORUploadPackage *recreatedPackage = (GDTCORUploadPackage *)GDTCORDecodeArchive(
      [GDTCORUploadPackage class], nil, packageData, &error);
  XCTAssertNil(error);
  XCTAssertNotNil(recreatedPackage);
  XCTAssertEqualObjects(uploadPackage, recreatedPackage);
}

- (void)testExpiration {
  XCTAssertFalse(self.packageExpiredCalled);
  GDTCORUploadPackage *uploadPackage =
      [[GDTCORUploadPackage alloc] initWithTarget:kGDTCORTargetTest];
  uploadPackage.deliverByTime = [GDTCORClock clockSnapshotInTheFuture:1000];
  uploadPackage.handler = self;
  NSPredicate *pred =
      [NSPredicate predicateWithBlock:^BOOL(id _Nullable evaluatedObject,
                                            NSDictionary<NSString *, id> *_Nullable bindings) {
        return self.packageExpiredCalled;
      }];
  XCTestExpectation *expectation = [self expectationForPredicate:pred
                                             evaluatedWithObject:self
                                                         handler:nil];
  [self waitForExpectations:@[ expectation ] timeout:30];
}

/** Tests that the upload package is not leaked by using an NSTimer. */
- (void)testNoMemoryLeak {
  __weak GDTCORUploadPackage *weakPackage;
  @autoreleasepool {
    GDTCORUploadPackage *package = [[GDTCORUploadPackage alloc] initWithTarget:kGDTCORTargetTest];
    weakPackage = package;
    package = nil;
  }
  XCTAssertNil(weakPackage);
}

@end
