// TemperatureStore.swift
// Observable store for temperature history.
// Reads SMC at 4 Hz on a background queue, smooths with EMA (O(1)),
// and fires a 1 Hz renderTick for UI updates.

import Foundation
import Combine

final class TemperatureStore: ObservableObject {
    // Ring buffer size: 4 Hz × 60 s × 10 min = 2400
    static let maxPoints = 2400

    // EMA-smoothed history for graphs (ring buffer)
    private(set) var cpuTemps: [Double] = []
    private(set) var gpuTemps: [Double] = []
    private(set) var memTemps: [Double] = []
    private(set) var aneTemps: [Double] = []

    // Raw latest readings for temperature labels (no EMA lag)
    private(set) var cpuCurrent:  Double? = nil
    private(set) var gpuCurrent:  Double? = nil
    private(set) var memCurrent:  Double? = nil
    private(set) var aneCurrent:  Double? = nil

    private(set) var cpuAvailable = false
    private(set) var gpuAvailable = false
    private(set) var memAvailable = false
    private(set) var aneAvailable = false

    // 1 Hz UI update trigger
    @Published private(set) var renderTick: Int = 0
    private var tickCount = 0

    // EMA: α = 2/(N+1), N=40 → α ≈ 0.0488 (≈10秒の平滑化)
    private let emaAlpha = 2.0 / 41.0
    private var cpuEMA: Double? = nil
    private var gpuEMA: Double? = nil
    private var memEMA: Double? = nil
    private var aneEMA: Double? = nil

    private let smcReader = SMCReader()
    private let smcQueue = DispatchQueue(label: "com.tempura.smc", qos: .utility)
    private var smcTimer: DispatchSourceTimer?
    private var simTimer: DispatchSourceTimer?

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
        let t = DispatchSource.makeTimerSource(queue: smcQueue)
        t.schedule(deadline: .now(), repeating: 0.25)
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        smcTimer = t
    }

    private func stop() {
        smcTimer?.cancel()
        smcTimer = nil
        simTimer?.cancel()
        simTimer = nil
    }

    // MARK: - SMC読み取り（バックグラウンドスレッド）

    private func tick() {
        // smcQueue 上で実行 — I/O をメインスレッドから切り離す
        let cpu = smcReader.cpuTemperature
        let gpu = smcReader.gpuTemperature
        let mem = smcReader.memoryTemperature
        let ane = smcReader.aneTemperature

        DispatchQueue.main.async { [weak self] in
            self?.processReadings(cpu: cpu, gpu: gpu, mem: mem, ane: ane)
        }
    }

    private func processReadings(cpu: Double?, gpu: Double?, mem: Double?, ane: Double?) {
        if let v = cpu {
            cpuCurrent = v
            cpuEMA = ema(cpuEMA, v)
            push(cpuEMA!, to: &cpuTemps)
            cpuAvailable = true
        }
        if let v = gpu {
            gpuCurrent = v
            gpuEMA = ema(gpuEMA, v)
            push(gpuEMA!, to: &gpuTemps)
            gpuAvailable = true
        }
        if let v = mem {
            memCurrent = v
            memEMA = ema(memEMA, v)
            push(memEMA!, to: &memTemps)
            memAvailable = true
        }
        if let v = ane {
            aneCurrent = v
            aneEMA = ema(aneEMA, v)
            push(aneEMA!, to: &aneTemps)
            aneAvailable = true
        }
        tickCount += 1
        if tickCount % 4 == 0 {   // 4Hz → 1Hz
            renderTick += 1
        }
    }

    private func ema(_ prev: Double?, _ value: Double) -> Double {
        guard let prev else { return value }
        return emaAlpha * value + (1 - emaAlpha) * prev
    }

    private func push(_ value: Double, to buffer: inout [Double]) {
        buffer.append(value)
        if buffer.count > Self.maxPoints {
            buffer.removeFirst(buffer.count - Self.maxPoints)
        }
    }

    // MARK: - Simulation fallback (dev/debugging)

    private var simPhase: Double = 0

    private func startSimulation() {
        cpuAvailable = true
        gpuAvailable = true
        memAvailable = true
        aneAvailable = true

        let t = DispatchSource.makeTimerSource(queue: smcQueue)
        t.schedule(deadline: .now(), repeating: 0.25)
        t.setEventHandler { [weak self] in self?.simTick() }
        t.resume()
        simTimer = t
    }

    private func simTick() {
        simPhase += 0.05
        let cpu = 55.0 + 15.0 * sin(simPhase)
        let gpu = 45.0 + 20.0 * sin(simPhase * 0.7 + 1.0)
        let mem = 40.0 + 10.0 * sin(simPhase * 0.4 + 2.0)
        let ane = 38.0 + 12.0 * sin(simPhase * 0.6 + 3.0)

        DispatchQueue.main.async { [weak self] in
            self?.processReadings(cpu: cpu, gpu: gpu, mem: mem, ane: ane)
        }
    }
}
