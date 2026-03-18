//
//  AudioFileManager.swift
//  EngeRecordingApp
//
//  Created by user on 2026/03/18.
//

import Foundation
import AVFoundation
import Accelerate // vDSP_mmov のために必要

final class AudioFileManager {
    
    enum Config {
        static let trimmingWindow: TimeInterval = 3.0
        static let fileExtension = "caf"
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()

    /// メインの処理：複数のタイムスタンプを一括処理する
    func processTrimming(timestamps: [Double], originalURL: URL, comment: String, settings: [String: Any]) {
        let nowDate = dateFormatter.string(from: Date())
        
        for seconds in timestamps {
            do {
                try trimAndSave(
                    at: seconds,
                    from: originalURL,
                    dateString: nowDate,
                    comment: comment,
                    settings: settings
                )
            } catch {
                print("Failed to trim at \(seconds)s: \(error)")
            }
        }
    }

    /// 1つの切り出しを実行して保存する
    private func trimAndSave(at seconds: Double, from url: URL, dateString: String, comment: String, settings: [String: Any]) throws {
        let originalFile = try AVAudioFile(forReading: url)
        guard let originalBuffer = loadAudioFileToBuffer(fileURL: url) else { return }
        
        let sampleRate = originalFile.processingFormat.sampleRate
        let positionInSamples = AVAudioFramePosition(seconds * sampleRate)
        let windowInSamples = Int64(sampleRate * Config.trimmingWindow)
        
        // 1. 開始・終了フレームの計算（境界線チェック）
        let startFrame = max(0, positionInSamples - windowInSamples)
        let lastFrame = AVAudioFramePosition(originalBuffer.frameLength)
        let endFrame = min(lastFrame, positionInSamples + windowInSamples)
        let frameCount = AVAudioFrameCount(endFrame - startFrame)
        
        // 2. 書き出し用バッファの作成とデータコピー
        let format = originalFile.processingFormat
        guard let trimmingBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let srcData = originalBuffer.floatChannelData,
              let dstData = trimmingBuffer.floatChannelData else { return }
        
        trimmingBuffer.frameLength = frameCount
        
        // vDSPを使用して高速コピー
        vDSP_mmov(srcData[0] + Int(startFrame),
                  dstData[0],
                  vDSP_Length(frameCount), 1,
                  vDSP_Length(originalBuffer.format.channelCount),
                  vDSP_Length(frameCount))
        
        // 3. ファイル名の生成と保存
        let fileName = "\(dateString)_\(String(format: "%.1f", seconds))s"
        let suffix = comment.isEmpty ? ".\(Config.fileExtension)" : "_\(comment).\(Config.fileExtension)"
        let outputURL = try getDocumentsDirectory().appendingPathComponent("\(fileName)\(suffix)")
        
        let outputFile = try AVAudioFile(forWriting: outputURL, settings: settings)
        try outputFile.write(from: trimmingBuffer)
        
        print("✅ Saved: \(outputURL.lastPathComponent)")
    }

    private func getDocumentsDirectory() throws -> URL {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "AudioFileManager", code: 404, userInfo: nil)
        }
        return url
    }

    // 元々の convertOriginalAudioFileToBuffer をメソッド化
    private func loadAudioFileToBuffer(fileURL: URL) -> AVAudioPCMBuffer? {
        guard let file = try? AVAudioFile(forReading: fileURL),
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else { return nil }
        try? file.read(into: buffer)
        return buffer
    }
}
