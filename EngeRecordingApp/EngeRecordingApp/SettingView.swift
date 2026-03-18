//
//  SettingView.swift
//  EngeRecordingApp
//
//  Created by user on 2023/11/17.
//

import SwiftUI
import Foundation
import AVKit

struct SettingView: View {
    @Binding var settingA: String
    @Binding var settingB: String
//    @Binding var isPresented: Bool
    @State private var isKeyboardVisible = false
    @EnvironmentObject var modeSettings: ModeSettings
//    @ObservedObject var audioModel = AudioModel(modelName: "EngeSoundClassifier", viewModel: ResultViewModel())
    @EnvironmentObject var audioModel: AudioModel
    
    init(settingA: Binding<String>, settingB: Binding<String>, modeSettings: ModeSettings) {
        self._settingA = settingA
        self._settingB = settingB
    }

    var body: some View {
        NavigationView {
            VStack{
                Form {
                    Section(header: Text("下記に入力したテキストが、トリミングするファイル名に追加されます")) {
                        TextField("左ボタンのテキストを入力　例：水泡音", text: $settingA)
                        TextField("右ボタンのテキストを入力　例：むせ", text: $settingB)
                    }
                    HStack{
                        Spacer().frame(width: 5)
                        Text("音声出力先の変更")
                        Spacer()
                        RoutePickerView()
                            .frame(width: 40, height: 40) // 適宜サイズを調整
                        Spacer().frame(width: 5)
                    }
                    // 記録モードの切り替え
                    HStack{
                        Spacer().frame(width: 5)
                        Toggle(isOn: $modeSettings.isRecordingMode) {
                            Text(modeSettings.isRecordingMode ? "記録モード  ON" : "記録モード  OFF")
                        }
//                        .disabled(modeSettings.isRecording)
                        .disabled(audioModel.isRecording)
                        Spacer().frame(width: 5)
                    }
                }
                
            }
            .navigationBarTitle("設定", displayMode: .inline)
            .onAppear {
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { (notification) in
                    self.isKeyboardVisible = true
                }

                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { (notification) in
                    self.isKeyboardVisible = false
                }
            }
        } 
        .background(Color(.systemGroupedBackground))
    }
}

struct RoutePickerView: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let routePickerView = AVRoutePickerView()
        routePickerView.activeTintColor = .green
        routePickerView.tintColor = .gray
        // ここで必要なスタイリングや設定を行います
        return routePickerView
    }
  
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        // UIViewの更新時に行いたい処理をここで行います
    }
}

class ModeSettings: ObservableObject {
    @Published var isRecordingMode: Bool = true {
        didSet {
            print("Recording mode is now: \(isRecordingMode ? "ON" : "OFF")")
        }
    }
    @Published var isRecording: Bool = false {
        didSet {
            print("isRecording is now: \(isRecording ? "true" : "false")")
        }
    }

//    init() {
//        self.isRecordingMode = true
//        self.isRecording = false
//        print("Object address  @SettingView: \(Unmanaged.passUnretained(self).toOpaque())")
//    }
}
