/** @file MainViewController.h
    @brief Firebase Auth SDK Sample App
    @copyright Copyright 2015 Google Inc.
    @remarks Use of this SDK is subject to the Google APIs Terms of Service:
        https://developers.google.com/terms/
 */

#import <UIKit/UIKit.h>

@class StaticContentTableViewManager;
@class UserTableViewCell;

/** @var kCreateUserAccessibilityID
    @brief The "Create User" button accessibility ID.
 */
extern NSString *const kCreateUserAccessibilityID;

/** @class MainViewController
    @brief The first view controller presented when the application is started.
 */
@interface MainViewController : UIViewController

/** @property tableViewManager
    @brief A @c StaticContentTableViewManager which is used to manage the contents of the table
        view.
 */
@property(nonatomic, strong) IBOutlet StaticContentTableViewManager *tableViewManager;

/** @property tableView
    @brief A UITableView which is used to display user info and a list of actions.
 */
@property(nonatomic, weak) IBOutlet UITableView *tableView;

/** @property userInfoTableViewCell
    @brief A custom UITableViewCell for displaying the user info.
 */
@property(nonatomic, strong) IBOutlet UserTableViewCell *userInfoTableViewCell;

/** @property userInMemoryInfoTableViewCell
    @brief A custom UITableViewCell for displaying the user info.
 */
@property(nonatomic, strong) IBOutlet UserTableViewCell *userInMemoryInfoTableViewCell;

/** @property userToUseCell
    @brief A custom UITableViewCell for choosing which user to use for user operations (either the
        currently signed-in user, or the user in "memory".
 */
@property(nonatomic, strong) IBOutlet UITableViewCell *userToUseCell;

/** @property consoleTextView
    @brief A UITextView with a log of the actions performed in the sample app.
 */
@property(nonatomic, weak) IBOutlet UITextView *consoleTextView;

/** @fn userToUseDidChange:
    @brief Should be invoked when the user wishes to switch which user to use for user-related
        operations in the sample app.
    @param sender The UISegmentedControl which prompted the change in value. It is assumed that the
        segment at index 0 represents the "signed-in user" and the segment at index 1 represents the
        "user in memeory".
 */
- (IBAction)userToUseDidChange:(UISegmentedControl *)sender;

/** @fn memoryPlus
    @brief Works like the "M+" button on a calculator; stores the currently signed-in user as the
        "user in memory" for the application.
 */
- (IBAction)memoryPlus;

/** @fn memoryClear
    @brief Works like the "MC" button on a calculator; clears the currently stored "user in memory"
        for the application.
 */
- (IBAction)memoryClear;

@end
