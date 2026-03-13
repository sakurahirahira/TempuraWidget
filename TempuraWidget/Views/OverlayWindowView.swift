// OverlayWindowView.swift
// Main widget view — adapts layout based on window width (Small vs Medium)

import SwiftUI

struct OverlayWindowView: View {
    @EnvironmentObject var store: TemperatureStore

    var body: some View {
        GeometryReader { geo in
            let isWide = geo.size.width > 400

            ZStack {
                // renderTick を参照して1Hzのみ再描画させる invisible anchor
                Color.clear.frame(width: 0, height: 0).id(store.renderTick)
                // Dark navy background (画像に合わせたダークネイビー)
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.12, green: 0.14, blue: 0.20).opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
                    )

                // Sensor graphs
                if isWide {
                    // Medium: 4 sensors side by side
                    HStack(spacing: 1) {
                        graphCell(label: "CPU", temps: store.cpuTemps, available: store.cpuAvailable)
                        Divider().background(.white.opacity(0.1))
                        graphCell(label: "GPU", temps: store.gpuTemps, available: store.gpuAvailable)
                        Divider().background(.white.opacity(0.1))
                        graphCell(label: "MEM", temps: store.memTemps, available: store.memAvailable)
                        Divider().background(.white.opacity(0.1))
                        graphCell(label: "ANE", temps: store.aneTemps, available: store.aneAvailable)
                    }
                    .padding(8)
                } else {
                    // Small: 4 sensors stacked
                    VStack(spacing: 1) {
                        graphCell(label: "CPU", temps: store.cpuTemps, available: store.cpuAvailable)
                        Divider().background(.white.opacity(0.1))
                        graphCell(label: "GPU", temps: store.gpuTemps, available: store.gpuAvailable)
                        Divider().background(.white.opacity(0.1))
                        graphCell(label: "MEM", temps: store.memTemps, available: store.memAvailable)
                        Divider().background(.white.opacity(0.1))
                        graphCell(label: "ANE", temps: store.aneTemps, available: store.aneAvailable)
                    }
                    .padding(8)
                }
            }
        }
        .contextMenu {
            Button("終了") { NSApplication.shared.terminate(nil) }
        }
    }

    @ViewBuilder
    private func graphCell(label: String, temps: [Double], available: Bool) -> some View {
        SensorGraphView(label: label, temperatures: temps, isAvailable: available)
    }
}
