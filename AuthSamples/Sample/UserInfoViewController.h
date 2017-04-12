/** @file SettingsViewController.h
    @brief Firebase Auth SDK Sample App
    @copyright Copyright 2016 Google Inc.
    @remarks Use of this SDK is subject to the Google APIs Terms of Service:
        https://developers.google.com/terms/
 */


#import <UIKit/UIKit.h>

@class FIRUser;
@class StaticContentTableViewManager;

/** @class UserInfoViewController
    @brief A view controller for displaying @c FIRUser data.
 */
@interface UserInfoViewController : UIViewController

/** @property tableViewManager
    @brief A @c StaticContentTableViewManager which is used to manage the contents of the table
        view.
 */
@property(nonatomic, strong) IBOutlet StaticContentTableViewManager *tableViewManager;

/** @fn initWithUser:
    @biref Initializes with a @c FIRUser instance.
    @param user The user to be displayed in the view.
 */
- (instancetype)initWithUser:(FIRUser *)user NS_DESIGNATED_INITIALIZER;

/** @fn initWithNibName:bundle:
    @brief Not available. Call initWithUser: instead.
 */
- (instancetype)initWithNibName:(NSString *)nibNameOrNil
                         bundle:(NSBundle *)nibBundleOrNil NS_UNAVAILABLE;

/** @fn initWithCoder:
    @brief Not available. Call initWithUser: instead.
 */
- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_UNAVAILABLE;

/** @fn done
    @brief Called when user taps the "Done" button.
 */
- (IBAction)done:(id)sender;

@end
