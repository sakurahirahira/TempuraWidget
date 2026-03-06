# TempuraWidget

Mac mini M4上でCPU・GPU・メモリの温度をデスクトップに常時表示するmacOSウィジェットアプリ。

## 技術スタック
- Swift + SwiftUI + AppKit（NSPanel）
- 温度取得：IOKit経由でSMCセンサー直読み（Apple Silicon M4対応、sudo不要）
- グラフ描画：SwiftUI Path

## 重要な決定事項
- App Sandbox：無効（IOKit直接アクセスのため）
- `powermetrics` は使用しない（sudo必要のため）
- SMCキーはApple Silicon M4用のキーを使用（Intel系キーとは異なる）

## 機能要件
- 250ms間隔（4Hz）で温度更新
- 過去10分分のデータ保持（2,400点/センサー × 3センサー）
- 折れ線グラフ全面表示＋右上に現在温度を重ねて表示
- 温度に応じて線の色変化：緑（〜60°C）→ 黄（60〜80°C）→ 赤（80°C〜）
- デスクトップ上に半透明フロストガラス背景で常時表示
- ドラッグで位置移動可能
- 右クリックで設定メニュー

## 2サイズ対応
| サイズ | 概算サイズ | レイアウト |
|--------|-----------|-----------|
| Small  | 300×250px | 3センサー縦並び |
| Medium | 600×250px | 3センサー横並び（グラフ広め） |

## ファイル構成
```
TempuraWidget/
├── TempuraWidgetApp.swift       # エントリーポイント
├── AppDelegate.swift            # NSPanel管理
├── Views/
│   ├── OverlayWindowView.swift  # メインウィジェットView
│   ├── SensorGraphView.swift    # 1センサー分の折れ線グラフ
│   └── ContextMenuView.swift    # 右クリックメニュー
├── Models/
│   ├── TemperatureStore.swift   # データ保持（リングバッファ、Combine）
│   └── SensorReading.swift      # データモデル
└── Services/
    └── SMCReader.swift          # IOKit経由のSMC温度取得
```

## 参考
- SMCキーリスト：https://github.com/exelban/stats （Apple Silicon対応）
