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
	private let queue = DispatchQueue(label: "resolver.di.resolver.queue", attributes: .concurrent)
	
	private init() {}
	
	private func register(_ container: ContainerProtocol) {
		queue.async(flags: .barrier) { [weak self] in
			self?.containers.append(container)
		}
	}
	public func register(_ containerScope: String, with serviceBuilder: (inout ContainerProtocol) -> Void) {
		queue.sync(flags: .barrier) {
			if var existingContainer = containers.first(where: { $0.scope == containerScope}) {
				serviceBuilder(&existingContainer)
			} else {
				var container: any ContainerProtocol = Container(scope: containerScope)
				serviceBuilder(&container)
				register(container)
			}
		}
	}
	
	public func resolve<T>() -> T {
		return resolve(T.self)
	}
	
	public func resolve<T>(_ type: T.Type) -> T {
		resolve(type, name: nil)
	}
	
	public func resolve<T>(_ type: T.Type, name: String?) -> T {
		var container: (any ContainerProtocol)?
		
		queue.sync(flags: .barrier) {
			container = containers.first { $0.contains(type, name: name) }
		}
		
		guard let instance = container?.resolve(type, name: name) else {
			fatalError("No registration for type \(type) with name: \(name ?? "nil")")
		}
		
		return instance
	}
}
