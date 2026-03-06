// TemperatureStore.swift
// Observable store for temperature history.
// Reads SMC at 4 Hz and maintains a ring buffer of 2400 samples per sensor (10 min).

import Foundation
import Combine

final class TemperatureStore: ObservableObject {
    // Ring buffer size: 4 Hz × 60 s × 10 min = 2400
    private let maxPoints = 2400

    @Published var cpuTemps: [Double] = []
    @Published var gpuTemps: [Double] = []
    @Published var memTemps: [Double] = []
    @Published var aneTemps: [Double] = []

    @Published var cpuAvailable = false
    @Published var gpuAvailable = false
    @Published var memAvailable = false
    @Published var aneAvailable = false

    private let smcReader = SMCReader()
    private var timer: Timer?

    init() {
        smcReader.logAvailableTemperatureKeys()
        start()
    }

    deinit { stop() }

    // MARK: - Control

    private func start() {
        guard smcReader.isAvailable else {
            NSLog("TemperatureStore: SMC not available — using simulated data")
            startSimulation()
            return
        }
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        if let v = smcReader.cpuTemperature {
            push(v, to: &cpuTemps)
            cpuAvailable = true
        }
        if let v = smcReader.gpuTemperature {
            push(v, to: &gpuTemps)
            gpuAvailable = true
        }
        if let v = smcReader.memoryTemperature {
            push(v, to: &memTemps)
            memAvailable = true
        }
        if let v = smcReader.aneTemperature {
            push(v, to: &aneTemps)
            aneAvailable = true
        }
    }

    private func push(_ value: Double, to buffer: inout [Double]) {
        buffer.append(value)
        if buffer.count > maxPoints {
            buffer.removeFirst(buffer.count - maxPoints)
        }
    }

    // MARK: - Simulation fallback (dev/debugging)

    private var simPhase: Double = 0
    private var simTimer: Timer?

    private func startSimulation() {
        cpuAvailable = true
        gpuAvailable = true
        memAvailable = true
        aneAvailable = true

        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.simTick()
        }
        RunLoop.main.add(t, forMode: .common)
        simTimer = t
    }

    private func simTick() {
        simPhase += 0.05
        let cpu = 55.0 + 15.0 * sin(simPhase)
        let gpu = 45.0 + 20.0 * sin(simPhase * 0.7 + 1.0)
        let mem = 40.0 + 10.0 * sin(simPhase * 0.4 + 2.0)
        let ane = 38.0 + 12.0 * sin(simPhase * 0.6 + 3.0)
        push(cpu, to: &cpuTemps)
        push(gpu, to: &gpuTemps)
        push(mem, to: &memTemps)
        push(ane, to: &aneTemps)
    }
}
