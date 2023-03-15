#import "FirebaseAuth/Tests/Unit/FIRFakeAppCheck.h"
#import <Foundation/Foundation.h>
#import "FirebaseAppCheck/Interop/FIRAppCheckTokenResultInterop.h"

/** @var kFakeAppCheckToken
    @brief A fake App Check token.
 */
static NSString *const kFakeAppCheckToken = @"appCheckToken";

#pragma mark - FIRFakeAppCheckResult

/// A fake appCheckResult used for dependency injection during testing.
@interface FIRFakeAppCheckResult : NSObject <FIRAppCheckTokenResultInterop>
@property(nonatomic) NSString *token;
@property(nonatomic, nullable) NSError *error;
@end

@implementation FIRFakeAppCheckResult

@end

@implementation FIRFakeAppCheck

- (void)getTokenForcingRefresh:(BOOL)forcingRefresh
                    completion:(nonnull FIRAppCheckTokenHandlerInterop)completion {
  FIRFakeAppCheckResult *fakeAppCheckResult = [[FIRFakeAppCheckResult alloc] init];
  fakeAppCheckResult.token = kFakeAppCheckToken;
  completion(fakeAppCheckResult);
}

@end
