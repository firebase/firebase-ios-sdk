//
//  FIRHeartbeatInfoTest.m
//  FirebaseCore-iOS-Unit-unit
//
//  Created by Vinay Guthal on 10/23/19.
//

#import <XCTest/XCTest.h>
#import <FirebaseCore/FIRHeartbeatInfo.h>
#import <GoogleUtilities/GULStorageHeartbeat.h>

@interface FIRHeartbeatInfoTest : XCTestCase

@property(nonatomic, strong) GULStorageHeartbeat* dataStorage;

@property(nonatomic, strong) NSMutableDictionary* dictionary;

@end

@implementation FIRHeartbeatInfoTest

- (void)setUp {
  NSString *const kHeartbeatStorageFile = @"HEARTBEAT_INFO_STORAGE";
  self.dataStorage = [[GULStorageHeartbeat alloc]
                                      initWithFileURL:[FIRHeartbeatInfo filePathURLWithName:kHeartbeatStorageFile]];
  self.dictionary = [NSMutableDictionary dictionary];
  NSError *error;
  [self.dataStorage writeDictionary:self.dictionary error:&error];
}

- (void) testCombinedHeartbeat {
  NSInteger heartbeatCode = [FIRHeartbeatInfo getHeartbeatCode:@"fire-iid"];
  XCTAssertEqual(heartbeatCode, 3);
}

- (void) testSdkOnlyHeartbeat {
  NSInteger timeInSeconds = [[NSDate date] timeIntervalSince1970];
  NSError *error;
  self.dictionary[@"GLOBAL"] = [NSString stringWithFormat:@"%ld", timeInSeconds];
  [self.dataStorage writeDictionary:self.dictionary error:&error];
  NSInteger heartbeatCode = [FIRHeartbeatInfo getHeartbeatCode:@"fire-iid"];
  XCTAssertEqual(heartbeatCode, 1);
}

- (void) testGlobalOnlyHeartbeat {
  NSInteger timeInSeconds = [[NSDate date] timeIntervalSince1970];
  NSError *error;
  self.dictionary[@"fire-iid"] = [NSString stringWithFormat:@"%ld", timeInSeconds];
  [self.dataStorage writeDictionary:self.dictionary error:&error];
  NSInteger heartbeatCode = [FIRHeartbeatInfo getHeartbeatCode:@"fire-iid"];
  XCTAssertEqual(heartbeatCode, 2);
}

- (void) testNoHeartbeat {
  NSInteger timeInSeconds = [[NSDate date] timeIntervalSince1970];
  NSError *error;
  self.dictionary[@"fire-iid"] = [NSString stringWithFormat:@"%ld", timeInSeconds];
  self.dictionary[@"GLOBAL"] = [NSString stringWithFormat:@"%ld", timeInSeconds];
  [self.dataStorage writeDictionary:self.dictionary error:&error];
  NSInteger heartbeatCode = [FIRHeartbeatInfo getHeartbeatCode:@"fire-iid"];
  XCTAssertEqual(heartbeatCode, 0);
}


@end
