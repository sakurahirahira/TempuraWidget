// SensorGraphView.swift
// Single sensor line chart drawn via Canvas (Core Graphics, no SwiftUI view diff overhead).
// temperatures: EMA-smoothed history from TemperatureStore
// currentTemp:  raw latest reading for the temperature label

import SwiftUI

struct SensorGraphView: View {
    let label:       String
    let temperatures: [Double]  // EMA-smoothed ring buffer
    let currentTemp: Double?    // raw latest reading for label
    let isAvailable: Bool

    private static let maxPoints  = TemperatureStore.maxPoints
    private static let strideSize = maxPoints / 60  // 40 — 固定ストライドでスプライン安定

    // デフォルトYレンジ。データがはみ出たら自動拡張する
    private var defaultMin: Double { thresholdTemp - 15 }
    private let defaultMax: Double = 60

    private var yRange: (min: Double, max: Double) {
        guard !temperatures.isEmpty else { return (defaultMin, defaultMax) }
        let lo = min(temperatures.min()! - 3, defaultMin)
        let hi = max(temperatures.max()! + 3, defaultMax)
        return (lo, hi)
    }
    private var minTemp: Double { yRange.min }
    private var maxTemp: Double { yRange.max }

    var body: some View {
        ZStack(alignment: .topLeading) {

            // Grid + Graph — Canvas で直接描画（SwiftUIビュー差分計算なし）
            Canvas { ctx, size in
                drawGrid(&ctx, size: size)
                if temperatures.count >= 2 {
                    drawGraph(&ctx, size: size)
                }
            }

            // Y-axis labels（右端）
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

            // センサーラベル + 現在温度（左上）
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(sensorColor)
                if let current = currentTemp, isAvailable {
                    Text(String(format: "%.0f°", current))
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundStyle(currentTempColor(current))
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

    // MARK: - Canvas 描画

    private func drawGrid(_ ctx: inout GraphicsContext, size: CGSize) {
        var path = Path()
        for frac in [0.0, 0.5, 1.0] {
            let y = size.height * frac
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
        }
        ctx.stroke(path, with: .color(.white.opacity(0.07)), lineWidth: 0.5)
    }

    private func drawGraph(_ ctx: inout GraphicsContext, size: CGSize) {
        let pts = buildPoints(in: size)
        guard pts.count >= 2 else { return }

        // Catmull-Rom スプライン
        var path = Path()
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

        let shading = buildShading(in: size)
        let style = StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)

        // shadow を先に描画してから本線を上書き
        var shadowCtx = ctx
        shadowCtx.addFilter(.shadow(color: hotColor.opacity(0.5), radius: 4, x: 0, y: 0))
        shadowCtx.stroke(path, with: shading, style: style)
    }

    // MARK: - サンプル点の構築

    private func buildPoints(in size: CGSize) -> [CGPoint] {
        let xScale     = size.width / Double(Self.maxPoints - 1)
        let stride     = Self.strideSize
        let heightRange = maxTemp - minTemp
        guard heightRange > 0 else { return [] }

        var pts: [CGPoint] = []
        var i = 0
        while i < temperatures.count {
            let x = Double(i) * xScale
            let y = size.height - (temperatures[i] - minTemp) / heightRange * size.height
            pts.append(CGPoint(x: x, y: max(0, min(size.height, y))))
            i += stride
        }
        // 最新データポイントを常に末尾に追加（ストライド境界でない場合）
        let lastIdx = temperatures.count - 1
        if lastIdx % stride != 0 {
            let x = Double(lastIdx) * xScale
            let y = size.height - (temperatures[lastIdx] - minTemp) / heightRange * size.height
            pts.append(CGPoint(x: x, y: max(0, min(size.height, y))))
        }
        return pts
    }

    // MARK: - グラデーションシェーディング

    private func buildShading(in size: CGSize) -> GraphicsContext.Shading {
        let range = maxTemp - minTemp
        guard range > 0 else { return .color(sensorColor) }

        let s1 = max(0.0, min(1.0, (thresholdTemp      - minTemp) / range))
        let s2 = max(0.0, min(1.0, (thresholdTemp + 10 - minTemp) / range))

        let gradient = Gradient(stops: [
            .init(color: sensorColor, location: 0.0),
            .init(color: sensorColor, location: s1),
            .init(color: hotColor,    location: s2),
            .init(color: hotColor,    location: 1.0),
        ])
        // Canvas では CGPoint でエンドポイントを指定（bottom → top）
        return .linearGradient(gradient,
                               startPoint: CGPoint(x: 0, y: size.height),
                               endPoint:   CGPoint(x: 0, y: 0))
    }

    // MARK: - Colors

    private var sensorColor: Color {
        switch label {
        case "CPU": return Color(red: 0.7,  green: 0.35, blue: 1.0)
        case "GPU": return Color(red: 0.2,  green: 0.75, blue: 1.0)
        case "ANE": return Color(red: 1.0,  green: 0.6,  blue: 0.1)
        default:    return Color(red: 0.0,  green: 0.9,  blue: 0.75)
        }
    }

    private var thresholdTemp: Double {
        switch label {
        case "CPU": return 75.0
        case "GPU": return 65.0
        case "MEM": return 55.0
        case "ANE": return 35.0
        default:    return 60.0
        }
    }

    private var hotColor: Color { Color(red: 1.0, green: 0.2, blue: 0.1) }

    private func currentTempColor(_ temp: Double) -> Color {
        let lo = thresholdTemp
        let hi = thresholdTemp + 10
        guard temp > lo else { return .white }
        guard temp < hi else { return hotColor }
        let t = (temp - lo) / (hi - lo)
        return Color(red: 1.0, green: 1.0 - 0.8 * t, blue: 1.0 - 0.9 * t)
    }
}
