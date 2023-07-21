/*
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "AppCheckCore/Sources/Core/Storage/GACAppCheckStoredToken+GACAppCheckToken.h"

#import "AppCheckCore/Sources/Public/AppCheckCore/GACAppCheckToken.h"

@implementation GACAppCheckStoredToken (GACAppCheckToken)

- (void)updateWithToken:(GACAppCheckToken *)token {
  self.token = token.token;
  self.expirationDate = token.expirationDate;
  self.receivedAtDate = token.receivedAtDate;
}

- (GACAppCheckToken *)appCheckToken {
  return [[GACAppCheckToken alloc] initWithToken:self.token
                                  expirationDate:self.expirationDate
                                  receivedAtDate:self.receivedAtDate];
}

@end
