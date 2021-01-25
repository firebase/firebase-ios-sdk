//
//  FIRCLSNotificationManager.h
//  Pods
//
//  Created by Sam Edson on 1/25/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FIRCLSNotificationManager : NSObject

+ (instancetype)new NS_UNAVAILABLE;

- (void)registerNotificationListener;

@end

NS_ASSUME_NONNULL_END
