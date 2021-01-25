//
//  FIRCLSAnalyticsManager.h
//  Pods
//
//  Created by Sam Edson on 1/25/21.
//

#import <Foundation/Foundation.h>

#import "Interop/Analytics/Public/FIRAnalyticsInterop.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRCLSAnalyticsManager : NSObject

- (instancetype)initWithAnalytics:(nullable id<FIRAnalyticsInterop>)analytics;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (void)registerAnalyticsListener;

@end

NS_ASSUME_NONNULL_END
