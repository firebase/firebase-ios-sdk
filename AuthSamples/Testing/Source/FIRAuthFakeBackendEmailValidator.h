/** @file FIRAuthFakeBackendEmailValidator.h
    @brief Firebase Auth SDK
    @copyright Copyright 2015 Google Inc.
    @remarks Use of this SDK is subject to the Google APIs Terms of Service:
        https://developers.google.com/terms/
 */

#import <Foundation/Foundation.h>

/** @class FIRAuthFakeBackendEmailValidator
    @brief This class provides validation for internationalized email addresses as defined by
        RFC6530.
 */
@interface FIRAuthFakeBackendEmailValidator : NSObject

/** @fn isValidEmailAddress:
    @brief Validates an email address string conforms to RFC6530.
    @param emailAddress
    @return YES if @c emailAddress is spec-compliant. NO otherwise.
 */
+ (BOOL)isValidEmailAddress:(NSString *)emailAddress;

@end
