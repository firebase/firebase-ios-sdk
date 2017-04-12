/** @file AuthProviders.h
    @brief Firebase Auth SDK Sample App
    @copyright Copyright 2016 Google Inc.
    @remarks Use of this SDK is subject to the Google APIs Terms of Service:
        https://developers.google.com/terms/
 */

#import "googlemac/iPhone/Identity/Firebear/Sample/AuthProviders.h"

#import "googlemac/iPhone/Identity/Firebear/Sample/FacebookAuthProvider.h"
#import "googlemac/iPhone/Identity/Firebear/Sample/GoogleAuthProvider.h"

@implementation AuthProviders

+ (id<AuthProvider>)google {
  static id<AuthProvider> googleAuthProvider;
  if (!googleAuthProvider) {
    googleAuthProvider = [[GoogleAuthProvider alloc] init];
  }
  return googleAuthProvider;
}

+ (id<AuthProvider>)facebook {
  static id<AuthProvider> facebookAuthProvider;
  if (!facebookAuthProvider) {
    facebookAuthProvider = [[FacebookAuthProvider alloc] init];
  }
  return facebookAuthProvider;
}

@end