/*
 * Copyright 2023 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <Foundation/Foundation.h>

#import "FIRMultiFactorInfo.h"

NS_ASSUME_NONNULL_BEGIN

/**
 @class TOTPSecret
 */
NS_SWIFT_NAME(TOTPSecret)
@interface FIRTOTPSecret : NSObject

/**
 @brief Returns the shared secret key/seed used to generate time-based one-time passwords.
 */
- (NSString *)sharedSecretKey;

/**
 @brief Returns a QRCode URL as described in
 https://github.com/google/google-authenticator/wiki/Key-Uri-Format
 This can be displayed to the user as a QRCode to be scanned into a TOTP app like Google
 Authenticator.

 @param accountName the name of the account/app.
 @param issuer issuer of the TOTP(likely the app name).
 @returns A QRCode URL string.
 */
- (NSString *)generateQRCodeURLWithAccountName:(NSString *)accountName issuer:(NSString *)issuer;

/**
 @brief Opens the specified QR Code URL in a password manager like iCloud Keychain.
 * See more details here:
 https://developer.apple.com/documentation/authenticationservices/securing_logins_with_icloud_keychain_verification_codes
 */
- (void)openInOTPAppWithQRCodeURL:(NSString *)QRCodeURL;

@end

NS_ASSUME_NONNULL_END
