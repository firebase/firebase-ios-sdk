//
//  CustomModel.swift
//  FirebaseMLModelDownloader
//
//  Created by Manjana Chandrasekharan on 9/23/20.
//

import Foundation

enum CustomModelFormat {
  case Unknown
  case TFLite
  case TorchScript
  case CoreML
}

public struct CustomModel {
  let modelName: String
  var modelSize: Int?
  var modelPath: String?
  var modelHash: String?
  var modelFormat = CustomModelFormat.Unknown

  init(withName name: String) {
    modelName = name
  }

  func getLatestModel() -> FileHandle? {
    if let filePath = modelPath, let modelFile = FileHandle(forReadingAtPath: filePath) {
      return modelFile
    } else {
      return nil
    }
  }
}
