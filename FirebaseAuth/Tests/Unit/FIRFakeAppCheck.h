//
//  FIRFakeAppCheck.h
//  Pods
//
//  Created by Yvonne Cheng on 3/14/23.
//
#import <Foundation/Foundation.h>
#import "FirebaseAppCheck/Interop/FIRAppCheckInterop.h"
#import "FirebaseAppCheck/Interop/FIRAppCheckTokenResultInterop.h"

NS_ASSUME_NONNULL_BEGIN
@interface FIRFakeAppCheck : NSObject <FIRAppCheckInterop>

/** @property tokenDidChangeNotificationName
    @brief A notification with the specified name is sent to the default notification center
   (`NotificationCenter.default`) each time a Firebase app check token is refreshed.
 */
@property(nonatomic, nonnull, readwrite, copy) NSString *tokenDidChangeNotificationName;

/** @property notificationAppNameKey
    @brief `userInfo` key for the FAC token in a notification for `tokenDidChangeNotificationName`.
 */
@property(nonatomic, nonnull, readwrite, copy) NSString *notificationAppNameKey;

/** @property notificationAppNameKey
    @brief `userInfo` key for the `FirebaseApp.name` in a notification for
   `tokenDidChangeNotificationName`.
 */
@property(nonatomic, nonnull, readwrite, copy) NSString *notificationTokenKey;

/** @fn getTokenForcingRefresh:completion:
    @brief A fake appCheck used for dependency injection during testing.
    @param forcingRefresh dtermines if a new token is generated.
    @param completion the handler to update the cache.
 */
- (void)getTokenForcingRefresh:(BOOL)forcingRefresh
                    completion:(nonnull FIRAppCheckTokenHandlerInterop)handler;

@end

NS_ASSUME_NONNULL_END
