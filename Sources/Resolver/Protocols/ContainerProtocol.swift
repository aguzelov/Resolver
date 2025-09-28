//
//  ContainerProtocol.swift
//  Resolver
//
//  Created by Clax on 28.09.25.
//

import Foundation

public protocol ContainerProtocol: ResolverProtocol {
	var scope: String { get }
	
	func contains<T>(_ type: T.Type, name: String?) -> Bool
	func register<Service>(_ type: Service.Type, name: String?, lifetime: Lifetime, factory: @escaping (ResolverProtocol) -> Service)
}
