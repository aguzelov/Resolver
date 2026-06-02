//
//  Resolver.swift
//  Resolver
//
//  Created by Clax on 28.09.25.
//

import Foundation

public enum Lifetime {
	case transient
	case container
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

	private let lock = NSLock()
	private var factories: [ServiceKey: (factory: Factory, lifetime: Lifetime)] = [:]
	private var singletons: [ServiceKey: Any] = [:]

	public init(scope: String) {
		self.scope = scope
	}

	public func removeRegistration<T>(_ type: T.Type, name: String? = nil) {
		let key = ServiceKey(type, name: name)
		lock.withLock {
			factories.removeValue(forKey: key)
			singletons.removeValue(forKey: key)
		}
	}
}

extension Container: ContainerProtocol {
	public func register<Service>(_ type: Service.Type, name: String? = nil, lifetime: Lifetime = .transient, factory: @escaping (ResolverProtocol) -> Service) {
		let key = ServiceKey(type, name: name)
		lock.withLock {
			factories[key] = (factory: { r in factory(r) }, lifetime: lifetime)
		}
	}

	public func contains<T>(_ type: T.Type, name: String? = nil) -> Bool {
		let key = ServiceKey(type, name: name)
		return lock.withLock {
			factories.keys.contains(key)
		}
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

		guard let (factory, lifetime) = lock.withLock({ factories[key] }) else {
			fatalError("No registration for type \(type) with name: \(name ?? "nil")")
		}

		switch lifetime {
		case .transient:
			guard let instance = factory(self) as? T else {
				fatalError("Factory for \(type) returned wrong type")
			}
			return instance

		case .container:
			if let existing = lock.withLock({ singletons[key] }) as? T {
				return existing
			}

			// Factory is called outside the lock so it can call resolve re-entrantly
			guard let created = factory(self) as? T else {
				fatalError("Factory for \(type) returned wrong type")
			}

			return lock.withLock {
				if let existing = singletons[key] as? T {
					return existing
				}
				singletons[key] = created
				return created
			}
		}
	}
}
