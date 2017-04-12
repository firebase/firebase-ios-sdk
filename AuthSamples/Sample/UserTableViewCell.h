/** @file UserTableViewCell.h
    @brief Firebase Auth SDK Sample App
    @copyright Copyright 2015 Google Inc.
    @remarks Use of this SDK is subject to the Google APIs Terms of Service:
        https://developers.google.com/terms/
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
