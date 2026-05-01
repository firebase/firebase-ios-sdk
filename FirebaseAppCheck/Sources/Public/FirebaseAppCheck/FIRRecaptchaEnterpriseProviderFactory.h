#import <Foundation/Foundation.h>
#import "FIRAppCheckProviderFactory.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(RecaptchaEnterpriseProviderFactory)
@interface FIRRecaptchaEnterpriseProviderFactory : NSObject <FIRAppCheckProviderFactory>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithSiteKey:(NSString *)siteKey;

@end
NS_ASSUME_NONNULL_END
