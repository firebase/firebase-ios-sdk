//
//  AuthViewController+MultiFactor.swift
//  AuthenticationExample
//
//  Created by Pragati Modi on 17/03/24.
//  Copyright © 2024 Firebase. All rights reserved.
//

import Foundation
import UIKit

class MultiFactorViewController: AuthViewController {
  override func didSelectRowAt(_ indexPath: IndexPath, on tableView: UITableView) {
    let item = dataSourceProvider.item(at: indexPath)
    
    let itemName = item.title!
    
      //    guard let provider = AuthMenu(rawValue: providerName) else {
      //      // The row tapped has no affiliated action.
      //      return
      //    }
    if let mfaOption = MultiFactorMenu(rawValue: itemName) {
      switch mfaOption {
      case .phoneEnroll:
        return
        
      case .totpEnroll:
        return
        
      case .multifactorUnenroll:
        return
      }
    } else {
      return
    }
  }

}
