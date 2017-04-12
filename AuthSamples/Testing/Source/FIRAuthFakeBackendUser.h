/** @file FIRAuthFakeBackendUser.h
    @brief Firebase Auth SDK
    @copyright Copyright 2015 Google Inc.
    @remarks Use of this SDK is subject to the Google APIs Terms of Service:
        https://developers.google.com/terms/
 */

#import <Foundation/Foundation.h>

@class FIRAuthFakeBackendCredential;

/** @class FIRAuthFakeBackendUser
    @brief Data model for a user.
 */
@interface FIRAuthFakeBackendUser : NSObject

/** @property credentials
    @brief Map of provider IDs to credentials.
 */
@property(nonatomic, copy)
    NSMutableDictionary<NSString *, FIRAuthFakeBackendCredential *> *credentialsByProviderID;

@end
