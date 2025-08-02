import Foundation
import FirebaseCore
import RecaptchaEnterpriseProvider


class AppCheckRecaptchaEnterpriseProvider:NSObject, AppCheckProvider{
  private let recaptchaEnterpriseProvider: AppCheckCoreRecaptchaEnterpriseProvider
  
  init(recaptchaEnterpriseProvider: AppCheckCoreRecaptchaEnterpriseProvider) {
    self.recaptchaEnterpriseProvider = recaptchaEnterpriseProvider
    super.init();
  }
  
  convenience init(app: FirebaseApp,siteKey:String) {
    let missingOptionsFields = AppCheckValidator.tokenExchangeMissingFields(in: app.options)
    
//    if !missingOptionsFields.isEmpty {
////      ("AppCheck",
////      "RecaptchaEnterpriseIncompleteFIROptions",
////      "Cannot instantiate 'AppCheckRecaptchaEnterpriseProvider' for app: @. The following 'FirebaseOptions' fields are missing: @",
////                  app.name, missingOptionsFields.joined(separator: ", "))
//      return
//    }
    let recaptchaEnterpriseProvider = AppCheckCoreRecaptchaEnterpriseProvider(
      siteKey:siteKey,
      resourceName:app.name,
      APIKey: app.options.apiKey!,
      requestHooks:[/*app.heartbeatLogger.requestHook()*/]   //TODO: Add HeartBeatLogger
    )
    self.init(recaptchaEnterpriseProvider:recaptchaEnterpriseProvider)
    
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

