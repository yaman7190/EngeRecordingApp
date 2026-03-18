//
//  AudioFileManager.swift
//  EngeRecordingApp
//
//  Created by user on 2026/03/18.
//

import Foundation
import AVFoundation

/// 録音ファイルの保存、管理、トリミングを専門に担当するクラス
final class AudioFileManager {
    
    // 設定値を一箇所にまとめる（マジックナンバーの排除）
    enum Config {
        static let trimmingWindow: TimeInterval = 3.0 // 前後3秒
        static let fileExtension = "caf"
    }
    
    // エラー定義（何が起きたか自作アプリ内で明確にするため）
    enum FileError: Error {
        case directoryNotFound
        case trimmingFailed(String)
    }
    
    // MARK: - Properties
    
    private let fileManager = FileManager.default
    
    // MARK: - Utilities
    
    /// 保存先のDocumentディレクトリを取得
    func getDocumentsDirectory() -> URL? {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    // TODO: ここに AudioModel からトリミングロジックを移植する
}
