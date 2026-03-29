//
//  AudioModel.swift
//  EngeRecordingApp
//
//  Created by user on 2023/11/04.

import Foundation
import SwiftUI
import AVFoundation
import SoundAnalysis

class AudioModel: ObservableObject {
    // MARK: - 外部マネージャー
    private let audioManager = AudioManager()
    private let fileManager = AudioFileManager()
    
    // MARK: - 公開プロパティ（Viewが監視するもの）
    @Published var isRecording = false
    @Published var isPlaying: Bool = false
    @Published var waveformData: [Float] = []
    @Published var commentA: String = ""
    @Published var commentB: String = ""
    @Published var outputVolume: Float = 1.0
    
    // MARK: - 内部管理用プロパティ
    private var audioFileURL: URL?
    private var audioFileforFull: AVAudioFile?
    private var recordingStartTime: Date?
    
    private var nowTimeA_Array: [Double] = []
    private var nowTimeB_Array: [Double] = []
    
    // AI・解析関連
    private var soundClassifier: MLModel?
    var resultViewModel: ResultViewModel
    var resultObserver: ResultObserver

    // 設定定数
    let waveformLengthInSeconds: Double = 3
    let samplesPerSecond: Double = 12000
    private let dateFormatter = DateFormatter()

    // MARK: - 初期化
    init(modelName: String, resultObserver: ResultObserver, resultViewModel: ResultViewModel) {
        self.resultViewModel = resultViewModel
        self.resultObserver = ResultObserver(resultViewModel: resultViewModel)
        
        // 日付フォーマットの設定
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        dateFormatter.locale = Locale.current
        dateFormatter.timeZone = TimeZone.current
        
        // AIモデルのロード
        loadSoundClassifier(modelName: modelName)
    }

    private func loadSoundClassifier(modelName: String) {
        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") else {
            print("Error: モデルファイルが見つかりません。")
            return
        }
        do {
            self.soundClassifier = try MLModel(contentsOf: modelURL)
        } catch {
            print("Error: モデルの読み込みに失敗: \(error)")
        }
    }

    // MARK: - 録音コントロール
    func startRecording() {
        guard let classifier = soundClassifier else { return }
        
        // 1. データの初期化
        self.waveformData.removeAll()
        self.nowTimeA_Array.removeAll()
        self.nowTimeB_Array.removeAll()
        self.resultViewModel.lap1 = 0.0
        self.resultViewModel.lap2 = 0.0
        self.resultViewModel.lap3 = 0.0
        
        // 2. 保存用ファイルの準備
        prepareFullAudioFile()
        
        do {
            // 3. オーディオセッションの設定
            try audioManager.configureSession()
            
            // 4. エンジンの開始と配線（クロージャでデータを受け取る）
            try audioManager.setupEngine(model: classifier, observer: self.resultObserver) { [weak self] buffer, time in
                guard let self = self else { return }
                
                // 波形の更新
                self.updateWaveform(buffer: buffer)
                
                // 全編録音ファイルへの書き込み
                try? self.audioFileforFull?.write(from: buffer)
            }
            
            self.isRecording = true
            self.recordingStartTime = Date()
            print("Recording started successfully.")
            
        } catch {
            print("Failed to start recording: \(error)")
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        
        self.isRecording = false
        audioManager.stopEngine()
        
        // 解析用の後処理
        self.resultObserver.engeCount = 0
        self.resultObserver.engeTime = nil
        self.resultObserver.timeLapArray = [nil, nil, nil, nil]

        // 非同期でトリミング保存を実行
        DispatchQueue.global(qos: .userInitiated).async {
            self.saveTrimmedAudioFile()
        }
    }

    // MARK: - 内部ロジック
    private func prepareFullAudioFile() {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let dateString = dateFormatter.string(from: Date())
        let url = docs.appendingPathComponent("\(dateString)_full.caf")
        self.audioFileURL = url
        
        let settings = audioManager.engine.inputNode.outputFormat(forBus: 0).settings
        self.audioFileforFull = try? AVAudioFile(forWriting: url, settings: settings)
    }

    private func updateWaveform(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let floatBuffer = UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength))
        
        // UI更新のためにメインスレッドへ
        DispatchQueue.main.async {
            self.waveformData.append(contentsOf: floatBuffer)
            
            let maxSamples = Int(self.waveformLengthInSeconds * self.samplesPerSecond)
            if self.waveformData.count > maxSamples {
                self.waveformData.removeFirst(self.waveformData.count - maxSamples)
            }
            // 変更を通知
            self.objectWillChange.send()
        }
    }

    private func saveTrimmedAudioFile() {
        guard let url = audioFileURL else { return }
        let settings = audioManager.engine.inputNode.outputFormat(forBus: 0).settings
        
        fileManager.processTrimming(timestamps: nowTimeA_Array, originalURL: url, comment: commentA, settings: settings)
        fileManager.processTrimming(timestamps: nowTimeB_Array, originalURL: url, comment: commentB, settings: settings)
    }

    // MARK: - UI Action Methods
    func trimmingButtonAPressed() {
        if isRecording, let start = recordingStartTime {
            let timestamp = Date().timeIntervalSince(start)
            nowTimeA_Array.append(timestamp)
            print("Added Timestamp A: \(timestamp)")
        }
    }

    func trimmingButtonBPressed() {
        if isRecording, let start = recordingStartTime {
            let timestamp = Date().timeIntervalSince(start)
            nowTimeB_Array.append(timestamp)
            print("Added Timestamp B: \(timestamp)")
        }
    }
}

class ResultObserver: NSObject, SNResultsObserving, ObservableObject {
    var resultViewModel: ResultViewModel
    
    // 状態管理用
    var engeCount: Int = 0
    var engeTime: Date? = nil
    var timeLapArray: [Date?] = [nil, nil, nil, nil]
    var isUpdateActive: Bool = true

    init(resultViewModel: ResultViewModel) {
        self.resultViewModel = resultViewModel
    }
    
    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult else { return }
        guard let classification = result.classifications.first else { return }
        
        let identifier = classification.identifier
        let confidence = Float(classification.confidence)
        
        // 信頼度が0.7以上、かつ前回の更新から1秒以上経過している場合のみ処理
        if (confidence >= 0.7) && self.isUpdateActive {
            updateValue(identifier: identifier, confidence: confidence)
            timeLapEnge(identifier: identifier)
            
            // 連続検知を防ぐためのインターバル（1秒）
            self.isUpdateActive = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.isUpdateActive = true
            }
        }
    }
    
    private func updateValue(identifier: String, confidence: Float) {
        DispatchQueue.main.async {
            self.resultViewModel.identifier = identifier
            self.resultViewModel.confidence = confidence
        }
    }
    
    private func timeLapEnge(identifier: String) {
        // 「嚥下」または「むせ」に反応
        if (identifier == "嚥下") || (identifier == "むせ") {
            engeCount += 1
            let now = Date()
            
            if engeCount == 1 {
                engeTime = now
                self.timeLapArray = [now, now, now, now]
            } else {
                // 配列の更新ロジック
                if engeCount <= 4 {
                    self.timeLapArray[engeCount - 1] = now
                } else {
                    self.timeLapArray.removeFirst()
                    self.timeLapArray.append(now)
                }
                
                // ラップタイムの計算をViewModelに反映
                DispatchQueue.main.async {
                    self.calculateLaps()
                }
            }
        }
    }
    
    private func calculateLaps() {
        guard timeLapArray.count >= 4 else { return }
        // 安全にラップタイムを計算
        if let t0 = timeLapArray[0], let t1 = timeLapArray[1] {
            resultViewModel.lap1 = t1.timeIntervalSince(t0)
        }
        if let t1 = timeLapArray[1], let t2 = timeLapArray[2] {
            resultViewModel.lap2 = t2.timeIntervalSince(t1)
        }
        if let t2 = timeLapArray[2], let t3 = timeLapArray[3] {
            resultViewModel.lap3 = t3.timeIntervalSince(t2)
        }
    }
}

class ResultViewModel: ObservableObject {
    @Published var identifier: String = ""
    @Published var confidence: Float = 0.0
    @Published var lap1: Double = 0.0
    @Published var lap2: Double = 0.0
    @Published var lap3: Double = 0.0
    
    init() {} // シンプルに保持
}
