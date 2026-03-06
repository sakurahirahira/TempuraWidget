// SensorGraphView.swift
// Single sensor line chart with temperature label overlaid in top-left

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
                // Grid lines
                gridLines(in: geo.size)
                    .stroke(.white.opacity(0.07), lineWidth: 0.5)

                // Line graph (smooth bezier)
                if temperatures.count >= 2 {
                    smoothPath(in: geo.size)
                        .stroke(
                            sensorColor,
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                        )
                        .shadow(color: sensorColor.opacity(0.6), radius: 4, x: 0, y: 0)
                }

                // Y-axis labels (right side)
                let midTemp = (minTemp + maxTemp) / 2
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(Int(maxTemp))°")
                    Spacer()
                    Text("\(Int(midTemp))°")
                    Spacer()
                    Text("\(Int(minTemp))°")
                }
                .font(.system(size: 9, weight: .regular, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
                .padding(.trailing, 4)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)

                // Sensor label + current temperature (top-left)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(sensorColor)
                    if let current = temperatures.last, isAvailable {
                        Text(String(format: "%.0f°", current))
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    } else {
                        Text("--°")
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
                .padding(.top, 6)
                .padding(.leading, 8)
            }
        }
    }

    // MARK: - Grid

    private func gridLines(in size: CGSize) -> Path {
        Path { path in
            // 横3本（上・中・下）
            for frac in [0.0, 0.5, 1.0] {
                let y = size.height * frac
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
        }
    }

    // MARK: - Smooth bezier path

    private func smoothPath(in size: CGSize) -> Path {
        let count = temperatures.count
        let step = size.width / Double(count - 1)

        func point(_ i: Int) -> CGPoint {
            let x = Double(i) * step
            let y = size.height - (temperatures[i] - minTemp) / (maxTemp - minTemp) * size.height
            return CGPoint(x: x, y: max(0, min(size.height, y)))
        }

        return Path { path in
            path.move(to: point(0))
            for i in 1..<count {
                let prev = point(i - 1)
                let curr = point(i)
                let cp1 = CGPoint(x: prev.x + step * 0.4, y: prev.y)
                let cp2 = CGPoint(x: curr.x - step * 0.4, y: curr.y)
                path.addCurve(to: curr, control1: cp1, control2: cp2)
            }
        }
    }

    // MARK: - Colors

    private var sensorColor: Color {
        switch label {
        case "CPU": return Color(red: 1.0, green: 0.25, blue: 0.65)  // マゼンタ/ピンク
        case "GPU": return Color(red: 0.2,  green: 0.75, blue: 1.0)  // シアン/水色
        default:    return Color(red: 0.0,  green: 0.9,  blue: 0.75) // ティール/グリーン（MEM）
        }
    }
}
