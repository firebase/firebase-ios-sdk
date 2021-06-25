// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Non-google3 relative import to support building with Xcode.
#import "NetworkConnectionsFactory.h"
#import "../Models/PerfLogger.h"

static NSString *const kNetworkConnectionsConfigurationFileType = @"plist";

@implementation NetworkConnectionsFactory

+ (NSDictionary<NSString *, id<NetworkConnection>> *)titleConnectionPairsFromConfigFile:
    (NSString *)fileName {
  NSString *path = [[NSBundle mainBundle] pathForResource:fileName
                                                   ofType:kNetworkConnectionsConfigurationFileType];

  NSDictionary<NSString *, NSString *> *classesNamesAndURLs =
      [NSDictionary dictionaryWithContentsOfFile:path];

  NSMutableDictionary *resultDict = [[NSMutableDictionary alloc] init];

  [classesNamesAndURLs enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull className,
                                                           NSString *_Nonnull URLString,
                                                           BOOL *_Nonnull stop) {
    id<NetworkConnection> connection =
        (id<NetworkConnection>)[[NSClassFromString(className) alloc] initWithURLString:URLString];
    PerfLog(@"connection %@ initialized", className);
    resultDict[className] = connection;
  }];

  return resultDict;
}

@end
