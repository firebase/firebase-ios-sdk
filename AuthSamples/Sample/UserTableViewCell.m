/** @file UserTableViewCell.m
    @brief Firebase Auth SDK Sample App
    @copyright Copyright 2015 Google Inc.
    @remarks Use of this SDK is subject to the Google APIs Terms of Service:
        https://developers.google.com/terms/
 */

#import "googlemac/iPhone/Identity/Firebear/Sample/UserTableViewCell.h"

#import "googlemac/iPhone/Identity/Firebear/Auth/Source/FIRUser.h"

@implementation UserTableViewCell {
  /** @var _lastPhotoURL
      @brief Used to make sure only the last requested image is used to update the UIImageView.
   */
  NSURL *_lastPhotoURL;
}

- (void)updateContentsWithUser:(FIRUser *)user {
  _userInfoDisplayNameLabel.text = user.displayName;
  _userInfoEmailLabel.text = user.email;
  _userInfoUserIDLabel.text = user.uid;

  NSMutableArray<NSString *> *providerIDs = [NSMutableArray array];
  for (id<FIRUserInfo> userInfo in user.providerData) {
    [providerIDs addObject:userInfo.providerID];
  }
  _userInfoProviderListLabel.text = [providerIDs componentsJoinedByString:@", "];

  NSURL *photoURL = user.photoURL;
  _lastPhotoURL = photoURL;  // to prevent eariler image overwrites later one.
  if (photoURL) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^() {
      UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:photoURL]];
      dispatch_async(dispatch_get_main_queue(), ^() {
        if (photoURL == _lastPhotoURL) {
          _userInfoProfileURLImageView.image = image;
        }
      });
    });
  } else {
    _userInfoProfileURLImageView.image = nil;
  }
}

@end
