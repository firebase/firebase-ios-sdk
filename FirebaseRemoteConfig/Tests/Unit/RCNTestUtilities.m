#import "googlemac/iPhone/Config/RemoteConfig/Tests/UnitTestsNew/RCNTestUtilities.h"

NSString *const RCNTestsPerfNamespace = @"fireperf";
NSString *const RCNTestsFIRNamespace = @"firebase";
NSString *const RCNTestsDefaultFIRAppName = @"__FIRAPP_DEFAULT";
NSString *const RCNTestsSecondFIRAppName = @"secondFIRApp";

/// The application support sub-directory that the Remote Config database resides in.
static NSString *const RCNRemoteConfigApplicationSupportSubDirectory = @"Google/RemoteConfig";

@implementation RCNTestUtilities

// Fake a fetch config response.
+ (NSMutableDictionary<NSString *, NSString *> *)
    responseWithNamespaceToConfig:(NSDictionary<NSString *, NSDictionary *> *)namespaceToConfig
                      statusArray:(NSArray *)statusArray {
  // TODO(mandard): Update helper function to replace protobuf and return a JSON response
  return nil;
}

+ (NSMutableArray *)entryArrayWithKeyValuePair:(NSDictionary *)aDictionary {
  NSMutableArray *entryArray = [NSMutableArray array];
  // TODO(mandard): Update helper function to replace protobuf with JSON
  return entryArray;
}

+ (NSString *)generatedTestAppNameForTest:(NSString *)testName {
  // Filter out any characters not valid for FIRApp's naming scheme.
  NSCharacterSet *invalidCharacters = [[NSCharacterSet alphanumericCharacterSet] invertedSet];

  // This will result in a string with the class name, a space, and the test name. We only care
  // about the test name so split it into components and return the last item.
  NSString *friendlyTestName = [testName stringByTrimmingCharactersInSet:invalidCharacters];
  NSArray<NSString *> *components = [friendlyTestName componentsSeparatedByString:@" "];
  return [components lastObject];
}

/// Remote Config database path for test version
+ (NSString *)remoteConfigPathForTestDatabase {
  NSArray<NSString *> *dirPaths =
      NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
  NSString *appSupportPath = dirPaths.firstObject;
  NSArray<NSString *> *components = @[
    appSupportPath, RCNRemoteConfigApplicationSupportSubDirectory,
    [NSString stringWithFormat:@"test-%f.sqlite3", [[NSDate date] timeIntervalSince1970] * 1000]
  ];
  NSString *dbPath = [NSString pathWithComponents:components];
  [RCNTestUtilities removeDatabaseAtPath:dbPath];
  return dbPath;
}

+ (void)removeDatabaseAtPath:(NSString *)DBPath {
  // Remove existing database if exists.
  NSFileManager *fileManager = [NSFileManager defaultManager];
  if ([fileManager fileExistsAtPath:DBPath]) {
    NSError *error;
    [fileManager removeItemAtPath:DBPath error:&error];
  }
}

#pragma mark UserDefaults
/// Remote Config database path for test version
+ (NSString *)userDefaultsSuiteNameForTestSuite {
  NSString *suiteName =
      [NSString stringWithFormat:@"group.%@.test-%f", [NSBundle mainBundle].bundleIdentifier,
                                 [[NSDate date] timeIntervalSince1970] * 1000];
  return suiteName;
}

@end
