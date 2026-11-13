import Foundation
import SwiftData

// Consultas acotadas a "lo mas reciente".
//
// Un `@Query` sin limite carga el historial ENTERO del modelo y lo mantiene en
// memoria mientras la vista exista — y las pestañas nunca se desmontan. Para
// las pantallas que solo miran hoy o las ultimas semanas, eso crece sin tope
// con los meses de uso. Los limites van holgados respecto a la ventana que
// cada pantalla consulta de verdad (indicada en cada uso).
//
// Se usa `fetchLimit` y no `#Predicate` con fecha: un `@Query` con predicado
// ya provoco un crash al destruirse `NutritionView` (ver su comentario).

extension MealLog {
    static func recent(_ limit: Int) -> FetchDescriptor<MealLog> {
        var descriptor = FetchDescriptor<MealLog>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = limit
        return descriptor
    }
}

extension EmotionLog {
    static func recent(_ limit: Int) -> FetchDescriptor<EmotionLog> {
        var descriptor = FetchDescriptor<EmotionLog>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = limit
        return descriptor
    }
}

extension FitnessActivityLog {
    static func recent(_ limit: Int) -> FetchDescriptor<FitnessActivityLog> {
        var descriptor = FetchDescriptor<FitnessActivityLog>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        descriptor.fetchLimit = limit
        return descriptor
    }
}

extension TrainingReadinessCheckIn {
    static func recent(_ limit: Int) -> FetchDescriptor<TrainingReadinessCheckIn> {
        var descriptor = FetchDescriptor<TrainingReadinessCheckIn>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = limit
        return descriptor
    }
}
