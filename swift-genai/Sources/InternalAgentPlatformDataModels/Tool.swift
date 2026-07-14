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


extension AgentPlatform {
  /// Tool details that the model may use to generate response. A `Tool` is a piece of code that enables the system to interact with external systems to perform an action, or set of actions, outside of knowledge and scope of the model. A Tool object should contain exactly one type of Tool (e.g FunctionDeclaration, Retrieval or GoogleSearchRetrieval).
  public struct Tool: Codable, Sendable, Equatable, Hashable {
    /// Optional. CodeExecution tool type. Enables the model to execute code as part of generation.
    public var codeExecution: ToolCodeExecution?
    
    /// Optional. Tool to support the model interacting directly with the computer. If enabled, it automatically populates computer-use specific Function Declarations.
    public var computerUse: ToolComputerUse?
    
    /// Optional. Tool to support searching public web data, powered by Vertex AI Search and Sec4 compliance.
    public var enterpriseWebSearch: EnterpriseWebSearch?
    
    /// Optional. Uses Exa.ai to search for information to answer user queries. The search results will be grounded on Exa.ai and presented to the model for response generation
    public var exaAiSearch: ToolExaAiSearch?
    
    /// Optional. Function tool type. One or more function declarations to be passed to the model along with the current user query. Model may decide to call a subset of these functions by populating FunctionCall in the response. User should provide a FunctionResponse for each function call in the next turn. Based on the function responses, Model will generate the final response back to the user. Maximum 512 function declarations can be provided.
    public var functionDeclarations: [FunctionDeclaration]?
    
    /// Optional. GoogleMaps tool type. Tool to support Google Maps in Model.
    public var googleMaps: GoogleMaps?
    
    /// Optional. GoogleSearch tool type. Tool to support Google Search in Model. Powered by Google.
    public var googleSearch: ToolGoogleSearch?
    
    /// Optional. Specialized retrieval tool that is powered by Google Search.
    @available(*, deprecated)
    public var googleSearchRetrieval: GoogleSearchRetrieval?
    
    /// Optional. If specified, Vertex AI will use Parallel.ai to search for information to answer user queries. The search results will be grounded on Parallel.ai and presented to the model for response generation
    public var parallelAiSearch: ToolParallelAiSearch?
    
    /// Optional. Retrieval tool type. System will always execute the provided retrieval tool(s) to get external knowledge to answer the prompt. Retrieval results are presented to the model for generation.
    public var retrieval: Retrieval?
    
    /// Optional. Tool to support URL context retrieval.
    public var urlContext: UrlContext?
    
    /// Creates a new `Tool`.
    public init(
      codeExecution: ToolCodeExecution? = nil,
      computerUse: ToolComputerUse? = nil,
      enterpriseWebSearch: EnterpriseWebSearch? = nil,
      exaAiSearch: ToolExaAiSearch? = nil,
      functionDeclarations: [FunctionDeclaration]? = nil,
      googleMaps: GoogleMaps? = nil,
      googleSearch: ToolGoogleSearch? = nil,
      googleSearchRetrieval: GoogleSearchRetrieval? = nil,
      parallelAiSearch: ToolParallelAiSearch? = nil,
      retrieval: Retrieval? = nil,
      urlContext: UrlContext? = nil
    ) {
      self.codeExecution = codeExecution
      self.computerUse = computerUse
      self.enterpriseWebSearch = enterpriseWebSearch
      self.exaAiSearch = exaAiSearch
      self.functionDeclarations = functionDeclarations
      self.googleMaps = googleMaps
      self.googleSearch = googleSearch
      self.googleSearchRetrieval = googleSearchRetrieval
      self.parallelAiSearch = parallelAiSearch
      self.retrieval = retrieval
      self.urlContext = urlContext
    }
    enum CodingKeys: String, CodingKey {
      case codeExecution = "codeExecution"
      case computerUse = "computerUse"
      case enterpriseWebSearch = "enterpriseWebSearch"
      case exaAiSearch = "exaAiSearch"
      case functionDeclarations = "functionDeclarations"
      case googleMaps = "googleMaps"
      case googleSearch = "googleSearch"
      case googleSearchRetrieval = "googleSearchRetrieval"
      case parallelAiSearch = "parallelAiSearch"
      case retrieval = "retrieval"
      case urlContext = "urlContext"
    }
  }
}