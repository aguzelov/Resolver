//
//  Resolver.swift
//  Resolver
//
//  Created by Clax on 28.09.25.
//

import Foundation

public final class Resolver: ResolverProtocol {
	public static let shared = Resolver()
	private var containers: [ContainerProtocol] = []
	private init() {}
	
	private func register(_ container: ContainerProtocol) {
		containers.append(container)
	}
	public func register(_ containerScope: String, with serviceBuilder: (inout ContainerProtocol) -> Void) {
		if var existingContainer = containers.first(where: { $0.scope == containerScope}) {
			serviceBuilder(&existingContainer)
			register(existingContainer)
		} else {
			var container: any ContainerProtocol = Container(scope: containerScope)
			serviceBuilder(&container)
			register(container)
		}
	}
	
	public func resolve<T>() -> T {
		return resolve(T.self)
	}
	
	public func resolve<T>(_ type: T.Type) -> T {
		resolve(type, name: nil)
	}
	
	public func resolve<T>(_ type: T.Type, name: String?) -> T {
		let container = containers.first { $0.contains(type, name: name) }
		
		guard let instance = container?.resolve(type, name: name) else {
			fatalError("No registration for type \(type) with name: \(name ?? "nil")")
		}
		
		return instance
	}
}
