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

#import "GDTTests/Unit/GDTTestCase.h"

#import <GoogleDataTransport/GDTClock.h>
#import <GoogleDataTransport/GDTRegistrar.h>
#import <GoogleDataTransport/GDTUploadPackage.h>

#import "GDTLibrary/Private/GDTUploadPackage_Private.h"

#import "GDTTests/Unit/Helpers/GDTEventGenerator.h"
#import "GDTTests/Unit/Helpers/GDTTestPrioritizer.h"
#import "GDTTests/Unit/Helpers/GDTTestUploadPackage.h"
#import "GDTTests/Unit/Helpers/GDTTestUploader.h"

@interface GDTUploadPackageTest : GDTTestCase <NSSecureCoding, GDTUploadPackageProtocol>

/** If YES, -packageDelivered:successful was called. */
@property(nonatomic) BOOL packageDeliveredCalledSuccessful;

/** If YES, -packageDeliveryFailed: was called. */
@property(nonatomic) BOOL packageDeliveredCalledFailed;

/** If YES, -packageExpired: was called. */
@property(nonatomic) BOOL packageExpiredCalled;

@end

@implementation GDTUploadPackageTest

- (void)setUp {
  [super setUp];
  _packageExpiredCalled = NO;
  _packageDeliveredCalledFailed = NO;
  _packageDeliveredCalledSuccessful = NO;
}

- (void)packageDelivered:(GDTUploadPackage *)package successful:(BOOL)successful {
  if (successful) {
    self.packageDeliveredCalledSuccessful = YES;
  } else {
    self.packageDeliveredCalledFailed = YES;
  }
}

- (void)packageExpired:(GDTUploadPackage *)package {
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
  XCTAssertNotNil([[GDTUploadPackage alloc] initWithTarget:kGDTTargetTest]);
}

/** Tests copying indicates that the underlying sets of events can't be changed from underneath. */
- (void)testRegisterUpload {
  GDTUploadPackage *uploadPackage = [[GDTUploadPackage alloc] initWithTarget:kGDTTargetTest];
  GDTUploadPackage *uploadPackageCopy = [uploadPackage copy];
  XCTAssertNotEqual(uploadPackage, uploadPackageCopy);
  XCTAssertEqualObjects(uploadPackage.events, uploadPackageCopy.events);
  XCTAssertEqualObjects(uploadPackage, uploadPackageCopy);

  uploadPackage.events = [NSSet set];
  uploadPackageCopy = [uploadPackage copy];
  XCTAssertNotEqual(uploadPackage, uploadPackageCopy);
  XCTAssertEqualObjects(uploadPackage.events, uploadPackageCopy.events);
  XCTAssertEqualObjects(uploadPackage, uploadPackageCopy);

  NSMutableSet<GDTStoredEvent *> *set = [GDTEventGenerator generate3StoredEvents];
  uploadPackage.events = set;
  uploadPackageCopy = [uploadPackage copy];
  XCTAssertNotEqual(uploadPackage, uploadPackageCopy);
  GDTStoredEvent *newEvent = [[GDTEventGenerator generate3StoredEvents] anyObject];
  [set addObject:newEvent];
  XCTAssertFalse([uploadPackageCopy.events containsObject:newEvent]);
  XCTAssertNotEqualObjects(uploadPackage.events, uploadPackageCopy.events);
  XCTAssertNotEqualObjects(uploadPackage, uploadPackageCopy);
  [set removeObject:newEvent];
  XCTAssertEqualObjects(uploadPackage.events, uploadPackageCopy.events);
  XCTAssertEqualObjects(uploadPackage, uploadPackageCopy);
}

- (void)testEncoding {
  GDTUploadPackage *uploadPackage = [[GDTUploadPackage alloc] initWithTarget:kGDTTargetTest];
  NSMutableSet<GDTStoredEvent *> *set = [GDTEventGenerator generate3StoredEvents];
  uploadPackage.events = set;
  uploadPackage.handler = self;
  GDTUploadPackage *recreatedPackage;
  NSError *error;

  if (@available(macOS 10.13, iOS 11.0, tvOS 11.0, *)) {
    NSData *packageData = [NSKeyedArchiver archivedDataWithRootObject:uploadPackage
                                                requiringSecureCoding:YES
                                                                error:&error];
    recreatedPackage = [NSKeyedUnarchiver unarchivedObjectOfClass:[GDTUploadPackage class]
                                                         fromData:packageData
                                                            error:&error];
    XCTAssertNil(error);
  } else {
#if !defined(TARGET_OS_MACCATALYST)
    NSData *packageData = [NSKeyedArchiver archivedDataWithRootObject:uploadPackage];
    recreatedPackage = [NSKeyedUnarchiver unarchiveObjectWithData:packageData];
#endif
  }
  XCTAssertEqualObjects(uploadPackage, recreatedPackage);
}

- (void)testExpiration {
  XCTAssertFalse(self.packageExpiredCalled);
  GDTUploadPackage *uploadPackage = [[GDTUploadPackage alloc] initWithTarget:kGDTTargetTest];
  uploadPackage.deliverByTime = [GDTClock clockSnapshotInTheFuture:1000];
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

@end
