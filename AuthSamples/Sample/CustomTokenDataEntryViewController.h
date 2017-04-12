/** @file CustomTokenDataEntryViewController.h
    @brief Firebase Auth SDK Sample App
    @copyright Copyright 2015 Google Inc.
    @remarks Use of this SDK is subject to the Google APIs Terms of Service:
        https://developers.google.com/terms/
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/** @typedef CustomTokenDataEntryViewControllerCompletion
    @brief The type of callback block invoked when a @c CustomTokenDataEntryViewController is
        dismissed (by either being cancelled or completed by the user.)
    @param cancelled Indicates the user cancelled the flow and didn't want to enter a token.
    @param userEnteredTokenText The token text the user entered.
 */
typedef void (^CustomTokenDataEntryViewControllerCompletion)
    (BOOL cancelled, NSString *_Nullable userEnteredTokenText);

/** @class CustomTokenDataEntryViewController
    @brief Simple view controller to allow data entry of custom BYOAuth tokens.
 */
@interface CustomTokenDataEntryViewController : UIViewController

/** @fn initWithNibName:bundle:
    @brief Please use initWithCompletion:
 */
- (instancetype)initWithNibName:(NSString *_Nullable)nibNameOrNil
                         bundle:(NSBundle *_Nullable)nibBundleOrNil NS_UNAVAILABLE;

/** @fn initWithCoder:
    @brief Please use initWithCompletion:
 */
- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_UNAVAILABLE;

/** @fn initWithCompletion:
    @brief Designated initializer.
    @param completion A block which will be invoked when the user either chooses "cancel" or "done".
 */
- (nullable instancetype)initWithCompletion:
    (CustomTokenDataEntryViewControllerCompletion)completion NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
