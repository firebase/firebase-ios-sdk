//
//  GACAppCheckTokenDelegate.h
//  AppCheck
//
//  Created by Andrew Heard on 2023-06-19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol GACAppCheckTokenDelegate <NSObject>

- (void)didUpdateWithToken:(NSString *)token;

@end

NS_ASSUME_NONNULL_END
