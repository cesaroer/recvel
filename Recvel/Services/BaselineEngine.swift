import Foundation

struct BaselineEngine {
    func median(_ values: [Double]) -> Double? {
        let sorted = values.filter(\.isFinite).sorted()
        guard !sorted.isEmpty else { return nil }
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }

    func confidence(sampleCount: Int) -> DataConfidence {
        switch sampleCount {
        case 21...: .high
        case 7...: .medium
        default: .low
        }
    }

    func deviation(current: Double?, values: [Double], lowerIsBetter: Bool = false) -> Double? {
        guard let current, let baseline = median(robustValues(values)), baseline != 0 else { return nil }
        let raw = (current - baseline) / baseline
        return lowerIsBetter ? -raw : raw
    }

    func robustValues(_ values: [Double], threshold: Double = 4.5) -> [Double] {
        let finite = values.filter(\.isFinite)
        guard let center = median(finite) else { return [] }
        let deviations = finite.map { abs($0 - center) }
        guard let mad = median(deviations), mad > 0 else { return finite }
        return finite.filter { abs($0 - center) / mad <= threshold }
    }

    /// Personal baseline band around the median, clamped to non-negative.
    /// Requires at least 3 finite samples.
    func personalBand(_ values: [Double]) -> ClosedRange<Double>? {
        let finite = values.filter(\.isFinite)
        guard finite.count >= 3, let center = median(finite) else { return nil }
        let deviations = finite.map { abs($0 - center) }
        let mad = median(deviations) ?? 0
        let spread = max(mad * 2.4, max(abs(center) * 0.055, 0.1))
        let lower = max(center - spread, 0)
        let upper = max(center + spread, 0)
        guard lower <= upper else { return nil }
        return lower...upper
    }
}
