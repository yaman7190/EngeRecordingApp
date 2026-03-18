//
//  EngeRecordingView.swift
//  EngeRecordingApp
//
//  Created by user on 2024/02/22.
//

import SwiftUI
import AVFoundation
import Combine

struct EngeRecordingView: View {
    @State private var isRecording = false
//    @Binding var settingA: String
//    @Binding var settingB: String
    @AppStorage("settingA") var settingA = "Aボタン"
    @AppStorage("settingB") var settingB = "Bボタン"
    @State private var isSettingPresented = false
    
    // 処理のデバウンスのためのプロパティ
    private var debounceTimeInterval: TimeInterval = 0.3
    @ObservedObject private var debouncer = Debouncer()
    @State private var isProcessing = false
    
    @EnvironmentObject var resultViewModel: ResultViewModel
    @EnvironmentObject var audioModel: AudioModel
//    @ObservedObject var resultObserver: ResultObserver
    @EnvironmentObject var modeSettings: ModeSettings
    
    @State private var selectedTab = 0
    
    @State var isRedActive: Bool = false
    
    let screenWidth = UIScreen.main.bounds.width
    let screenHeight = UIScreen.main.bounds.height
    
    // むせ判定時に画面を赤くするための背景色定義
    var bgColor: Color {
        if (self.resultViewModel.identifier == "嚥下") && (self.resultViewModel.confidence >= 0.7) && (self.isRedActive == false) {
//            print("self.isRedActive:\(self.isRedActive)")
            return Color(.systemGroupedBackground)
        } 
//        else if (self.resultViewModel.identifier == "むせ") && (self.resultViewModel.confidence >= 0.7) {
////            print("self.isRedActive:\(self.isRedActive)")
//            return .red
//        }
//        else if self.isRedActive == true {
//            return .red
//        }
        else {
//            print("self.isRedActive:\(self.isRedActive)")
            return Color(.systemGroupedBackground)
        }
    }
    
    // publicまたはinternalを明示的に指定する
    public init(settingA: Binding<String>, settingB: Binding<String>) {
//    public init(viewModel: ResultViewModel, settingA: Binding<String>, settingB: Binding<String>) {
//        self.viewModel = viewModel
//        self.audioModel = AudioModel(modelName: "EngeSoundClassifier", viewModel: viewModel)
//        print("viewModel Adress @EngeRecordingView :\(Unmanaged.passUnretained(viewModel).toOpaque())")
//        self._settingA = settingA
//        self._settingB = settingB
//        self.resultObserver = ResultObserver(viewModel: viewModel)
    }
    
    var body: some View {
        VStack {
            // 波形表示エリア上のスペース
            Spacer().frame(height: self.screenHeight*0.025)
            
            ZStack{
                // 波形表示エリア
                GeometryReader { geometry in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    
                    ZStack{
                        Path { path in
                            // Vertical grid
                            for i in stride(from: 0, to: width, by: width/10) {
                                path.move(to: CGPoint(x: i, y: 0))
                                path.addLine(to: CGPoint(x: i, y: height))
                            }
                            
                            // Horizontal grid
                            for i in stride(from: 0, to: height, by: height/10) {
                                path.move(to: CGPoint(x: 0, y: i))
                                path.addLine(to: CGPoint(x: width, y: i))
                            }
                        }
                        .stroke(Color.gray.opacity(0.5), lineWidth: 0.5)
                        
                        Path { path in
                            let numberOfPoints = self.audioModel.waveformData.count
                            let xScale = width / CGFloat(numberOfPoints - 1)
                            let yScale = height / 2.0
                            
                            path.move(to: CGPoint(x: 0, y: height / 2))
                            for (index, value) in self.audioModel.waveformData.enumerated() {
                                let x = CGFloat(index) * xScale
                                let y = CGFloat(value) * yScale + height / 2
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        .stroke(Color.blue, lineWidth: 1)
                    }
                    .background(Color(white: 0.9))
                }
//                .frame(width: self.screenWidth*0.99, height: self.screenHeight*0.45)
            }
            .edgesIgnoringSafeArea(.all)
            .frame(width: self.screenWidth*0.99, height: self.screenHeight*0.45)
            
            // 波形エリアとコンテンツの間のスペース
            Spacer().frame(height: self.screenHeight*0.005)
//            Spacer()
            
            // コンテンツ（音声分類表示と音量）
            HStack(alignment: .center){
//                HStack{
//                    Spacer().frame(width: 10)
//                    GeometryReader { geometry in
                        VStack(alignment: .leading){
//                            Spacer().frame(height: self.screenHeight*0.01)
                            HStack {
                                Spacer().frame(width: 5)
                                Text("判定 　:  　")
                                //                                Spacer()
                                
                                if (self.resultViewModel.identifier == "嚥下"){
                                    Text("嚥下")
                                }else if (self.resultViewModel.identifier == "むせ"){
                                    Text("むせ")
                                }else {
                                    Text("なし")
                                }
                                
                                Spacer()
                            }
//                            .frame(width: geometry.size.width * 0.9, height: 10)
                            .frame(width: self.screenWidth*0.5, height: 10)
                            HStack {
                                Spacer().frame(width: 5)
                                Text("確信度 :  ")
                                Spacer()
                                Text("\(Int(floor(self.resultViewModel.confidence * 100)))")
                                Spacer()
                                Text(" %")
                                Spacer()
                            }
//                            .frame(width: geometry.size.width * 1.0, height: 10)
                            .frame(width: self.screenWidth*0.5, height: 10)
//                            Spacer()
                        }
//                    }
//                    Spacer()
//                }
                Spacer()
                HStack(alignment: .center){
//                    Spacer()
                    if (audioModel.outputVolume == 0) {
                        VStack{
//                            Spacer()
                            Spacer().frame(height: self.screenHeight*0.01)
                            Image(systemName: "speaker.slash.fill")
                                .resizable()
                                .frame(width: 20, height: 20)
    //                            .foregroundColor(.white)
                        }
                    } else if (audioModel.outputVolume == 1)||(audioModel.outputVolume == 2)||(audioModel.outputVolume == 3){
                        VStack{
//                            Spacer()
                            Spacer().frame(height: self.screenHeight*0.01)
                            Image(systemName: "speaker.wave.1.fill")
                                .resizable()
                                .frame(width: 20, height: 20)
    //                            .foregroundColor(.white)
                        }
                    } else if (audioModel.outputVolume == 4)||(audioModel.outputVolume == 5)||(audioModel.outputVolume == 6)||(audioModel.outputVolume == 7){
                        VStack{
//                            Spacer()
                            Spacer().frame(height: self.screenHeight*0.01)
                            Image(systemName: "speaker.wave.2.fill")
                                .resizable()
                                .frame(width: 20, height: 20)
                            //                            .foregroundColor(.white)
                        }
                    } else{
                        VStack{
//                            Spacer()
                            Spacer().frame(height: self.screenHeight*0.01)
                            Image(systemName: "speaker.wave.3.fill")
                                .resizable()
                                .frame(width: 20, height: 20)
                            //                            .foregroundColor(.white)
                        }
                    }
                    Spacer()
                    VStack{
//                        Spacer()
                        Spacer().frame(height: self.screenHeight*0.048)
                        GeometryReader { geometry in
                            Slider(value: $audioModel.outputVolume, in: 0...10, step: 1.0)
    //                            .frame(width: geometry.size.width * 0.8, height: 10)
                                .frame(width: self.screenWidth*0.35, height: 10)
                        }
//                        Spacer()
                    }
                    Spacer()
//                    Text("\(Int(floor(audioModel.outputVolume * 10)))")
                }
            }
            .frame(width: self.screenWidth*0.99, height: self.screenHeight*0.1)
            //A、Bボタンとコンテンツの間のスペース
            Spacer().frame(height: self.screenHeight*0.005)
            
            if self.modeSettings.isRecordingMode {
//                VStack{
//                    Spacer()
                    HStack{
                        // Aボタン
                        Button(action: {
                            // 処理中であれば何もしない
                            guard !isProcessing else { return }
                            
                            // 処理の開始
                            isProcessing = true
                            
                            // Aボタンが押された時の処理
                            audioModel.commentA = self.settingA
                            audioModel.trimmingButtonAPressed()
                            
                            // 処理後、次の処理を受け付けるまでのデバウンス時間を設定
                            Just(())
                                .delay(for: .seconds(debounceTimeInterval), scheduler: RunLoop.main)
                                .sink(receiveValue: { [self] _ in
                                    self.isProcessing = false
                                })
                            // SubscribersをDebouncerオブジェクトで管理する
                                .store(in: &debouncer.subscribers)
                        }) {
                            Text(self.settingA)
                                .frame(width: self.screenWidth*0.2, height: self.screenWidth*0.05)
                                .padding()
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(30)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 30)
                                        .stroke(Color.black, lineWidth: 0.5) // 枠線の色と太さを指定
                                )
                        }
                        .disabled(isProcessing) // 処理中はボタンを無効化
                        
                        //AボタンとBボタンの間の余白を固定
                        Spacer().frame(width: 50)
                        
                        // Bボタン
                        Button(action: {
                            // 処理中であれば何もしない
                            guard !isProcessing else { return }
                            
                            // 処理の開始
                            isProcessing = true
                            
                            // Bボタンが押された時の処理
                            audioModel.commentB = self.settingB
                            audioModel.trimmingButtonBPressed()
                            
                            // 処理後、次の処理を受け付けるまでのデバウンス時間を設定
                            Just(())
                                .delay(for: .seconds(debounceTimeInterval), scheduler: RunLoop.main)
                                .sink(receiveValue: { [self] _ in
                                    self.isProcessing = false
                                })
                            // SubscribersをDebouncerオブジェクトで管理する
                                .store(in: &debouncer.subscribers)
                        }) {
                            Text(self.settingB)
                                .frame(width: self.screenWidth*0.2, height: self.screenWidth*0.05)
                                .padding()
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(30)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 30)
                                        .stroke(Color.black, lineWidth: 0.5) // 枠線の色と太さを指定
                                )
                        }
                        .disabled(isProcessing) // 処理中はボタンを無効化
                    }
                    .frame(width: self.screenWidth*0.99, height: self.screenHeight*0.1)
//                    Spacer()
//                }
            } else{
                VStack(alignment: .leading) {
//                    Spacer()
                    HStack {
                        Spacer().frame(width: self.screenWidth*0.25)
                        Text("Lap1 :")
                        Spacer()
                        Text("\(self.resultViewModel.lap1)")
                        Spacer()
                        Text("s")
                        Spacer().frame(width: self.screenWidth*0.25)
                    }
                    HStack {
                        Spacer().frame(width: self.screenWidth*0.25)
                        Text("Lap2 :")
                        Spacer()
                        Text("\(self.resultViewModel.lap2)")
                        Spacer()
                        Text("s")
                        Spacer().frame(width: self.screenWidth*0.25)
                    }
                    HStack {
                        Spacer().frame(width: self.screenWidth*0.25)
                        Text("Lap3 :")
                        Spacer()
                        Text("\(self.resultViewModel.lap3)")
                        Spacer()
                        Text("s")
                        Spacer().frame(width: self.screenWidth*0.25)
                    }
//                    Spacer()
                }
                .frame(width: self.screenWidth*0.99, height: self.screenHeight*0.1)
            }
            
            //A、Bボタン/Lap表示とCボタンの間の余白を固定
            Spacer().frame(height: self.screenHeight*0.01)
            
            // Cボタン (Start/Stopトグル)
            Button(action: {
                // 処理中であれば何もしない
                guard !isProcessing else { return }
                
                // 処理の開始
                isProcessing = true
                modeSettings.isRecording.toggle()
                
                // Cボタンが押された時の処理
                isRecording.toggle()
                if audioModel.isRecording {
                    // 録音を停止する処理
                    //                        audioModel.isRecording.toggle()
                    
                    audioModel.stopRecording()
                    self.resultViewModel.identifier = ""
                    self.resultViewModel.confidence = 0.0
//                    print("Is main thread @C-ButtonPressed: \(Thread.isMainThread)")
//                    
//                    print("Recording stopped  @C-ButtonPressed")
//                    print("isRecording  @C-ButtonPressed:\(audioModel.isRecording)")
//                    print("audioModel Adress @C-ButtonPressed :\(Unmanaged.passUnretained(audioModel).toOpaque())")
                    print("self.modeSettings.isRecordingMode:\(self.modeSettings.isRecordingMode)")
                    print("Object address  @EngeRecordingView: \(Unmanaged.passUnretained(self.modeSettings).toOpaque())")
                } else {
                    // 録音を開始する処理
                    if !audioModel.isRecording {
                        //                            audioModel.isRecording.toggle()
                        
                        audioModel.startRecording()
//                        print("Is main thread @C-ButtonPressed: \(Thread.isMainThread)")
//                        
//                        print("Recording started @C-ButtonPressed")
//                        print("isRecording @C-ButtonPressed:\(audioModel.isRecording)")
//                        print("audioModel Adress @C-ButtonPressed :\(Unmanaged.passUnretained(audioModel).toOpaque())")
                        print("self.modeSettings.isRecordingMode:\(self.modeSettings.isRecordingMode)")
                        print("Object address  @EngeRecordingView: \(Unmanaged.passUnretained(self.modeSettings).toOpaque())")
                    }
                }
                
                // 処理後、次の処理を受け付けるまでのデバウンス時間を設定
                Just(())
                    .delay(for: .seconds(debounceTimeInterval), scheduler: RunLoop.main)
                    .sink(receiveValue: { [self] _ in
                        self.isProcessing = false
                    })
                // SubscribersをDebouncerオブジェクトで管理する
                    .store(in: &debouncer.subscribers)
            }) {
                Text(isRecording ? "Stop" : "Start")
//                    .padding()
                    .frame(width: self.screenWidth*0.35, height: self.screenWidth*0.35)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.black, lineWidth: 0.5) // 枠線の色と太さを指定
                    )
            }
            .disabled(isProcessing) // 処理中はボタンを無効化
            
            //Cボタン下のスペース
            Spacer().frame(height: self.screenHeight*0.025)
        }
//        .padding()
        .background(self.bgColor)
        .onChange(of: self.bgColor) { newValue in
            if newValue == .red {
                self.isRedActive = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { // 10秒後に実行
                    self.isRedActive = false
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }
    
//    func backgroundColorChange(){
//        if isRedActive { return }
//        
//        switch self.viewModel.identifier {
//        case "11（喉開き嚥下）", "12（喉開き無し嚥下）":
//            self.bgColor = .black
//            print("case1")
//        case "21（ムセ）", "22（溺れムセ）", "24（ムセて息を吸う）", "25（その他ムセ）":
//            self.bgColor = .red
//            self.isRedActive = true
//            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { // 指定秒後に背景色を変更
//                self.bgColor = .black
//                self.isRedActive = false
//            }
//            print("case2")
//        default:
//            self.bgColor = .black
//            print("case3")
//        }
//        print("self.bgColor:\(self.bgColor)")
//        print("self.isRedActive:\(self.isRedActive)")
//    }
}

struct EngeRecordingView_Previews: PreviewProvider {
    static var previews: some View {
        EngeRecordingView(settingA: .constant(""), settingB: .constant(""))
            .environmentObject(ResultViewModel())
            .environmentObject(AudioModel(modelName: "EngeSoundClassifier", resultObserver: ResultObserver(resultViewModel: ResultViewModel()), resultViewModel: ResultViewModel()))
            .environmentObject(ModeSettings())
    }
}

class Debouncer: ObservableObject {
    var subscribers = Set<AnyCancellable>()
}

extension Date {
    func toString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return dateFormatter.string(from: self)
    }
}
