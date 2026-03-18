//
//  AudioManager.swift
//  EngeRecordingApp
//
//  Created by user on 2026/03/18.
//

import Foundation
import AVFoundation
import SoundAnalysis

/// 録音機材のセットアップ・配線・AI解析の実行を担当する（機材設営プロフェッショナル）
final class AudioManager {
    let engine = AVAudioEngine()
    private let session = AVAudioSession.sharedInstance()
    private var streamAnalyzer: SNAudioStreamAnalyzer?
    
    /// オーディオセッションの設定（有線マイク優先などのデバイス設定）
    func configureSession() throws {
        let inputs = session.availableInputs
        // 有線マイクがあれば優先的に使用する設定
        if let wiredMicInput = inputs?.first(where: { $0.portType == .headsetMic }) {
            try session.setPreferredInput(wiredMicInput)
        }
        
        try session.setCategory(.playAndRecord, options: [.allowBluetoothA2DP])
        try session.setMode(.default)
        try session.setPreferredSampleRate(24000.0)
        try session.setActive(true)
    }
    
    /// エンジンの配線とAI解析の開始
    func setupEngine(
        model: MLModel,
        observer: SNResultsObserving,
        onBuffer: @escaping (AVAudioPCMBuffer, AVAudioTime) -> Void
    ) throws {
        // 前回のタップや設定をクリーンアップ
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        
        let inputNode = engine.inputNode
        let format = inputNode.inputFormat(forBus: 0)
        
        // 1. AI解析のリクエスト登録
        streamAnalyzer = SNAudioStreamAnalyzer(format: format)
        let request = try SNClassifySoundRequest(mlModel: model)
        try streamAnalyzer?.add(request, withObserver: observer)
        
        // 2. マイクからの入力を「分岐」させる（タップの設置）
        inputNode.installTap(onBus: 0, bufferSize: 2400, format: format) { buffer, time in
            // A: AIに音を渡して解析させる
            self.streamAnalyzer?.analyze(buffer, atAudioFramePosition: time.sampleTime)
            // B: 外部（AudioModel）にバッファを渡し、波形更新や保存を行わせる
            onBuffer(buffer, time)
        }
        
        // 3. エンジン起動
        engine.prepare()
        try engine.start()
    }
    
    func stopEngine() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        try? session.setActive(false)
    }
}
