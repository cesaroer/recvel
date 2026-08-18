import Foundation
import HealthKit

struct NutritionHealthKitPayload {
    let id: UUID
    let title: String
    let date: Date
    let calories: Int
    let protein: Int
    let carbohydrates: Int
    let fat: Int
}

enum NutritionHealthKitWriteError: LocalizedError {
    case unavailable
    case unsupportedDataType

    var errorDescription: String? {
        switch self {
        case .unavailable:
            RecvelL10n.text("nutrition.assistant.health.unavailable")
        case .unsupportedDataType:
            RecvelL10n.text("nutrition.assistant.health.unsupported")
        }
    }
}

/// Writes only a meal the user has explicitly confirmed as eaten. Authorization
/// is separate from Recvel's read permission and is requested at the moment the
/// user chooses Apple Health.
struct NutritionHealthKitWriter {
    private let healthStore = HKHealthStore()

    func save(_ payload: NutritionHealthKitPayload) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw NutritionHealthKitWriteError.unavailable
        }
        let descriptors: [(HKQuantityTypeIdentifier, HKUnit, Double, String)] = [
            (.dietaryEnergyConsumed, .kilocalorie(), Double(payload.calories), "energy"),
            (.dietaryProtein, .gram(), Double(payload.protein), "protein"),
            (.dietaryCarbohydrates, .gram(), Double(payload.carbohydrates), "carbohydrates"),
            (.dietaryFatTotal, .gram(), Double(payload.fat), "fat")
        ]
        let resolved = descriptors.compactMap { descriptor -> (HKQuantityType, HKUnit, Double, String)? in
            guard let type = HKObjectType.quantityType(forIdentifier: descriptor.0) else { return nil }
            return (type, descriptor.1, descriptor.2, descriptor.3)
        }
        guard resolved.count == descriptors.count else {
            throw NutritionHealthKitWriteError.unsupportedDataType
        }

        let shareTypes = Set(resolved.map { $0.0 as HKSampleType })
        // API async nativa de HealthKit (iOS 15+), la misma que usa
        // `HealthDataProvider.requestAuthorization`. Envolverla en
        // `withCheckedThrowingContinuation` ademas no compilaba: el SDK nuevo
        // añade una sobrecarga con `isolation:` y la inferencia del generico
        // se vuelve ambigua.
        try await healthStore.requestAuthorization(toShare: shareTypes, read: [])

        let samples: [HKQuantitySample] = resolved.map { type, unit, value, suffix in
            HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: unit, doubleValue: value),
                start: payload.date,
                end: payload.date,
                metadata: [
                    HKMetadataKeyFoodType: payload.title,
                    HKMetadataKeySyncIdentifier: "com.recvel.meal.\(payload.id.uuidString).\(suffix)",
                    HKMetadataKeySyncVersion: 1
                ]
            )
        }
        try await healthStore.save(samples)
    }
}
