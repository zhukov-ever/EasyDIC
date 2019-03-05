import Foundation

    
struct ContainerConfiguration {
    
    static let global = "global"
    
    var currentNamespace:AnyHashable
    var store:[AnyHashable:[AnyHashable:Any]] = [:]
    
    init() {
        currentNamespace = ContainerConfiguration.global
    }
    
}


struct Container {
    
    private var lock = pthread_rwlock_t()
    var configuration:ContainerConfiguration
    
    init(configuration conf:ContainerConfiguration) {
        _ = pthread_rwlock_init(&lock, nil)
        configuration = conf
    }
    
    mutating func resolve<T>(for type:T.Type, in namespace:AnyHashable? = nil) -> T? {
        defer { pthread_rwlock_unlock(&lock) }
        pthread_rwlock_rdlock(&lock)
        
        var store = configuration.store[namespace ?? configuration.currentNamespace]
        let extract = { store?["\(type.self)"] as? T }
        
        if extract() == nil {
            store = configuration.store[ContainerConfiguration.global]
        }
        return extract()
    }
    
    mutating func bind<T>(object:T, for type:T.Type, in namespace:AnyHashable? = nil) {
        defer { pthread_rwlock_unlock(&lock) }
        pthread_rwlock_wrlock(&lock)
        
        let namespace = namespace ?? configuration.currentNamespace
        var objects = configuration.store[namespace] ?? [:]
        objects["\(type.self)"] = object
        
        configuration.store[namespace] = objects
    }

}


/***
 Example
 */

enum Namespaces:String {
    case test
}

protocol Aing { }
class A: Aing { }

protocol Bing { }
class B: Bing { }

class Foo: Aing, Bing { }
class Nani: Aing, Bing { }


let configuration = ContainerConfiguration()
var container = Container(configuration: configuration)

container.bind(object: A(), for: Aing.self)
container.bind(object: Foo(), for: (Aing & Bing).self)
container.bind(object: Nani(), for: (Aing & Bing).self, in: Namespaces.test)

container.resolve(for: Aing.self)
container.resolve(for: Bing.self)
container.resolve(for: (Aing & Bing).self)
container.resolve(for: (Aing & Bing).self, in: Namespaces.test)

container.configuration.currentNamespace = Namespaces.test
container.resolve(for: (Aing & Bing).self)
