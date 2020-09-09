//
//  FIRFirebaseUserAgent.h
//  Pods
//
//  Created by Maksym Malyhin on 2020-09-09.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FIRFirebaseUserAgent : NSObject

- (NSString *)firebaseUserAgent;

- (void)setValue:(NSString *)value forComponent:(NSString *)componentName;

- (void)reset;

@end

NS_ASSUME_NONNULL_END
