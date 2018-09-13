#import <Foundation/Foundation.h>

/// A thread-safe user defaults that uses C functions from CFPreferences.h instead of
/// `NSUserDefaults`. This is to avoid sending an `NSNotification` when it's changed from a
/// background thread to avoid crashing. // TODO: Insert radar number here.
@interface GULUserDefaults : NSObject

/// A shared user defaults similar to +[NSUserDefaults standardUserDefaults] and accesses the same
/// data of the standardUserDefaults.
+ (nonnull GULUserDefaults *)standardUserDefaults;

/// Initializes preferences with a suite name that is the same with the NSUserDefaults' suite name.
/// Both of CFPreferences and NSUserDefaults share the same plist file so their data will exactly
/// the same.
///
/// @param suiteName The name of the suite of the user defaults.
- (nonnull instancetype)initWithSuiteName:(nullable NSString *)suiteName;

#pragma mark - Getters

/// Searches the receiver's search list for a default with the key 'defaultName' and return it. If
/// another process has changed defaults in the search list, NSUserDefaults will automatically
/// update to the latest values. If the key in question has been marked as ubiquitous via a Defaults
/// Configuration File, the latest value may not be immediately available, and the registered value
/// will be returned instead.
- (nullable id)objectForKey:(nonnull NSString *)defaultName;

/// Equivalent to -objectForKey:, except that it will return nil if the value is not an NSArray.
- (nullable NSArray *)arrayForKey:(nonnull NSString *)defaultName;

/// Equivalent to -objectForKey:, except that it will return nil if the value
/// is not an NSDictionary.
- (nullable NSDictionary<NSString *, id> *)dictionaryForKey:(nonnull NSString *)defaultName;

/// Equivalent to -objectForKey:, except that it will convert NSNumber values to their NSString
/// representation. If a non-string non-number value is found, nil will be returned.
- (nullable NSString *)stringForKey:(nonnull NSString *)defaultName;

/// Equivalent to -objectForKey:, except that it converts the returned value to an NSInteger. If the
/// value is an NSNumber, the result of -integerValue will be returned. If the value is an NSString,
/// it will be converted to NSInteger if possible. If the value is a boolean, it will be converted
/// to either 1 for YES or 0 for NO. If the value is absent or can't be converted to an integer, 0
/// will be returned.
- (NSInteger)integerForKey:(nonnull NSString *)defaultName;

/// Similar to -integerForKey:, except that it returns a float, and boolean values will not be
/// converted.
- (float)floatForKey:(nonnull NSString *)defaultName;

/// Similar to -integerForKey:, except that it returns a double, and boolean values will not be
/// converted.
- (double)doubleForKey:(nonnull NSString *)defaultName;

/// Equivalent to -objectForKey:, except that it converts the returned value to a BOOL. If the value
/// is an NSNumber, NO will be returned if the value is 0, YES otherwise. If the value is an
/// NSString, values of "YES" or "1" will return YES, and values of "NO", "0", or any other string
/// will return NO. If the value is absent or can't be converted to a BOOL, NO will be returned.
- (BOOL)boolForKey:(nonnull NSString *)defaultName;

#pragma mark - Setters

/// Immediately stores a value (or removes the value if `nil` is passed as the value) for the
/// provided key in the search list entry for the receiver's suite name in the current user and any
/// host, then asynchronously stores the value persistently, where it is made available to other
/// processes.
- (void)setObject:(nullable id)value forKey:(nonnull NSString *)defaultName;

/// Equivalent to -setObject:forKey: except that the value is converted from a float to an NSNumber.
- (void)setFloat:(float)value forKey:(nonnull NSString *)defaultName;

/// Equivalent to -setObject:forKey: except that the value is converted from a double to an
/// NSNumber.
- (void)setDouble:(double)value forKey:(nonnull NSString *)defaultName;

/// Equivalent to -setObject:forKey: except that the value is converted from an NSInteger to an
/// NSNumber.
- (void)setInteger:(NSInteger)value forKey:(nonnull NSString *)defaultName;

/// Equivalent to -setObject:forKey: except that the value is converted from a BOOL to an NSNumber.
- (void)setBool:(BOOL)value forKey:(nonnull NSString *)defaultName;

#pragma mark - Removing Defaults

/// Equivalent to -[... setObject:nil forKey:defaultName]
- (void)removeObjectForKey:(nonnull NSString *)defaultName;

#pragma mark - Clear data

/// Removes all values from the search list entry specified by 'domainName', the current user, and
/// any host. The change is persistent. Equivalent to -removePersistentDomainForName: of
/// NSUserDefaults.
- (void)clearAllData;

#pragma mark - Save data

/// Blocks the calling thread until all in-progress set operations have completed.
- (void)synchronize;

#ifdef GUL_USER_DEFAULTS_TESTING

/// Returns a dictionary of all the key-value pairs of the user defaults.
- (nullable NSDictionary *)dictionaryRepresentation;

#endif  // GUL_USER_DEFAULTS_TESTING

@end
