/*
 * Copyright 2019 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "UserTableViewCell.h"

@import FirebaseAuth;

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
        if (photoURL == self->_lastPhotoURL) {
          self->_userInfoProfileURLImageView.image = image;
        }
      });
    });
  } else {
    _userInfoProfileURLImageView.image = nil;
  }
}

@end
