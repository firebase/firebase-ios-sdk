/** @file NSString+FIRAuth.h
    @brief Firebase Auth SDK
    @copyright Copyright 2017 Google Inc.
    @remarks Use of this SDK is subject to the Google APIs Terms of Service:
        https://developers.google.com/terms/
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/** @category NSString(FIRAuth)
    @brief A FIRAuth category for extending the functionality of NSString for specific Firebase Auth
        use cases.
 */
@interface NSString (FIRAuth)

/** @property fir_authPhoneNumber
    @brief A phone number associated with the verification ID (NSString instance).
    @remarks Allows an instance on NSString to be associated with a phone number in order to link
        phone number with the verificationID returned from verifyPhoneNumber:completion:
 */
@property(nonatomic, strong) NSString *fir_authPhoneNumber;

@end

NS_ASSUME_NONNULL_END
