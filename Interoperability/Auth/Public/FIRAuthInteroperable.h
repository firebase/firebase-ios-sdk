#ifndef FIRAuthInteroperable_h
#define FIRAuthInteroperable_h

NS_ASSUME_NONNULL_BEGIN

/** @typedef FIRTokenCallback
 @brief The type of block which gets called when a token is ready.
 */
typedef void (^FIRTokenCallback)(NSString *_Nullable token, NSError *_Nullable error);

/// Common methods for Auth interoperability.
@protocol FIRAuthInteroperable

/// Retrieves the Firebase authentication token, possibly refreshing it if it has expired.
- (void)getTokenForcingRefresh:(BOOL)forceRefresh withCallback:(FIRTokenCallback)callback;

/// Get the current Auth user's UID. Returns nil if there is no user signed in.
- (nullable NSString *)getUserID;

@end

NS_ASSUME_NONNULL_END

#endif /* FIRAuthInteroperable_h */
