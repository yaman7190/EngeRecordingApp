//
//  AudioModel.swift
//  EngeRecordingApp
//
//  Created by user on 2023/11/04.


import SwiftUI
import AVFoundation
import Foundation
import Accelerate
import SoundAnalysis

class AudioModel: ObservableObject {
    let audioEngine = AVAudioEngine()
    private let audioSession = AVAudioSession.sharedInstance()
    private let audioPlayerNode = AVAudioPlayerNode()
    private let audioMixerNode = AVAudioMixerNode()
    
    let waveformLengthInSeconds: Double = 3
    let samplesPerSecond: Double = 12000
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var audioFileforFull: AVAudioFile?
    private var audioFileURL: URL?
    private var audioFileforTrim: AVAudioFile?
    private var trimmingFileURL: URL?
    private var recordingStartTime: Date?
    private var trimmingTimestamps: [Double] = []
    private var nowDate: String = ""
    private var nowTimeA: Double?
    private var nowTimeB: Double?
    private var nowTimeA_Array: [Double] = []
    private var nowTimeB_Array: [Double] = []
    
//    @Published var waveformData: [Float] = []
    var waveformData: [Float] {
        didSet {
            DispatchQueue.main.async {
                // データの変更を通知
                self.objectWillChange.send()
            }
        }
    }
//    @Published var isRecording: Bool?
    @Published var isRecording = false {
        didSet {
            print("isRecording changed: \(isRecording)")
        }
    }
    @Published var isPlaying: Bool = false
    @Published var audioDataforTrimming: [Float] = []
    @Published var commentA: String = ""
    @Published var commentB: String = ""
    
    let dataformat_for_filename: String = "yyyyMMdd_HHmmss"
    let dateFormatter = DateFormatter()
    
    private var soundClassifier: MLModel?
    private var streamAnalyzer: SNAudioStreamAnalyzer?
//    var viewModel: ResultViewModel?
    var resultViewModel = ResultViewModel()
    var resultObserver: ResultObserver
//    var resultObserver: ResultObserver?
//    var resultObserver = ResultObserver()
    
//    var i: Int = 0
    
    @Published var outputVolume: Float = 1.0
    
//    init(modelName: String, viewModel: ResultViewModel) {
    init(modelName: String, resultObserver: ResultObserver, resultViewModel: ResultViewModel) {
        self.resultViewModel = resultViewModel
        self.resultObserver = ResultObserver(resultViewModel: resultViewModel)
        waveformData = []
        setupAudioSession()
//        i = i + 1
//        print("\(i)回目の初期化をしています...")
        
//        self.initialize()
    
//        self.viewModel = viewModel
//        resultObserver = ResultObserver(viewModel: self.viewModel)
//        resultObserver = ResultObserver()
//        print("viewModel Adress @AudioModel :\(Unmanaged.passUnretained(self.viewModel!).toOpaque())")
        
        dateFormatter.dateFormat = dataformat_for_filename
        dateFormatter.locale = Locale.current
        dateFormatter.timeZone = TimeZone.current
        
        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") else {
            fatalError("モデルファイルが見つかりませんでした。")
        }
        do {
            let soundClassifier = try MLModel(contentsOf: modelURL)
            self.soundClassifier = soundClassifier
            self.streamAnalyzer = SNAudioStreamAnalyzer(format: audioEngine.inputNode.inputFormat(forBus: 0))
//            print("modelURL:\(modelURL)")
//            print("soundClassifier_init:\(String(describing: self.soundClassifier))")
        } catch {
            fatalError("モデルを読み込むことができませんでした: \(error)")
        }
    }

    private func setupAudioSession() {
//        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            // 利用可能なオーディオ入力と出力のポートを列挙する
            let inputs = audioSession.availableInputs
            let outputs = audioSession.currentRoute.outputs
            
            // 特定の入力デバイス（例：有線マイク）を選択する
            if let wiredMicInput = inputs?.first(where: { $0.portType == .headsetMic }) {
               try audioSession.setPreferredInput(wiredMicInput)
            } else {
               print("有線マイクが見つかりません")
            }

            // 特定の出力デバイス（例えば Bluetooth デバイス）を選択する
            if outputs.contains(where: { $0.portType == .bluetoothA2DP }) {
                try audioSession.overrideOutputAudioPort(AVAudioSession.PortOverride.none)
            } else {
               print("Bluetoothデバイスが見つかりません")
            }
            
//            try audioSession.setCategory(AVAudioSession.Category.playAndRecord, options: [.allowBluetoothA2DP, .defaultToSpeaker])
            try audioSession.setCategory(.playAndRecord, options: [.allowBluetoothA2DP])
            try audioSession.setMode(.default) // 必要であれば特定のモードを設定、.measurement: 高品質なオーディオ録音が必要な場合に、システムのオーディオ処理を最小限に抑えるモード
            try audioSession.setPreferredSampleRate(24000.0)
            try audioSession.setActive(true)
            
            
        } catch {
            print("Error setupAudioSession: \(error)")
        }
        
    }

    private func setupAudioEngine() {
        guard let documentsDirectoryforFull = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        nowDate = "\(self.dateFormatter.string(from: Date()))"
        audioFileURL = documentsDirectoryforFull.appendingPathComponent("\(nowDate)_full.caf")
        print("audioFileURL:\(audioFileURL!)")
        
        
        // 音声データの初期化
        self.waveformData.removeAll()
        self.audioDataforTrimming.removeAll()
        
        
        do {
            audioFileforFull = try AVAudioFile(forWriting: audioFileURL!, settings: audioEngine.inputNode.outputFormat(forBus: 0).settings)
            
            //
//            print("soundClassifier_setup:\(String(describing: self.soundClassifier))")
            guard let soundClassifier = soundClassifier else {
                fatalError("soundClassifierがnilです。")
            }
            if let classifySoundRequest = try? SNClassifySoundRequest(mlModel: soundClassifier) {
                try streamAnalyzer?.add(classifySoundRequest, withObserver: self.resultObserver)
            }
        } catch {
            print("Error creating audio file: \(error)")
            return
        }
        
        //setUpNodes
        let inputNode = audioEngine.inputNode
        let mixer = audioEngine.mainMixerNode
        // 出力のフォーマットを入力に合わせる
        let outputFormat = inputNode.outputFormat(forBus: 0)
        
//        // 出力用の音量調整
//        DispatchQueue.main.async {
//            mixer.outputVolume = self.outputVolume
//        }
        
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 2400, format: nil, block: {(buffer, time) in
//        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1, format: nil, block: {[unowned self] (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
//            print("(buffer, time):(\(buffer),\(time))")
            
            //
//            self.streamAnalyzer?.analyze(buffer, atAudioFramePosition: when.sampleTime)
            self.streamAnalyzer?.analyze(buffer, atAudioFramePosition: time.sampleTime)
            
            // ここで波形データを更新
            self.updateWaveform(buffer: buffer)
            
            
            // 出力用の音量調整
            DispatchQueue.main.async {
                mixer.outputVolume = self.outputVolume
            }
            
            // ここで buffer のデータをファイルに書き込む
            do {
                try self.audioFileforFull?.write(from: buffer)
                // マイクからのバッファをそのまま再生
                self.audioPlayerNode.scheduleBuffer(buffer)
                if !self.audioPlayerNode.isPlaying {
                    self.audioPlayerNode.play()
                }
            } catch {
                print("Error writing to audio file: \(error)")
            }
        })
        
        // Connect nodes
        audioEngine.connect(audioPlayerNode, to: audioEngine.mainMixerNode, format: outputFormat)
        
        
        audioEngine.prepare()
        
        if !audioEngine.isRunning {
//            print("audioEngine.isRunning before try start:\(audioEngine.isRunning)")
            do {
                usleep(250000)
                try audioEngine.start()
            } catch{
                print("audioEngine.start() is eror:\(error)")
            }
//            print("audioEngine.isRunning after try start:\(audioEngine.isRunning)")
            recordingStartTime = Date() // 開始時間を記録
        }
//        print("audioEngine_start:\(audioEngine)")
        print("setupaudioEngine is finished.")
    }
    
    private func resetAudioEngine() {
        audioEngine.stop()
        audioEngine.reset()
//        audioEngine.inputNode.removeTap(onBus: 0)
//        audioEngine.outputNode.removeTap(onBus: 0)
        audioEngine.detach(audioPlayerNode)
        audioEngine.attach(audioPlayerNode)
//        audioEngine.detach(audioMixerNode)
//        audioEngine.attach(audioMixerNode)
//        print("audioEngine_before setup:\(audioEngine)")
//        setupAudioEngine()
//        print("audioEngine_after setup:\(audioEngine)")
        print("resetAudioEngine is finished.")
    }
    
    private func updateWaveform(buffer: AVAudioPCMBuffer) {
        // 波形データの追加
        let floatBuffer = UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength))
        self.waveformData.append(contentsOf: floatBuffer)
//        print("Int(buffer.frameLength):\(Int(buffer.frameLength))")
//        print("self.waveformData.count:\(self.waveformData.count)")
        
        // 最新の10秒間のデータのみ保持
        let maximumSamplesToKeep = Int(waveformLengthInSeconds * samplesPerSecond)
        
        if self.waveformData.count > maximumSamplesToKeep {
            
            let samplesToRemove = self.waveformData.count - maximumSamplesToKeep
            self.waveformData.removeFirst(samplesToRemove)
            
//            print("self.waveformData.count:\(self.waveformData.count)")
//            print("maximumSamplesToKeep:\(maximumSamplesToKeep)")
//            print("samplesToRemove:\(samplesToRemove)")
        }
        
//        DispatchQueue.main.async {
//            // データの変更を通知
//            self.objectWillChange.send()
//        }
        
//        print("self.outputVolume:\(self.outputVolume)")
//        print("self.waveformData.count:\(self.waveformData.count)")
//        print("self.waveformData:\(self.waveformData)")
    }
    
    func startRecording() {
        self.isRecording.toggle()
        print("Is main thread @audioModel startRecording: \(Thread.isMainThread)")
//        print("audioModel Adress @audioModel startRecording :\(Unmanaged.passUnretained(self).toOpaque())")
        
        // lapの初期化
        self.resultViewModel.lap1 = 0.0
        self.resultViewModel.lap2 = 0.0
        self.resultViewModel.lap3 = 0.0
        
        nowTimeA_Array.removeAll()
        nowTimeB_Array.removeAll()
//        setupAudioSession()
        self.resetAudioEngine()
        self.setupAudioEngine()
    }

    func stopRecording() {
        self.isRecording.toggle()
//        print("Is main thread @audioModel stopRecording: \(Thread.isMainThread)")
        
        if audioEngine.isRunning {
//            print("audioEngine.isRunning before stop:\(audioEngine.isRunning)")
            audioEngine.stop()
//            print("audioEngine.isRunning after stop:\(audioEngine.isRunning)")
            audioEngine.reset()
//            setupAudioSession()

            // Audio sessionを停止
            do {
                try audioSession.setActive(false)
            } catch{
                print("audioSession.setActive(false) is eror:\(error)")
            }
        } else {
            print("audioEngine is not runnning.")
        }
        
        // Tapを削除（登録したままにすると次に Installした時点でエラーになる
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.outputNode.removeTap(onBus: 0)
        audioEngine.detach(audioPlayerNode)
        audioEngine.inputNode.reset()
        audioEngine.outputNode.reset()
        
        //
        streamAnalyzer?.removeAllRequests()
        
        // 嚥下タイムラップ表示の初期化
        self.resultObserver.engeCount = 0
        self.resultObserver.engeTime = nil
        self.resultObserver.timeLapArray = [nil, nil, nil, nil]
        self.resultObserver.lap1 = 0.0
        self.resultObserver.lap2 = 0.0
        self.resultObserver.lap3 = 0.0

        // 非同期で重い処理をglobalキューでバックグラウンド実行
        DispatchQueue.global(qos: .userInitiated).async {
            self.saveTrimmedAudioFile()
        }
//        print("audioEngine_stop:\(audioEngine)")
    }
    
    func saveTrimmedAudioFile() {
        guard let documentsDirectoryforTrim = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let nowDate: String = "\(self.dateFormatter.string(from: Date()))"
        
        if nowTimeA_Array.count != 0 {
            for positionInSeconds in nowTimeA_Array {
                do {
                    // 元の音声ファイルを読み込む
                    let originalFile = try AVAudioFile(forReading: audioFileURL!)
                    // 元の音声ファイルをバッファに読み込む
                    let originalFileBuffer = convertOriginalAudioFileToBuffer(fileURL: audioFileURL!)
                    
                    // 指定位置から前後3秒分の範囲を抽出
                    let positionInSamples = AVAudioFramePosition(positionInSeconds * originalFile.processingFormat.sampleRate)
                    
                    var startFrame: Int64 = 0
                    var endFrame: Int64 = 0
                    // トリミングボタンが開始３秒未満で押された場合は０秒をトリミング開始位置とする
                    if positionInSeconds<3 {
                        startFrame = 0
                    } else {
                        startFrame = positionInSamples - Int64(originalFile.processingFormat.sampleRate * 3)
                    }
                    
                    let lastFrame = AVAudioFramePosition(originalFileBuffer!.frameLength)
                    // StopRecordingボタンがトリミングボタン押下後３秒未満で押された場合は最後のフレームをトリミング終了位置とする
                    if (lastFrame-positionInSamples)<Int64(originalFile.processingFormat.sampleRate * 3){
                        endFrame = lastFrame
                    } else{
                        endFrame = positionInSamples + Int64(originalFile.processingFormat.sampleRate * 3)
                    }
                    
                    let frameCount_trimming = AVAudioFrameCount(endFrame - startFrame)
                    
//                    print("positionInSamples:\(positionInSamples)")
//                    print("positionInSeconds:\(positionInSeconds)")
//                    print("originalFile.processingFormat.sampleRate:\(originalFile.processingFormat.sampleRate)")
//                    print("Int64(originalFile.processingFormat.sampleRate * 3):\(Int64(originalFile.processingFormat.sampleRate * 3))")
//                    print("frameCount_trimming:\(frameCount_trimming)")
                    
                    // AVAudioPCMBufferを作成
                    let audioFormat = originalFile.processingFormat
                    let trimmingBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount_trimming)
                    try originalFile.read(into: trimmingBuffer!)
//                    print("★trimmingBuffer:\(trimmingBuffer!)")
//                    print("★trimmingBuffer type:\(type(of: trimmingBuffer!))")
                    
                    // オリジナルのバッファの指定した位置からのデータをコピー
                    if let floatChannelData = originalFileBuffer!.floatChannelData {
                        if let trimmingFileChannelData = trimmingBuffer!.floatChannelData {
                            let channel = 0
                            print("-------------------------")
                            print("originalFileBuffer!.frameLength:\(originalFileBuffer!.frameLength)")
                            print("originalFileBuffer!.format.channelCount:\(originalFileBuffer!.format.channelCount)")
                            print("trimmingBuffer!.frameLength:\(trimmingBuffer!.frameLength)")
                            print("floatChannelData:\(floatChannelData)")
                            print("floatChannelData[channel]:\(floatChannelData[channel])")
                            print("trimmingFileChannelData:\(trimmingFileChannelData)")
                            print("trimmingFileChannelData[channel]:\(trimmingFileChannelData[channel])")
                            print("Int(startFrame):\(Int(startFrame))")
                            print("frameCount_trimming:\(frameCount_trimming)")
                            print("originalframe-trimmingframe:\(Int(originalFileBuffer!.frameLength)-Int(trimmingBuffer!.frameLength))")
                            print("-------------------------")
                            
                            vDSP_mmov(floatChannelData[channel] + Int(startFrame), trimmingFileChannelData[channel], vDSP_Length(frameCount_trimming), 1, vDSP_Length(originalFileBuffer!.format.channelCount), vDSP_Length(frameCount_trimming))
                        } else {
                            print("Error: trimmingFileChannelData is nil")
                        }
                    } else {
                        print("Error: floatChannelData is nil")
                    }
                    
                    // 新しい音声ファイルを作成
                    let fileName = "\(nowDate)_\(String(format: "%.1f", positionInSeconds))s"
                    let commentSuffix = commentA.isEmpty ? ".caf" : "_\(commentA).caf"
                    trimmingFileURL = documentsDirectoryforTrim.appendingPathComponent("\(fileName)\(commentSuffix)")
                    let trimmingFile = try AVAudioFile(forWriting: trimmingFileURL!, settings: audioEngine.inputNode.outputFormat(forBus: 0).settings)
//                    print("audioEngine.inputNode.outputFormat(forBus: 0).settings:\(audioEngine.inputNode.outputFormat(forBus: 0).settings)")
                    
//                    print("★originalFileBuffer:\(originalFileBuffer!)")
//                    print("★trimmingBuffer:\(trimmingBuffer!)")
//                    print("★originalFileBuffer type:\(type(of: originalFileBuffer!))")
//                    print("★trimmingBuffer type:\(type(of: trimmingBuffer!))")
//                    print("★originalFile.processingFormat:\(originalFile.processingFormat)")
//                    print("★trimmingFile.processingFormat:\(trimmingFile.processingFormat)")
//                    print("trimmingFileChannelData[0][0]:\(trimmingBuffer!.floatChannelData![0][0])")
//                    print("trimmingFileChannelData[0][1]:\(trimmingBuffer!.floatChannelData![0][1])")
//                    print("trimmingFileChannelData[0][2]:\(trimmingBuffer!.floatChannelData![0][2])")
//                    print("trimmingFileChannelData[0][Int(frameCount_trimming)]:\(trimmingBuffer!.floatChannelData![0][Int(frameCount_trimming)])")
                    
                    // 抽出したデータを新しいファイルに書き込む
                    try trimmingFile.write(from: trimmingBuffer!)
                    
                    print("Extraction and saving successful.")
                } catch {
                    print("Error: \(error)")
                }
            }
        }
        
        if nowTimeB_Array.count != 0 {
            for positionInSeconds in nowTimeB_Array {
                do {
                    // 元の音声ファイルを読み込む
                    let originalFile = try AVAudioFile(forReading: audioFileURL!)
                    // 元の音声ファイルをバッファに読み込む
                    let originalFileBuffer = convertOriginalAudioFileToBuffer(fileURL: audioFileURL!)
                    
                    // 指定位置から前後3秒分の範囲を抽出
                    let positionInSamples = AVAudioFramePosition(positionInSeconds * originalFile.processingFormat.sampleRate)
                    
                    var startFrame: Int64 = 0
                    var endFrame: Int64 = 0
                    // トリミングボタンが開始３秒未満で押された場合は０秒をトリミング開始位置とする
                    if positionInSeconds<3 {
                        startFrame = 0
                    } else {
                        startFrame = positionInSamples - Int64(originalFile.processingFormat.sampleRate * 3)
                    }
                    
                    let lastFrame = AVAudioFramePosition(originalFileBuffer!.frameLength)
                    // StopRecordingボタンがトリミングボタン押下後３秒未満で押された場合は最後のフレームをトリミング終了位置とする
                    if (lastFrame-positionInSamples)<Int64(originalFile.processingFormat.sampleRate * 3){
                        endFrame = lastFrame
                    } else{
                        endFrame = positionInSamples + Int64(originalFile.processingFormat.sampleRate * 3)
                    }
                    
                    let frameCount_trimming = AVAudioFrameCount(endFrame - startFrame)
                    
                    // AVAudioPCMBufferを作成
                    let audioFormat = originalFile.processingFormat
                    let trimmingBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount_trimming)
                    try originalFile.read(into: trimmingBuffer!)
//                    print("★trimmingBuffer:\(trimmingBuffer!)")
//                    print("★trimmingBuffer type:\(type(of: trimmingBuffer!))")
                    
                    // オリジナルのバッファの指定した位置からのデータをコピー
                    if let floatChannelData = originalFileBuffer!.floatChannelData {
                        if let trimmingFileChannelData = trimmingBuffer!.floatChannelData {
                            let channel = 0
                            print("-------------------------")
                            print("originalFileBuffer!.frameLength:\(originalFileBuffer!.frameLength)")
                            print("originalFileBuffer!.format.channelCount:\(originalFileBuffer!.format.channelCount)")
                            print("trimmingBuffer!.frameLength:\(trimmingBuffer!.frameLength)")
                            print("floatChannelData:\(floatChannelData)")
                            print("floatChannelData[channel]:\(floatChannelData[channel])")
                            print("trimmingFileChannelData:\(trimmingFileChannelData)")
                            print("trimmingFileChannelData[channel]:\(trimmingFileChannelData[channel])")
                            print("Int(startFrame):\(Int(startFrame))")
                            print("frameCount_trimming:\(frameCount_trimming)")
                            print("originalframe-trimmingframe:\(Int(originalFileBuffer!.frameLength)-Int(trimmingBuffer!.frameLength))")
                            print("-------------------------")
                            
                            if (Int(originalFileBuffer!.frameLength)-Int(trimmingBuffer!.frameLength))>=0 {
                                vDSP_mmov(floatChannelData[channel] + Int(startFrame), trimmingFileChannelData[channel], vDSP_Length(frameCount_trimming), 1, vDSP_Length(originalFileBuffer!.format.channelCount), vDSP_Length(frameCount_trimming))
                            } else{
                                print("error originalframe-trimmingframe:\(Int(originalFileBuffer!.frameLength)-Int(trimmingBuffer!.frameLength))")
                            }
                        } else {
                            print("Error: trimmingFileChannelData is nil")
                        }
                    } else {
                        print("Error: floatChannelData is nil")
                    }
                    
                    // 新しい音声ファイルを作成
                    let fileName = "\(nowDate)_\(String(format: "%.1f", positionInSeconds))s"
                    let commentSuffix = commentB.isEmpty ? ".caf" : "_\(commentB).caf"
                    trimmingFileURL = documentsDirectoryforTrim.appendingPathComponent("\(fileName)\(commentSuffix)")
                    let trimmingFile = try AVAudioFile(forWriting: trimmingFileURL!, settings: audioEngine.inputNode.outputFormat(forBus: 0).settings)

                    // 抽出したデータを新しいファイルに書き込む
                    try trimmingFile.write(from: trimmingBuffer!)
                    
                    print("Extraction and saving successful.")
                } catch {
                    print("Error: \(error)")
                }
            }
        }
    }
    
    func trimmingButtonAPressed() {
        print("trimmingButtonA was Pressed. @AudioModel")
        if self.isRecording{
            self.saveSecondsforTrimA()
            print("Is main thread @trimmingButtonAPressed: \(Thread.isMainThread)")
        }
    }
    
    func trimmingButtonBPressed() {
        print("trimmingButtonB was Pressed. @AudioModel")
        if self.isRecording {
            self.saveSecondsforTrimB()
            print("Is main thread @trimmingButtonBPressed: \(Thread.isMainThread)")
        }
    }
    
    func saveSecondsforTrimA() {
        guard let startTime = recordingStartTime else { return }
        nowTimeA = Date().timeIntervalSince(startTime)
        nowTimeA_Array.append(nowTimeA!)
        print("nowTimeA_Array:\(nowTimeA_Array)")
    }
    
    func saveSecondsforTrimB() {
        guard let startTime = recordingStartTime else { return }
        nowTimeB = Date().timeIntervalSince(startTime)
        nowTimeB_Array.append(nowTimeB!)
        print("nowTimeB_Array:\(nowTimeB_Array)")
    }
    
    func convertOriginalAudioFileToBuffer(fileURL: URL) -> AVAudioPCMBuffer? {
        do {
            // AVAudioFileを作成
            let originalFile = try AVAudioFile(forReading: fileURL)
            // AVAudioPCMBufferを作成
            let audioFormat = originalFile.processingFormat
            let audioFrameCount = AVAudioFrameCount(originalFile.length)
//            print("audioFrameCount:\(audioFrameCount)")
            guard let audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: audioFrameCount) else {
                return nil
            }

            // AVAudioFileからAVAudioPCMBufferにデータを読み込む
            try originalFile.read(into: audioBuffer)
//            print("★audioBuffer:\(audioBuffer)")
//            print("★audioBuffer type:\(type(of: audioBuffer))")

            return audioBuffer
        } catch {
            print("Error converting audio file to buffer: \(error)")
            return nil
        }
    }
}

class ResultObserver: NSObject, SNResultsObserving, ObservableObject {
    var resultViewModel = ResultViewModel()
    var identifier: String = ""
    var confidence: Float = 0.0
    
    var engeCount: Int = 0
    var engeTime: Date? = nil
    var timeLapArray: [Date?] = [nil, nil, nil, nil]
    var lap1: Double = 0.0
    var lap2: Double = 0.0
    var lap3: Double = 0.0
    var isUpdateActive: Bool = true
    
//    @EnvironmentObject var modeSettings = ModeSettings()
    
//    init(viewModel: ResultViewModel) {
    init(resultViewModel: ResultViewModel) {
        self.resultViewModel = resultViewModel
//        self.viewModel = viewModel
//        print("viewModel Adress @ResultOvserver :\(Unmanaged.passUnretained(self.viewModel).toOpaque())")
    }
    
    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult else { return }
        guard let classification = result.classifications.first else { return }
        
        identifier = classification.identifier
        confidence = Float(classification.confidence)
        
        if (confidence >= 0.7)&&(self.isUpdateActive == true) {
            updateValue(identifier: identifier, confidence: confidence)
            timeLapEnge(identifier: identifier)
            self.isUpdateActive = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { // 1秒後に実行
                self.isUpdateActive = true
            }
        }
    }
    
    func updateValue(identifier: String, confidence: Float) {
        // ViewModelを更新
        DispatchQueue.main.async {
            self.resultViewModel.identifier = identifier
            self.resultViewModel.confidence = confidence
        }
//        print("self.viewModel.identifier: \(self.viewModel.identifier), self.viewModel.confidence: \(self.viewModel.confidence)")
    }
    
    func timeLapEnge(identifier: String) {
//        if (identifier == "11（喉開き嚥下）" || identifier == "12（喉開き無し嚥下）") {
        if (identifier == "嚥下")||(identifier == "むせ") {
            engeCount += 1
            
            if (engeCount == 1) {
                engeTime = Date()
                self.timeLapArray.removeAll()
                self.timeLapArray = [engeTime!, engeTime!, engeTime!, engeTime!]
//                print("engeCount:\(engeCount)")
//                print("timeLapArray:\(self.timeLapArray)")
//                print("lap1:\(self.resultViewModel.lap1)")
//                print("lap2:\(self.resultViewModel.lap2)")
//                print("lap3:\(self.resultViewModel.lap3)")
            } else if (engeCount == 2 || engeCount == 3 || engeCount == 4) {
                engeTime = Date()
                self.timeLapArray[engeCount-1] = engeTime
                
                switch engeCount{
                case 2:
                    self.resultViewModel.lap1 = self.timeLapArray[1]!.timeIntervalSince(self.timeLapArray[0]!)
                case 3:
                    self.resultViewModel.lap1 = self.timeLapArray[1]!.timeIntervalSince(self.timeLapArray[0]!)
                    self.resultViewModel.lap2 = self.timeLapArray[2]!.timeIntervalSince(self.timeLapArray[1]!)
                case 4:
                    self.resultViewModel.lap1 = self.timeLapArray[1]!.timeIntervalSince(self.timeLapArray[0]!)
                    self.resultViewModel.lap2 = self.timeLapArray[2]!.timeIntervalSince(self.timeLapArray[1]!)
                    self.resultViewModel.lap3 = self.timeLapArray[3]!.timeIntervalSince(self.timeLapArray[2]!)
                default:
                    break
                }
//                print("engeCount:\(engeCount)")
//                print("timeLapArray:\(self.timeLapArray)")
//                print("lap1:\(self.resultViewModel.lap1)")
//                print("lap2:\(self.resultViewModel.lap2)")
//                print("lap3:\(self.resultViewModel.lap3)")
            } else {
                engeTime = Date()
                self.timeLapArray.removeFirst()
                self.timeLapArray.append(engeTime!)
                self.resultViewModel.lap1 = self.timeLapArray[1]!.timeIntervalSince(self.timeLapArray[0]!)
                self.resultViewModel.lap2 = self.timeLapArray[2]!.timeIntervalSince(self.timeLapArray[1]!)
                self.resultViewModel.lap3 = self.timeLapArray[3]!.timeIntervalSince(self.timeLapArray[2]!)
//                print("engeCount:\(engeCount)")
//                print("timeLapArray:\(self.timeLapArray)")
//                print("lap1:\(self.resultViewModel.lap1)")
//                print("lap2:\(self.resultViewModel.lap2)")
//                print("lap3:\(self.resultViewModel.lap3)")
            }
        }
    }
}

class ResultViewModel: ObservableObject {
    var engeRecordingView: EngeRecordingView?
    var identifier: String = ""
    var confidence: Float = 0.0
    var lap1: Double = 0.0
    var lap2: Double = 0.0
    var lap3: Double = 0.0
    
    init() {
        self.engeRecordingView = EngeRecordingView(settingA: .constant(""), settingB: .constant(""))
    }
}
