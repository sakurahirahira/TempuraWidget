// SensorReading.swift
// Data model for a single temperature sensor

import Foundation

enum SensorKind: String, CaseIterable {
    case cpu = "CPU"
    case gpu = "GPU"
    case memory = "MEM"

    var displayName: String { rawValue }

    var iconName: String {
        switch self {
        case .cpu: return "cpu"
        case .gpu: return "memorychip"
        case .memory: return "memorychip.fill"
        }
    }
}

struct SensorData {
    let kind: SensorKind
    var temperatures: [Double]   // ring buffer values
    var isAvailable: Bool        // false when SMC key returned no data

    var current: Double? { temperatures.last }

    var temperatureColor: TemperatureColor {
        guard let t = current else { return .normal }
        if t >= 80 { return .hot }
        if t >= 60 { return .warm }
        return .normal
    }
}

enum TemperatureColor {
    case normal  // < 60°C: green
    case warm    // 60–80°C: yellow
    case hot     // ≥ 80°C: red
}
