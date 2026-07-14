// Copyright 2026 Google LLC
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

import Foundation


extension GoogleAI {
  /// Tool details that the model may use to generate response. A `Tool` is a piece of code that enables the system to interact with external systems to perform an action, or set of actions, outside of knowledge and scope of the model. Next ID: 16
  public struct Tool: Codable, Sendable, Equatable, Hashable {
    /// Optional. Enables the model to execute code as part of generation.
    public var codeExecution: CodeExecution?
    
    /// Optional. Tool to support the model interacting directly with the computer. If enabled, it automatically populates computer-use specific Function Declarations.
    public var computerUse: ComputerUse?
    
    /// Optional. FileSearch tool type. Tool to retrieve knowledge from Semantic Retrieval corpora.
    public var fileSearch: FileSearch?
    
    /// Optional. A list of `FunctionDeclarations` available to the model that can be used for function calling. The model or system does not execute the function. Instead the defined function may be returned as a FunctionCall with arguments to the client side for execution. The model may decide to call a subset of these functions by populating FunctionCall in the response. The next conversation turn may contain a FunctionResponse with the Content.role "function" generation context for the next model turn.
    public var functionDeclarations: [FunctionDeclaration]?
    
    /// Optional. Tool that allows grounding the model's response with geospatial context related to the user's query.
    public var googleMaps: GoogleMaps?
    
    /// Optional. GoogleSearch tool type. Tool to support Google Search in Model. Powered by Google.
    public var googleSearch: GoogleSearch?
    
    /// Optional. Retrieval tool that is powered by Google search.
    public var googleSearchRetrieval: GoogleSearchRetrieval?
    
    /// Optional. MCP Servers to connect to.
    public var mcpServers: [McpServer]?
    
    /// Optional. Tool to support URL context retrieval.
    public var urlContext: UrlContext?
    
    /// Creates a new `Tool`.
    public init(
      codeExecution: CodeExecution? = nil,
      computerUse: ComputerUse? = nil,
      fileSearch: FileSearch? = nil,
      functionDeclarations: [FunctionDeclaration]? = nil,
      googleMaps: GoogleMaps? = nil,
      googleSearch: GoogleSearch? = nil,
      googleSearchRetrieval: GoogleSearchRetrieval? = nil,
      mcpServers: [McpServer]? = nil,
      urlContext: UrlContext? = nil
    ) {
      self.codeExecution = codeExecution
      self.computerUse = computerUse
      self.fileSearch = fileSearch
      self.functionDeclarations = functionDeclarations
      self.googleMaps = googleMaps
      self.googleSearch = googleSearch
      self.googleSearchRetrieval = googleSearchRetrieval
      self.mcpServers = mcpServers
      self.urlContext = urlContext
    }
    enum CodingKeys: String, CodingKey {
      case codeExecution = "codeExecution"
      case computerUse = "computerUse"
      case fileSearch = "fileSearch"
      case functionDeclarations = "functionDeclarations"
      case googleMaps = "googleMaps"
      case googleSearch = "googleSearch"
      case googleSearchRetrieval = "googleSearchRetrieval"
      case mcpServers = "mcpServers"
      case urlContext = "urlContext"
    }
  }
}