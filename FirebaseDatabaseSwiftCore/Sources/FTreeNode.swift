//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 19/02/2022.
//

import Foundation

struct FTreeNode<T> {
  var children: [String: FTreeNode] = [:]
  var childCount: Int = 0
  var value: T? = nil
}
