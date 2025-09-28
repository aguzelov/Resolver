//
//  Resolver.swift
//  Resolver
//
//  Created by Clax on 28.09.25.
//

import Foundation

public enum Lifetime {
	case transient
	case singleton
}

private struct ServiceKey: Hashable {
	let id: ObjectIdentifier
	let name: String?
	
	init(_ type: Any.Type, name: String?) {
		self.id = ObjectIdentifier(type)
		self.name = name
	}
}

public class Container {
	public typealias Factory = (ResolverProtocol) -> Any
	
	public let scope: String
	
	private let queue: DispatchQueue
	private var factories: [ServiceKey: (factory: Factory, lifetime: Lifetime)] = [:]
	private var singletons: [ServiceKey: Any] = [:]
	
	public init(scope: String) {
		self.scope = scope
		self.queue = DispatchQueue(label: "\(scope).di.container.queue", attributes: .concurrent)
	}
	
	public func removeRegistration<T>(_ type: T.Type, name: String? = nil) {
		let key = ServiceKey(type, name: name)
		queue.async(flags: .barrier) {
			self.factories.removeValue(forKey: key)
			self.singletons.removeValue(forKey: key)
		}
	}
}

extension Container: ContainerProtocol {
	public func register<Service>(_ type: Service.Type, name: String? = nil, lifetime: Lifetime = .transient, factory: @escaping (ResolverProtocol) -> Service) {
		let key = ServiceKey(type, name: name)
		queue.async(flags: .barrier) {
			self.factories[key] = (factory: { r in factory(r) }, lifetime: lifetime)
		}
	}
	
	public func contains<T>(_ type: T.Type, name: String? = nil) -> Bool {
		let key = ServiceKey(type, name: name)
		return factories.keys.contains(key)
	}
}

extension Container: ResolverProtocol {
	public func resolve<T>() -> T {
		return resolve(T.self)
	}
	
	public func resolve<T>(_ type: T.Type = T.self) -> T {
		return resolve(type, name: nil)
	}
	
	public func resolve<T>(_ type: T.Type, name: String?) -> T {
		let key = ServiceKey(type, name: name)
		
		if let (factory, lifetime) = queue.sync(execute: { factories[key] }) {
			switch lifetime {
				case .transient:
					guard let instance = factory(self) as? T else {
						fatalError("Factory for \(type) returned wrong type")
					}
					return instance
				case .singleton:
					if let existing = queue.sync(execute: { singletons[key] }) as? T {
						return existing
					}
					
					var instance: T!
					queue.sync(flags: .barrier) {
						if let existing = self.singletons[key] as? T {
							instance = existing
							return
						}
						
						guard let created = factory(self) as? T else {
							fatalError("Factory for \(type) returned wrong type")
						}
						
						self.singletons[key] = created
						instance = created
					}
					return instance
			}
		} else {
			fatalError("No registration for type \(type) with name: \(name ?? "nil")")
		}
	}
}
