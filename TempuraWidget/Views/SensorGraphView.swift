// SensorGraphView.swift
// Single sensor line chart with temperature label overlaid in top-right

import SwiftUI

struct SensorGraphView: View {
    let label: String
    let temperatures: [Double]
    let isAvailable: Bool

    private let minTemp: Double = 30
    private let maxTemp: Double = 100

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Line graph
                if temperatures.count >= 2 {
                    linePath(in: geo.size)
                        .stroke(lineColor, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                }

                // Y-axis labels (left side): max, mid, min
                let midTemp = (minTemp + maxTemp) / 2
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(Int(maxTemp))°")
                    Spacer()
                    Text("\(Int(midTemp))°")
                    Spacer()
                    Text("\(Int(minTemp))°")
                }
                .font(.system(size: 9, weight: .regular, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
                .padding(.trailing, 4)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)

                // Current temperature label (top-left, inside graph)
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(sensorColor.opacity(0.85))
                    if let current = temperatures.last, isAvailable {
                        Text(String(format: "%.0f°", current))
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundStyle(labelColor(for: current))
                    } else {
                        Text("--°")
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
                .padding(.top, 6)
                .padding(.leading, 8)
            }
        }
    }

    // MARK: - Line path

    private func linePath(in size: CGSize) -> Path {
        Path { path in
            let count = temperatures.count
            let step = size.width / Double(count - 1)

            for (i, temp) in temperatures.enumerated() {
                let x = Double(i) * step
                let y = size.height - (temp - minTemp) / (maxTemp - minTemp) * size.height
                let clampedY = max(0, min(size.height, y))
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: clampedY))
                } else {
                    path.addLine(to: CGPoint(x: x, y: clampedY))
                }
            }
        }
    }

    // MARK: - Colors

    private var sensorColor: Color {
        switch label {
        case "CPU": return Color(red: 0.4, green: 0.8, blue: 1.0)   // ライトブルー
        case "GPU": return Color(red: 0.8, green: 0.5, blue: 1.0)   // ライトパープル
        default:    return Color(red: 0.4, green: 1.0, blue: 0.8)   // ライトティール（MEM）
        }
    }

    private var lineColor: Color {
        guard let current = temperatures.last else { return .green }
        return temperatureColor(current).opacity(0.85)
    }

    private func labelColor(for temp: Double) -> Color {
        temperatureColor(temp)
    }

    private func temperatureColor(_ temp: Double) -> Color {
        if temp >= 80 { return .red }
        if temp >= 60 { return Color(red: 1.0, green: 0.8, blue: 0.0) }
        return Color(red: 0.3, green: 1.0, blue: 0.4)
    }
}
