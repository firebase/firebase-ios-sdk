/** @file GoogleAuthProvider.h
    @brief Firebase Auth SDK Sample App
    @copyright Copyright 2016 Google Inc.
    @remarks Use of this SDK is subject to the Google APIs Terms of Service:
        https://developers.google.com/terms/
 */

#import <UIKit/UIKit.h>

#import "googlemac/iPhone/Identity/Firebear/Sample/AuthProviders.h"

NS_ASSUME_NONNULL_BEGIN

/** @class GoogleAuthProvider
    @brief The implementation for Google auth provider related methods.
 */
@interface GoogleAuthProvider : NSObject <AuthProvider>
@end

NS_ASSUME_NONNULL_END
