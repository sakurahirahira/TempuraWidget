// SensorGraphView.swift
// Single sensor line chart with temperature label overlaid in top-left

import SwiftUI

struct SensorGraphView: View {
    let label: String
    let temperatures: [Double]
    let isAvailable: Bool

    // デフォルトレンジ。データがはみ出たら自動拡張する
    private let defaultMin: Double = 35
    private let defaultMax: Double = 60

    private var yRange: (min: Double, max: Double) {
        guard !temperatures.isEmpty else { return (defaultMin, defaultMax) }
        let dataMin = temperatures.min()!
        let dataMax = temperatures.max()!
        let lo = min(dataMin - 3, defaultMin)
        let hi = max(dataMax + 3, defaultMax)
        return (lo, hi)
    }

    private var minTemp: Double { yRange.min }
    private var maxTemp: Double { yRange.max }

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

    private let maxPoints = 2400  // 10分 × 4Hz

    private func smoothPath(in size: CGSize) -> Path {
        // 1. 移動平均でデータを平滑化
        let smoothed = movingAverage(temperatures, window: 40)
        guard smoothed.count >= 2 else { return Path() }

        // 2. X軸は常に2400点固定スケール
        //    データが溜まるにつれ左から右へ線が伸び、
        //    満杯になったら左スクロールになる
        let xScale = size.width / Double(maxPoints - 1)

        // 3. 間引き（表示用に最大60点）
        let strideSize = max(1, smoothed.count / 60)
        var pts: [CGPoint] = []
        var i = 0
        while i < smoothed.count {
            let x = Double(i) * xScale
            let y = size.height - (smoothed[i] - minTemp) / (maxTemp - minTemp) * size.height
            pts.append(CGPoint(x: x, y: max(0, min(size.height, y))))
            i += strideSize
        }

        // 4. Catmull-Rom スプライン
        return Path { path in
            guard pts.count >= 2 else { return }
            path.move(to: pts[0])
            for j in 1..<pts.count {
                let p0 = pts[max(0, j - 2)]
                let p1 = pts[j - 1]
                let p2 = pts[j]
                let p3 = pts[min(pts.count - 1, j + 1)]
                let cp1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6,
                                  y: p1.y + (p2.y - p0.y) / 6)
                let cp2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6,
                                  y: p2.y - (p3.y - p1.y) / 6)
                path.addCurve(to: p2, control1: cp1, control2: cp2)
            }
        }
    }

    private func movingAverage(_ data: [Double], window: Int) -> [Double] {
        guard data.count >= window else { return data }
        var result: [Double] = []
        result.reserveCapacity(data.count)
        for i in 0..<data.count {
            let from = max(0, i - window / 2)
            let to   = min(data.count - 1, i + window / 2)
            let slice = data[from...to]
            result.append(slice.reduce(0, +) / Double(slice.count))
        }
        return result
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
