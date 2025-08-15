import Foundation
/*
 * Copyright 2021 Google LLC
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

import FirebaseCore
import RecaptchaEnterpriseProvider
import AppCheckCore
import FirebaseAppCheckCore

class AppCheckRecaptchaEnterpriseProvider:NSObject, AppCheckProvider{
  private let recaptchaEnterpriseProvider: AppCheckCoreRecaptchaEnterpriseProvider
  
  init(recaptchaEnterpriseProvider: AppCheckCoreRecaptchaEnterpriseProvider) {
    self.recaptchaEnterpriseProvider = recaptchaEnterpriseProvider
    super.init();
  }
  
  convenience init(app: FirebaseApp,siteKey:String) {
    let missingOptionsFields = AppCheckValidator.tokenExchangeMissingFields(in: app.options)
    let recaptchaEnterpriseProvider = AppCheckCoreRecaptchaEnterpriseProvider(
      siteKey:siteKey,
      resourceName:app.resourceName,
      APIKey: app.options.apiKey!,
      requestHooks:[app.heartbeatLogger.requestHook()]   //TODO: Add HeartBeatLogger
    )
    self.init(recaptchaEnterpriseProvider:recaptchaEnterpriseProvider)
    
    if !missingOptionsFields.isEmpty {
      return
    }
  }
  
  func getToken(completion handler: @escaping(AppCheckToken?, Error?)->Void){
    recaptchaEnterpriseProvider.getToken{
token,
error in
    if let error = error {
        handler(nil,error)
      return
      }
      
      if let token=token{
        handler(AppCheckToken(token: token.token, expirationDate: token.expirationDate),nil)
      }else{
        handler(
          nil,
          NSError(domain:"AppCheckProviderError",code:-1,userInfo:[NSLocalizedDescriptionKey:"Internal token missing without an error"])
        )
      }
    }
  }
  
  func getLimitedUseToken(completion handler: @escaping(AppCheckToken?,Error?)->Void){
    recaptchaEnterpriseProvider.getLimitedUseToken {token,error in
      if let error=error{
        handler(nil,error)
        return
      }
      
      if let token=token{
        handler(AppCheckToken(token:token.token,expirationDate:token.expirationDate),nil)
      }else{
        handler(
          nil,
          NSError(domain:"AppCheckProviderError",code:-1,userInfo:[NSLocalizedDescriptionKey:"Internal token missing without an error"])
        )
      }
    }
  }
  
}

