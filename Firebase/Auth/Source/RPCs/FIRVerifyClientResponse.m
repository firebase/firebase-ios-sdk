/** @file FIRVerifyClientResponse.m
    @brief Firebase Auth SDK
    @copyright Copyright 2017 Google Inc.
    @remarks Use of this SDK is subject to the Google APIs Terms of Service:
        https://developers.google.com/terms/
 */

#import "FIRVerifyClientResponse.h"

NS_ASSUME_NONNULL_BEGIN

@implementation FIRVerifyClientResponse

- (BOOL)setWithDictionary:(NSDictionary *)dictionary
                    error:(NSError *_Nullable *_Nullable)error {
  _receipt = dictionary[@"receipt"];
  _suggestedTimeOutDate = [dictionary[@"suggestedTimeout"] isKindOfClass:[NSString class]] ?
      [NSDate dateWithTimeIntervalSinceNow:[dictionary[@"suggestedTimeout"] doubleValue]] : nil;
  return YES;
}

@end

NS_ASSUME_NONNULL_END
