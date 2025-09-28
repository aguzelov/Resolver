//
//  ResolverProtocol.swift
//  Resolver
//
//  Created by Clax on 28.09.25.
//

import Foundation

public protocol ResolverProtocol {
	func resolve<T>() -> T
	func resolve<T>(_ type: T.Type) -> T
	func resolve<T>(_ type: T.Type, name: String?) -> T
}
