#import <Foundation/Foundation.h>
#import "FIRAppCheckAvailability.h"
#import "FIRAppCheckProvider.h"

@class FIRApp;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(RecaptchaEnterpriseProvider)
@interface FIRRecaptchaEnterpriseProvider : NSObject <FIRAppCheckProvider>

- (instancetype)init NS_UNAVAILABLE;
- (nullable instancetype)initWithApp:(FIRApp *)app siteKey:(NSString *)siteKey;

@end
NS_ASSUME_NONNULL_END
