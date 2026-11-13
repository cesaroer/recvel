import Foundation

/// Memoria para valores derivados dentro de una vista.
///
/// Las pantallas grandes definian `scores`, `brief`, `points`… como
/// propiedades calculadas, y el `body` las leia decenas de veces por pasada:
/// cada lectura volvia a correr el motor sobre 30 dias de historial. En el
/// telefono, con datos reales, eso eran cientos de milisegundos por redibujado
/// (cambiar de pestaña, tocar un dia, hacer scroll).
///
/// Se guarda en `@State` como referencia: escribir en la cache durante el
/// `body` no es un cambio de estado y no provoca otro redibujado. Cada valor
/// se recalcula solo cuando cambia su clave.
final class DerivedCache {
    private var store: [String: (key: AnyHashable, value: Any)] = [:]

    func value<T>(_ name: String, key: AnyHashable, _ make: () -> T) -> T {
        if let hit = store[name], hit.key == key, let value = hit.value as? T {
            return value
        }
        let value = make()
        store[name] = (key, value)
        return value
    }
}
