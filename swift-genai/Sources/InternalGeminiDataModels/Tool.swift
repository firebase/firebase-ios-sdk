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


extension GeminiDataModels {
  /// An internal data model for `Tool`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `Tool`
  /// 
  /// Tool details that the model may use to generate response.
  /// 
  /// A `Tool` is a piece of code that enables the system to interact with external
  /// systems to perform an action, or set of actions, outside of knowledge and
  /// scope of the model. A Tool object should contain exactly one type of Tool.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1Tool`
  /// 
  /// Tool details that the model may use to generate response.
  /// 
  /// A `Tool` is a piece of code that enables the system to interact with
  /// external systems to perform an action, or set of actions, outside of
  /// knowledge and scope of the model. A Tool object should contain exactly
  /// one type of Tool (e.g FunctionDeclaration, Retrieval or
  /// GoogleSearchRetrieval).
  package struct Tool: Codable, Sendable, Equatable, Hashable {
    /// Optional. A list of user-provided functions for function calling. For functions whose
    /// names are listed in the template frontmatter, the model may decide to
    /// call a subset of these functions by populating `FunctionCall` in the
    /// response. User should provide a `FunctionResponse` for each function call
    /// in the next turn.
    package let templateFunctions: [TemplateFunction]?
    
    /// Optional. Tool to retrieve public maps data for grounding, powered by Google.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Tool to retrieve public maps data for grounding, powered by Google.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. GoogleMaps tool type.
    /// Tool to support Google Maps in Model.
    package let googleMaps: GoogleMaps?
    
    /// Optional. A list of `FunctionDeclarations` available to the model that can be used
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. A list of `FunctionDeclarations` available to the model that can be used
    /// for function calling.
    /// 
    /// The model or system does not execute the function. Instead the defined
    /// function may be returned as a FunctionCall
    /// with arguments to the client side for execution. The model may decide to
    /// call a subset of these functions by populating
    /// FunctionCall in the response. The next
    /// conversation turn may contain a
    /// FunctionResponse
    /// with the Content.role "function" generation context for the next model
    /// turn.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Function tool type.
    /// One or more function declarations to be passed to the model along with the
    /// current user query. Model may decide to call a subset of these functions
    /// by populating FunctionCall in the response.
    /// User should provide a FunctionResponse
    /// for each function call in the next turn. Based on the function responses,
    /// Model will generate the final response back to the user.
    /// Maximum 512 function declarations can be provided.
    package let functionDeclarations: [FunctionDeclaration]?
    
    /// Optional. Retrieval tool that is powered by Google search.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Retrieval tool that is powered by Google search.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Specialized retrieval tool that is powered by Google Search.
    package let googleSearchRetrieval: GoogleSearchRetrieval?
    
    /// Optional. Enables the model to execute code as part of generation.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Enables the model to execute code as part of generation.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. CodeExecution tool type.
    /// Enables the model to execute code as part of generation.
    package let codeExecution: CodeExecution?
    
    /// Optional. GoogleSearch tool type.
    /// Tool to support Google Search in Model. Powered by Google.
    package let googleSearch: GoogleSearch?
    
    /// Optional. Tool to support the model interacting directly with the computer.
    /// If enabled, it automatically populates computer-use specific Function
    /// Declarations.
    package let computerUse: ComputerUse?
    
    /// Optional. Tool to support URL context retrieval.
    package let urlContext: UrlContext?
    
    /// Optional. MCP Servers to connect to.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. MCP Servers to connect to.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let mcpServers: [ToolMcpServer]?
    
    /// Optional. Retrieval tool type.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Retrieval tool type.
    /// System will always execute the provided retrieval tool(s) to get external
    /// knowledge to answer the prompt. Retrieval results are presented to the
    /// model for generation.
    package let retrieval: Retrieval?
    
    /// Optional. Tool to support searching public web data, powered by Vertex AI Search and
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Tool to support searching public web data, powered by Vertex AI Search and
    /// Sec4 compliance.
    package let enterpriseWebSearch: EnterpriseWebSearch?
    
    /// Optional. If specified, Vertex AI will use Parallel.ai to search for information to
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. If specified, Vertex AI will use Parallel.ai to search for information to
    /// answer user queries. The search results will be grounded on Parallel.ai
    /// and presented to the model for response generation
    package let parallelAiSearch: ToolParallelAiSearch?
    
    /// Optional. Uses Exa.ai to search for information to
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Uses Exa.ai to search for information to
    /// answer user queries. The search results will be grounded on Exa.ai
    /// and presented to the model for response generation
    package let exaAiSearch: ToolExaAiSearch?
    

    /// Creates a new `Tool`.
    ///
    /// - Parameters:
    ///   - templateFunctions: Optional. A list of user-provided functions for function calling. For functions whose
    ///   - googleMaps: Optional. Tool to retrieve public maps data for grounding, powered by Google. (behavior varies by backend). For more details, see ``googleMaps``.
    ///   - functionDeclarations: Optional. A list of `FunctionDeclarations` available to the model that can be used (behavior varies by backend). For more details, see ``functionDeclarations``.
    ///   - googleSearchRetrieval: Optional. Retrieval tool that is powered by Google search. (behavior varies by backend). For more details, see ``googleSearchRetrieval``.
    ///   - codeExecution: Optional. Enables the model to execute code as part of generation. (behavior varies by backend). For more details, see ``codeExecution``.
    ///   - googleSearch: Optional. GoogleSearch tool type.
    ///   - computerUse: Optional. Tool to support the model interacting directly with the computer.
    ///   - urlContext: Optional. Tool to support URL context retrieval.
    ///   - mcpServers: Optional. MCP Servers to connect to. (Gemini Developer API only). For more details, see ``mcpServers``.
    ///   - retrieval: Optional. Retrieval tool type. (Gemini Enterprise Agent Platform only). For more details, see ``retrieval``.
    ///   - enterpriseWebSearch: Optional. Tool to support searching public web data, powered by Vertex AI Search and (Gemini Enterprise Agent Platform only). For more details, see ``enterpriseWebSearch``.
    ///   - parallelAiSearch: Optional. If specified, Vertex AI will use Parallel.ai to search for information to (Gemini Enterprise Agent Platform only). For more details, see ``parallelAiSearch``.
    ///   - exaAiSearch: Optional. Uses Exa.ai to search for information to (Gemini Enterprise Agent Platform only). For more details, see ``exaAiSearch``.
    package init(
      templateFunctions: [TemplateFunction]? = nil,
      googleMaps: GoogleMaps? = nil,
      functionDeclarations: [FunctionDeclaration]? = nil,
      googleSearchRetrieval: GoogleSearchRetrieval? = nil,
      codeExecution: CodeExecution? = nil,
      googleSearch: GoogleSearch? = nil,
      computerUse: ComputerUse? = nil,
      urlContext: UrlContext? = nil,
      mcpServers: [ToolMcpServer]? = nil,
      retrieval: Retrieval? = nil,
      enterpriseWebSearch: EnterpriseWebSearch? = nil,
      parallelAiSearch: ToolParallelAiSearch? = nil,
      exaAiSearch: ToolExaAiSearch? = nil
    ) {
      self.templateFunctions = templateFunctions
      self.googleMaps = googleMaps
      self.functionDeclarations = functionDeclarations
      self.googleSearchRetrieval = googleSearchRetrieval
      self.codeExecution = codeExecution
      self.googleSearch = googleSearch
      self.computerUse = computerUse
      self.urlContext = urlContext
      self.mcpServers = mcpServers
      self.retrieval = retrieval
      self.enterpriseWebSearch = enterpriseWebSearch
      self.parallelAiSearch = parallelAiSearch
      self.exaAiSearch = exaAiSearch
    }
    enum CodingKeys: String, CodingKey {
      case templateFunctions = "templateFunctions"
      case googleMaps = "googleMaps"
      case functionDeclarations = "functionDeclarations"
      case googleSearchRetrieval = "googleSearchRetrieval"
      case codeExecution = "codeExecution"
      case googleSearch = "googleSearch"
      case computerUse = "computerUse"
      case urlContext = "urlContext"
      case mcpServers = "mcpServers"
      case retrieval = "retrieval"
      case enterpriseWebSearch = "enterpriseWebSearch"
      case parallelAiSearch = "parallelAiSearch"
      case exaAiSearch = "exaAiSearch"
    }
  }
}