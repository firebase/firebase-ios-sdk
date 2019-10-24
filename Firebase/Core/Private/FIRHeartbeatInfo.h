//
//  HeartbeatInfo.h
//  AppHost-FirebaseInstanceID-iOS-Unit-Tests
//
//  Created by Vinay Guthal on 10/17/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FIRHeartbeatInfo : NSObject

+ (NSURL *)filePathURLWithName:(NSString *)fileName;

+ (NSInteger) getHeartbeatCode:(NSString *) heartbeatTag;

@end

NS_ASSUME_NONNULL_END
