#import <XCTest/XCTest.h>
#import "FIRDiagnosticsDateFileStorage.h"

@interface FIRDiagnosticsDateFileStorageTests : XCTestCase
@property(nonatomic) NSURL *fileURL;
@property(nonatomic) FIRDiagnosticsDateFileStorage *storage;
@end

@implementation FIRDiagnosticsDateFileStorageTests

- (void)setUp {
  NSString *documentsPath =
      [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES)
          firstObject];
  XCTAssertNotNil(documentsPath);
  NSURL *documentsURL = [NSURL fileURLWithPath:documentsPath];
  self.fileURL = [documentsURL URLByAppendingPathComponent:@"FIRDiagnosticsDateFileStorageTests"
                                               isDirectory:NO];

  NSError *error;
  if (![documentsURL checkResourceIsReachableAndReturnError:&error]) {
    XCTAssert([[NSFileManager defaultManager] createDirectoryAtURL:documentsURL
                                       withIntermediateDirectories:YES
                                                        attributes:nil
                                                             error:&error], @"Error: %@", error);
  }

  self.storage = [[FIRDiagnosticsDateFileStorage alloc] initWithFileURL:self.fileURL];
}

- (void)tearDown {
  [[NSFileManager defaultManager] removeItemAtURL:self.fileURL error:nil];
  self.fileURL = nil;
  self.storage = nil;
}

- (void)testDateStorage {
  NSDate *dateToSave = [NSDate date];

  XCTAssertNil([self.storage date]);

  NSError *error;
  XCTAssertTrue([self.storage setDate:dateToSave error:&error]);

  XCTAssertEqualObjects([self.storage date], dateToSave);

  XCTAssertTrue([self.storage setDate:nil error:&error]);
  XCTAssertNil([self.storage date]);
}

- (void)testDateIsStoredToFileSystem {
  NSDate *date = [NSDate date];

  NSError *error;
  XCTAssert([self.storage setDate:date error:&error], @"Error: %@", error);

  FIRDiagnosticsDateFileStorage *anotherStorage =
      [[FIRDiagnosticsDateFileStorage alloc] initWithFileURL:self.fileURL];

  XCTAssertEqualObjects([anotherStorage date], date);
}

@end
