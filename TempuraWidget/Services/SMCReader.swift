// SMCReader.swift
// Reads CPU/GPU/Memory temperatures via IOKit AppleSMC
// Apple Silicon M-series (M1/M2/M3/M4) compatible

import IOKit
import Foundation

// MARK: - SMC Constants
private let KERNEL_INDEX_SMC: UInt32 = 2
private let kSMCGetKeyInfo: UInt8 = 9
private let kSMCReadKey: UInt8 = 5

// MARK: - SMC Param Struct (80 bytes, matches kernel struct layout exactly)
// Flat layout with explicit padding to guarantee correct byte offsets
private struct SMCParamStruct {
    var key: UInt32 = 0                          // offset  0, size 4

    var versMajor: UInt8 = 0                     // offset  4
    var versMinor: UInt8 = 0                     // offset  5
    var versBuild: UInt8 = 0                     // offset  6
    var versReserved: UInt8 = 0                  // offset  7
    var versRelease: UInt16 = 0                  // offset  8
    var _pad1: UInt16 = 0                        // offset 10, pad to 4-byte align

    var pLimitVersion: UInt16 = 0               // offset 12
    var pLimitLength: UInt16 = 0                // offset 14
    var pLimitCPU: UInt32 = 0                   // offset 16
    var pLimitGPU: UInt32 = 0                   // offset 20
    var pLimitMem: UInt32 = 0                   // offset 24

    var keyInfoDataSize: UInt32 = 0             // offset 28
    var keyInfoDataType: UInt32 = 0             // offset 32
    var keyInfoDataAttrib: UInt8 = 0            // offset 36
    var _pad2: UInt8 = 0                        // offset 37
    var _pad3: UInt8 = 0                        // offset 38
    var _pad4: UInt8 = 0                        // offset 39

    var result: UInt8 = 0                       // offset 40
    var status: UInt8 = 0                       // offset 41
    var data8: UInt8 = 0                        // offset 42
    var _pad5: UInt8 = 0                        // offset 43, pad to 4-byte align
    var data32: UInt32 = 0                      // offset 44

    var bytes: (                                // offset 48, size 32
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
    ) = (
        0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    )
    // Total: 80 bytes
}

// MARK: - SMC Data Type Codes (FourCharCode as UInt32)
private func fourCC(_ s: String) -> UInt32 {
    var result: UInt32 = 0
    for byte in s.utf8.prefix(4) {
        result = (result << 8) | UInt32(byte)
    }
    return result
}

private let kSP78: UInt32 = fourCC("sp78")  // signed 7.8 fixed point
private let kFPE2: UInt32 = fourCC("fpe2")  // unsigned 14.2 fixed point
private let kFLT:  UInt32 = fourCC("flt ")  // 32-bit float (big-endian)

// MARK: - SMCReader
final class SMCReader {
    private var connection: io_connect_t = 0

    init() {
        assert(MemoryLayout<SMCParamStruct>.size == 80,
               "SMCParamStruct size is \(MemoryLayout<SMCParamStruct>.size), expected 80")
        openConnection()
    }

    deinit {
        closeConnection()
    }

    var isAvailable: Bool { connection != 0 }

    // MARK: - Public temperature accessors

    /// Average of available CPU core temperature sensors
    var cpuTemperature: Double? {
        // P-core and E-core keys for M-series chips
        // M4 base: 4 P-cores (Tp01,Tp05,Tp09,Tp0D) + 6 E-cores (Tp0X,Tp0b,Tp0d,Tp0f,Tp0h,Tp0j)
        // M4 Pro/Max have more cores with additional keys
        let keys = [
            "Tp01", "Tp05", "Tp09", "Tp0D",          // P-core clusters
            "Tp0X", "Tp0b", "Tp0d", "Tp0f",          // E-core clusters
            "Tp0h", "Tp0j", "Tp0l", "Tp0n",          // more E-cores (Pro/Max)
            "Tp0H", "Tp0L", "Tp0P", "Tp0T",          // alternate naming
            "TC0P", "TC0D",                            // Intel compat keys (some chips)
        ]
        return averageTemp(keys: keys)
    }

    /// Average of available GPU temperature sensors
    var gpuTemperature: Double? {
        let keys = [
            "Tg05", "Tg0D", "Tg0L", "Tg0T",         // GPU clusters
            "TGDD", "TG0D", "TG0P",                   // alternate GPU keys
        ]
        return averageTemp(keys: keys)
    }

    /// Memory/bandwidth controller temperature
    var memoryTemperature: Double? {
        let keys = [
            "Tm09", "Tm0D", "Tm0N", "Tm0P", "Tm0S",  // memory bandwidth controller
            "TM0P", "TM0S", "TM1P", "TM1S",           // LPDDR thermal sensors
            "Tf04", "Tf09", "Tf0A", "Tf0B",            // SoC fabric (used on some chips)
        ]
        return averageTemp(keys: keys)
    }

    // MARK: - Private helpers

    private func openConnection() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault,
                                                  IOServiceMatching("AppleSMC"))
        guard service != IO_OBJECT_NULL else {
            NSLog("SMCReader: AppleSMC service not found")
            return
        }
        let kr = IOServiceOpen(service, mach_task_self_, 0, &connection)
        IOObjectRelease(service)
        if kr != KERN_SUCCESS {
            NSLog("SMCReader: IOServiceOpen failed: 0x%x", kr)
            connection = 0
        }
    }

    private func closeConnection() {
        if connection != 0 {
            IOServiceClose(connection)
            connection = 0
        }
    }

    private func smcCall(selector: UInt8, input: inout SMCParamStruct) -> SMCParamStruct? {
        guard connection != 0 else { return nil }
        var inputCopy = input
        inputCopy.data8 = selector

        var output = SMCParamStruct()
        var outputSize = MemoryLayout<SMCParamStruct>.stride
        let kr = IOConnectCallStructMethod(
            connection,
            KERNEL_INDEX_SMC,
            &inputCopy, MemoryLayout<SMCParamStruct>.stride,
            &output, &outputSize
        )
        guard kr == KERN_SUCCESS, output.result == 0 else { return nil }
        return output
    }

    private func readKey(_ key: String) -> Double? {
        guard connection != 0 else { return nil }
        let keyCode = fourCC(key)

        // Step 1: get key info
        var input = SMCParamStruct()
        input.key = keyCode
        guard let info = smcCall(selector: kSMCGetKeyInfo, input: &input) else { return nil }

        let dataType = info.keyInfoDataType
        let dataSize = info.keyInfoDataSize

        // Step 2: read value
        input = SMCParamStruct()
        input.key = keyCode
        input.keyInfoDataSize = dataSize
        guard let value = smcCall(selector: kSMCReadKey, input: &input) else { return nil }

        let b0 = value.bytes.0
        let b1 = value.bytes.1

        switch dataType {
        case kSP78:
            // Signed 7.8 fixed point: range approx -128 to +127.996
            let raw = Int16(bitPattern: UInt16(b0) << 8 | UInt16(b1))
            return Double(raw) / 256.0

        case kFPE2:
            // Unsigned 14.2 fixed point
            let raw = UInt16(b0) << 8 | UInt16(b1)
            return Double(raw) / 4.0

        case kFLT:
            // 32-bit float, big-endian bytes
            let bits = UInt32(b0) << 24 | UInt32(b1) << 16 | UInt32(value.bytes.2) << 8 | UInt32(value.bytes.3)
            return Double(Float(bitPattern: bits))

        default:
            return nil
        }
    }

    private func averageTemp(keys: [String]) -> Double? {
        let readings = keys.compactMap { readKey($0) }
                          .filter { $0 > 1.0 && $0 < 150.0 }  // sanity range
        guard !readings.isEmpty else { return nil }
        return readings.reduce(0, +) / Double(readings.count)
    }
}
