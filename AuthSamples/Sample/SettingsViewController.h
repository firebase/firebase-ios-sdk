/** @file SettingsViewController.h
    @brief Firebase Auth SDK Sample App
    @copyright Copyright 2016 Google Inc.
    @remarks Use of this SDK is subject to the Google APIs Terms of Service:
        https://developers.google.com/terms/
 */


#import <UIKit/UIKit.h>

@class StaticContentTableViewManager;

/** @class SettingsViewController
    @brief A view controller for sample app info and settings.
 */
@interface SettingsViewController : UIViewController

/** @property tableViewManager
    @brief A @c StaticContentTableViewManager which is used to manage the contents of the table
        view.
 */
@property(nonatomic, strong) IBOutlet StaticContentTableViewManager *tableViewManager;

/** @fn done
    @brief Called when user taps the "Done" button.
 */
- (IBAction)done:(id)sender;

@end
