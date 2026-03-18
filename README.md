# 嚥下音判定アプリ (EngeRecordingApp)

## 概要
高齢者の不顕性誤嚥の早期発見を目的とした、iOSベースの嚥下音判定PoC（概念実証）アプリです。
iPhoneの外部マイク等で取得した嚥下音をリアルタイムで解析し、AIモデル（Core ML）を用いて嚥下イベントの判定を行います。

## 主な機能
- [cite_start]**音声録音・波形表示**: AVFoundationを用いた低遅延な音声入力とリアルタイム波形表示 
- [cite_start]**AI判定**: Core MLモデルによる嚥下音の推論・クラス分類 
- **履歴管理**: 判定結果のログ保存と過去データの閲覧
- [cite_start]**配信**: TestFlight経由での配布を想定したビルド構成 

## 技術スタック
- **iOS**: SwiftUI
- [cite_start]**Frameworks**: AVFoundation, SoundAnalysis, Core ML 
- [cite_start]**AI Model**: Python (Create ML / TensorFlow) を用いた学習モデル 
- [cite_start]**Tools**: Xcode, GitHub Actions (予定), TestFlight 

## 専門性とこだわったポイント
### 1. ドメイン知識を活かした判定ロジック
[cite_start]単なる音声判定ではなく、医療機器メーカーでの知見を活かし、現場の介護施設での評価・フィードバックを元に、ノイズ耐性の向上や判定アルゴリズムの修正を繰り返しました [cite: 17, 26]。

### 2. デバイス完結型の推論
[cite_start]プライバシーとリアルタイム性を考慮し、音声データをクラウドに送らず、Core MLを用いてデバイス内で推論を完結させています 。

### 3. PoCとしてのスピード感と柔軟性
SwiftUIを採用することで、現場からの要望（UIの視認性など）を即座にプロトタイプに反映できる設計としています。
