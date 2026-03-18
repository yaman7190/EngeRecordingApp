//
//  ContentView.swift
//  EngeRecordingApp
//
//  Created by user on 2023/10/21.,
//

import SwiftUI
import AVFoundation
import Combine
//import UIKit

struct ContentView: View {
    @State private var isRecording = false
    @State private var settingA = "Aボタン"
    @State private var settingB = "Bボタン"
    @AppStorage("settingA") var storedSettingA = "Aボタン"
    @AppStorage("settingB") var storedSettingB = "Bボタン"
    @State private var isSettingPresented = false
//    @State private var offset: CGFloat = UIScreen.main.bounds.width // 設定画面の初期位置は画面外
//    
//    // 処理のデバウンスのためのプロパティ
//    private var debounceTimeInterval: TimeInterval = 0.3
//    @ObservedObject private var debouncer = Debouncer()
//    @State private var isProcessing = false
//    
    @EnvironmentObject var viewModel: ResultViewModel
    @EnvironmentObject var audioModel: AudioModel
    @EnvironmentObject var modeSettings: ModeSettings
    @EnvironmentObject var resultOvserver: ResultObserver

//
    @State private var selectedTab = 0
    
    var historyPath: URL
    var historyPathString: String
//
    // publicまたはinternalを明示的に指定する
//    public init(viewModel: ResultViewModel) {
    public init() {
//        self.viewModel = viewModel
//        self.audioModel = AudioModel(modelName: "EngeSoundClassifier", viewModel: viewModel)
//        print("viewModel Adress @ContentView :\(Unmanaged.passUnretained(viewModel).toOpaque())")
        
        historyPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        do {
            try FileManager.default.createDirectory(at: historyPath, withIntermediateDirectories: true, attributes: nil)
            historyPathString = try String(contentsOf: historyPath)
        } catch {
            print("Error creating directory: \(error)")
            historyPathString = historyPath.path
        }
    }
    
    var body: some View {
        
//        ZStack {
//            VStack {
//                ZStack{
//                    // 波形表示エリア
//                    GeometryReader { geometry in
//                        Path { path in
//                            let width = geometry.size.width
//                            let height = geometry.size.height
//                            
////                            let numberOfPoints = audioModel.waveformData.count
//                            let numberOfPoints = 20000
//                            let xScale = width / CGFloat(numberOfPoints)
//                            let yScale = height / 2.0
//                            
//                            path.move(to: CGPoint(x: 0, y: height / 2))
//                            for (index, value) in self.audioModel.waveformData.enumerated() {
//                                let x = CGFloat(index) * xScale
//                                let y = CGFloat(value) * yScale + height / 2
//                                path.addLine(to: CGPoint(x: x, y: y))
//                            }
//                        }
//                        .stroke(Color.white, lineWidth: 2)
//                        .background(Color.black)
////                        .onReceive(self.audioModel.$waveformData) { newValue in
////                            print("waveformData was updated to \(newValue)")
////                        }
//                    }
//                }
//                .edgesIgnoringSafeArea(.all)
//                
//                VStack{
//                    Text("Identifier: \(self.viewModel.identifier)")
//                    Text("Confidence: \(self.viewModel.confidence)")
//                    GeometryReader { geometry in
//                        Slider(value: $audioModel.outputVolume, in: 0...10, step: 1)
//                            .frame(width: geometry.size.width * 0.9)
//                    }
//                }
////                .onReceive(viewModel.$identifier) { newValue in
////                    print("Identifier was updated to \(newValue)")
////                }
////                .onReceive(viewModel.$confidence) { newValue in
////                    print("Confidence was updated to \(newValue)")
////                }
//                
//                HStack {
//                    // Aボタン
//                    Button(action: {
//                        // 処理中であれば何もしない
//                        guard !isProcessing else { return }
//                        
//                        // 処理の開始
//                        isProcessing = true
//                        
//                        // Aボタンが押された時の処理
//                        audioModel.commentA = settingA
//                        audioModel.trimmingButtonAPressed()
//                        
//                        // 処理後、次の処理を受け付けるまでのデバウンス時間を設定
//                        Just(())
//                            .delay(for: .seconds(debounceTimeInterval), scheduler: RunLoop.main)
//                            .sink(receiveValue: { [self] _ in
//                                self.isProcessing = false
//                            })
//                            // SubscribersをDebouncerオブジェクトで管理する
//                            .store(in: &debouncer.subscribers)
//                    }) {
//                        Text(settingA)
//                            .padding()
//                            .background(Color.blue)
//                            .foregroundColor(.white)
//                            .cornerRadius(10)
//                    }
//                    .padding()
//                    .disabled(isProcessing) // 処理中はボタンを無効化
//                    
//                    // Bボタン
//                    Button(action: {
//                        // 処理中であれば何もしない
//                        guard !isProcessing else { return }
//                        
//                        // 処理の開始
//                        isProcessing = true
//                        
//                        // Bボタンが押された時の処理
//                        audioModel.commentB = settingB
//                        audioModel.trimmingButtonBPressed()
//                        
//                        // 処理後、次の処理を受け付けるまでのデバウンス時間を設定
//                        Just(())
//                            .delay(for: .seconds(debounceTimeInterval), scheduler: RunLoop.main)
//                            .sink(receiveValue: { [self] _ in
//                                self.isProcessing = false
//                            })
//                            // SubscribersをDebouncerオブジェクトで管理する
//                            .store(in: &debouncer.subscribers)
//                    }) {
//                        Text(settingB)
//                            .padding()
//                            .background(Color.green)
//                            .foregroundColor(.white)
//                            .cornerRadius(10)
//                    }
//                    .padding()
//                    .disabled(isProcessing) // 処理中はボタンを無効化
//                }
//                
//                Spacer()
//                
//                // Cボタン (Start/Stopトグル)
//                Button(action: {
//                    // 処理中であれば何もしない
//                    guard !isProcessing else { return }
//                    
//                    // 処理の開始
//                    isProcessing = true
//                    
//                    // Cボタンが押された時の処理
//                    isRecording.toggle()
//                    if audioModel.isRecording {
//                        // 録音を停止する処理
////                        audioModel.isRecording.toggle()
//                        
//                        audioModel.stopRecording()
//                        print("Is main thread @C-ButtonPressed: \(Thread.isMainThread)")
//                        
//                        print("Recording stopped  @C-ButtonPressed")
//                        print("isRecording  @C-ButtonPressed:\(audioModel.isRecording)")
//                        print("audioModel Adress @C-ButtonPressed :\(Unmanaged.passUnretained(audioModel).toOpaque())")
//                    } else {
//                        // 録音を開始する処理
//                        if !audioModel.isRecording {
////                            audioModel.isRecording.toggle()
//                            
//                            audioModel.startRecording()
//                            print("Is main thread @C-ButtonPressed: \(Thread.isMainThread)")
//                            
//                            print("Recording started @C-ButtonPressed")
//                            print("isRecording @C-ButtonPressed:\(audioModel.isRecording)")
//                            print("audioModel Adress @C-ButtonPressed :\(Unmanaged.passUnretained(audioModel).toOpaque())")
//                        }
//                    }
//                    
//                    // 処理後、次の処理を受け付けるまでのデバウンス時間を設定
//                    Just(())
//                        .delay(for: .seconds(debounceTimeInterval), scheduler: RunLoop.main)
//                        .sink(receiveValue: { [self] _ in
//                            self.isProcessing = false
//                        })
//                        // SubscribersをDebouncerオブジェクトで管理する
//                        .store(in: &debouncer.subscribers)
//                }) {
//                    Text(isRecording ? "Stop Recording" : "Start Recording")
//                        .padding()
//                        .background(Color.red)
//                        .foregroundColor(.white)
//                        .cornerRadius(10)
//                }
//                .padding()
//                .disabled(isProcessing) // 処理中はボタンを無効化
//                
//                Spacer()
//            }
//            .padding()
//            
//            // 設定画面
//            SettingsView(settingA: $settingA, settingB: $settingB, isPresented: $isSettingPresented)
//                .frame(width: UIScreen.main.bounds.width) // 設定画面の幅
//                .background(Color.white)
//            //                 .cornerRadius(20)
//                .offset(x: isSettingPresented ? 0 : UIScreen.main.bounds.width) // 表示/非表示で位置を変更
//            // 右から左にスワイプで設定画面を表示
//                .gesture(
//                    DragGesture()
//                        .onChanged { value in
//                            if value.translation.width < 0 {
//                                offset = value.translation.width
////                                print("UIScreen.main.bounds.width:\(UIScreen.main.bounds.width)")
////                                print("swipe translation.width(onChanged):\(value.translation.width)")
//                            }
//                        }
//                        .onEnded { value in
//                            withAnimation {
//                                // 画面の3分の1以上スワイプされた場合に設定画面を表示
//                                if -value.translation.width > UIScreen.main.bounds.width / 10 {
//                                    offset = 0
//                                    isSettingPresented = true
////                                    print("UIScreen.main.bounds.width:\(UIScreen.main.bounds.width)")
////                                    print("swipe translation.width(onEnded):\(value.translation.width)")
//                                } else {
//                                    // それ以外は元の位置に戻す
//                                    offset = UIScreen.main.bounds.width
//                                }
//                            }
//                        }
//                )
//            
//        }
        
        NavigationView {
            VStack {
                TabView(selection: $selectedTab) {
                    
                    //                        Text("HomeView")
                    //                            .tabItem {
                    //                                Image(systemName: "house.fill")
                    //                                Text("Home")
                    //                            }.tag(0)
                    
                    EngeRecordingView(settingA: $settingA, settingB: $settingB)
                        .padding(.bottom, 15)
                        .tabItem {
                            Image(systemName: "waveform.path.ecg.rectangle.fill")
                            Text("Record")
                        }.tag(1)
                    
                    HistoryView(path: historyPathString)
                        .padding(.bottom, 15)
                        .tabItem {
                            Image(systemName: "clock.fill")
                            Text("History")
                        }.tag(2)
                    
                    SettingView(settingA: $settingA, settingB: $settingB, modeSettings: self.modeSettings)
                        .padding(.bottom, 15)
                        .tabItem {
                            Image(systemName: "gearshape.fill")
                            Text("Setting")
                        }.tag(3)
                        .onAppear(perform: {
                            self.settingA = self.storedSettingA
                            self.settingB = self.storedSettingB
                        })
                        .onDisappear(perform: {
                            self.storedSettingA = self.settingA
                            self.storedSettingB = self.settingB
                        })
                }
            }
        }
    }
}

//class Debouncer: ObservableObject {
//    var subscribers = Set<AnyCancellable>()
//}
//
//extension Date {
//    func toString() -> String {
//        let dateFormatter = DateFormatter()
//        dateFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
//        return dateFormatter.string(from: self)
//    }
//}

@main
struct AudioRecordingApp: App {
//    @ObservedObject var viewModel = ResultViewModel() // ここでインスタンスを作成
//    var resultObserver = ResultObserver()
    // オブジェクトのインスタンス化
    @StateObject var modeSettings = ModeSettings()
    let resultViewModel = ResultViewModel()
    let audioModel: AudioModel
    let resultObserver: ResultObserver

    init() {
        self.resultObserver = ResultObserver(resultViewModel: resultViewModel)
        self.audioModel = AudioModel(modelName: "EngeSoundClassifier", resultObserver: resultObserver, resultViewModel: resultViewModel)
//        let observer = ResultObserver(viewModel: self.viewModel) // インスタンスをResultObserverに渡す
//        resultObserver = observer
//        print("viewModel Adress @AudioRecordingApp :\(Unmanaged.passUnretained(self.viewModel).toOpaque())")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(modeSettings)
                .environmentObject(audioModel)
                .environmentObject(resultViewModel)
                .environmentObject(resultObserver)
//                .onAppear(perform: {
//                    print("Object address @AudioRecordingApp: \(Unmanaged.passUnretained(self.modeSettings).toOpaque())")
//                })
        }
    }
}
