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

#import <UIKit/UIKit.h>

@class FIRUser;

/** @class UserTableViewCell
    @brief Represents a user in a table view.
 */
@interface UserTableViewCell : UITableViewCell

/** @property userInfoProfileURLImageView
    @brief A UIImageView whose image is set to the user's profile URL.
 */
@property(nonatomic, weak) IBOutlet UIImageView *userInfoProfileURLImageView;

/** @property userInfoDisplayNameLabel
    @brief A UILabel whose text is set to the user's display name.
 */
@property(nonatomic, weak) IBOutlet UILabel *userInfoDisplayNameLabel;

/** @property userInfoEmailLabel
    @brief A UILabel whose text is set to the user's email.
 */
@property(nonatomic, weak) IBOutlet UILabel *userInfoEmailLabel;

/** @property userInfoUserIDLabel
    @brief A UILabel whose text is set to the user's User ID.
 */
@property(nonatomic, weak) IBOutlet UILabel *userInfoUserIDLabel;

/** @property userInfoProviderListLabel
    @brief A UILabel whose text is set to the user's comma-delimited list of federated sign in
        provider IDs.
 */
@property(nonatomic, weak) IBOutlet UILabel *userInfoProviderListLabel;

/** @fn updateContentsWithUser:
    @brief Updates the values of the controls on this table view cell to represent the user.
    @param user The user whose values should be used to populate this cell.
 */
- (void)updateContentsWithUser:(FIRUser *)user;

@end
