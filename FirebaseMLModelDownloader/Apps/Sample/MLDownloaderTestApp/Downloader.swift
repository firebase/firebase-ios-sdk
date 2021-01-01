//
//  File.swift
//  MLDownloaderTestApp
//
//  Created by Manjana Chandrasekharan on 12/31/20.
//

import Foundation
import FirebaseMLModelDownloader

class Downloader : ObservableObject {
  @Published var downloadProgress: Float = 0.0
  @Published var selectedModel = "pose-detection"
  @Published var filePath = ""
  @Published var error = ""
  @Published var isDownloaded = false
  @Published var isDeleted = false
  @Published var isError = false
  @Published var modelNames = [String]()
  
  private func resetState() {
    self.isDownloaded = false
    self.isDeleted = false
    self.downloadProgress = 0.0
    self.filePath = ""
    self.error = ""
    self.isError = false
    self.modelNames = []
  }
  
  func downloadModelHelper(downloadType: ModelDownloadType) -> () -> () {
    return {
      self.resetState()
      self.downloadModel(downloadType: downloadType)
    }
  }
  
  func downloadModel(downloadType: ModelDownloadType) {
    let modelDownloader = ModelDownloader.modelDownloader()
    let conditions = ModelDownloadConditions()

    let modelName = self.selectedModel
    modelDownloader.getModel(name: modelName, downloadType: downloadType, conditions: conditions, progressHandler: { progress in
      self.downloadProgress = progress
    }) { result in
      switch result {
      case let .success(model):
        self.isDownloaded = true
        self.filePath = model.path
      case let .failure(error):
        self.isDownloaded = false
        self.isError = true
        self.error = "Model download failed with error: \(error)"
      }
    }
  }
  
  func deleteModelHelper() -> () -> () {
    return {
      self.resetState()
      self.deleteModel()
    }
  }
  
  func deleteModel() {
    let modelDownloader = ModelDownloader.modelDownloader()
    let modelName = self.selectedModel
    modelDownloader.deleteDownloadedModel(name: modelName) { result in
      switch result {
      case .success:
        self.isDeleted = true
        self.isDownloaded = false
        self.filePath = ""
      case let .failure(error):
        self.isDeleted = false
        self.isError = true
        self.error = "Model deletion failed with error: \(error)"
      }
    }
  }
  
  func listModelHelper() -> () -> () {
    return {
      self.resetState()
      self.listModel()
    }
  }
  
  func listModel() {
    let modelDownloader = ModelDownloader.modelDownloader()
    modelDownloader.listDownloadedModels { result in
      switch result {
      case let .success(models):
        for model in models {
          self.modelNames.append(model.name)
        }
      case let .failure(error):
        self.isError = true
        self.error = "Listing models failed with error: \(error)"
      }
    }
  }
}
