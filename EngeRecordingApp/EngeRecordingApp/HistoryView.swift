//
//  HistoryView.swift
//  EngeRecordingApp
//
//  Created by user on 2024/02/22.
//

// 一括消去、お気に入り以外のやつを★


import SwiftUI
import AVFoundation

struct HistoryView: View {
    let fileManager = FileManager.default
    let path: String
    @State var filePath: String? = nil
    @State var files: [String] = []
    var sortedFiles: [String] {
        if isAscending {
            return files.sorted()
        } else {
            return files.sorted(by: >)
        }
    }
    var monitoredFiles: [String] = []
    @State private var isAscending = false
    
    @State var selectedFile: String? = nil  // 選択されたファイル名を保存するための変数
    @State var selectedFileIndex: Int = 0
    var playingFile: String? = nil
    @State private var isPlaying = false
    @State var showingDeleteAlert = false
    @State var showingDeleteAllAlert = false
    @State private var isButtonVisible: Bool = false
    
    @ObservedObject var player = Player()

    @State private var favorites = [String: Bool]() {
        didSet {
            // false,つまりお気に入りでないkeyを削除する
            for (key, value) in favorites {
                if value == false {
                    favorites.removeValue(forKey: key)
                }
            }
            // favoritesが更新されたときにUserDefaultsに保存
            UserDefaults.standard.set(favorites, forKey: "favorites")
            // UserDefaultsの全データを取得してprintする
            //            for (key, value) in UserDefaults.standard.dictionaryRepresentation() {
            //                print("\(key) = \(value)")
            //            }
        }
    }
    
    
    @State var editingFileName: String = "" // 編集中のファイル名
    @State var isEditing = false
    

    init(path: String) {
        self.path = path
        // UserDefaultsからお気に入り情報を読み込む
        if let savedFavorites = UserDefaults.standard.dictionary(forKey: "favorites") as? [String: Bool] {
            self._favorites = State(initialValue: savedFavorites)
        }
    }

    var body: some View {
        NavigationView {
            VStack {
                VStack {
                    Button(action: {
                        self.isAscending.toggle()
                    }) {
                        HStack{
                            Spacer()
                            
                            Image(systemName: isAscending ? "arrow.down" : "arrow.up")
                                .resizable()
                                .frame(width: 20, height: 20)
                                .foregroundColor(.white)
                            Text(isAscending ? "昇順" : "降順")
                                .foregroundColor(.white)
                            
                            Spacer().frame(width: 20)
                        }
                    }
                    .background(Color(.systemGroupedBackground))
                    .contentShape(Rectangle())
                    
                    Spacer().frame(height: 20)
                    
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            self.showingDeleteAllAlert = true
                        }) {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(PlainButtonStyle())
                        .alert(isPresented: $showingDeleteAllAlert) {
                            Alert(title: Text("削除確認"),
                                  message: Text("お気に入り以外の全てのファイルを本当に削除しますか？"),
                                  primaryButton: .destructive(Text("削除")) {
                                    self.deleteNonFavoriteFiles(allfiles: self.sortedFiles) // 削除ボタンが押されたときのアクション
                                    self.showingDeleteAllAlert = false
                                  },
                                  secondaryButton: .cancel()
                            )
                        }
                        
                        Spacer().frame(width: 20)
                    }
                }
                
                List {
                    ForEach(Array(self.sortedFiles.enumerated()), id: \.element) { index, file in
                        VStack{
                            HStack {
                                if (self.isEditing == false)||(file != self.selectedFile) {
                                    Text(file)
                                    .lineLimit(5)
                                    .truncationMode(.tail)
                                    .onTapGesture {
                                        withAnimation {
                                            self.selectedFile = file
                                            self.filePath = "\(path)/\(file)"
                                            self.isButtonVisible.toggle()
                                            self.selectedFileIndex = index
                                        }
                                    }
                                    .onAppear {
                                        loadFiles()
                                    }
                                }
                                if (self.isEditing == true)&&(file == self.selectedFile) {
                                    // 編集モード
                                    TextField("ファイル名を入力", text: self.$editingFileName, onCommit: {
                                        // 編集を確定したら
                                        commitEdit(originalFileName: self.sortedFiles[self.selectedFileIndex]  ,newFileName: self.editingFileName)
                                        
                                        // 表示名、再生させるファイルパス名をそれぞれ更新する必要あり
                                        // comitEdit内の方が良いか？インデックスで直接ファイル名を変えにいく
                                        self.filePath = "\(path)/\(self.editingFileName)"
                                        //　表示名を変更するには、そもそものfile（sortedFiles[index]を書き換えにいく？）
                                        print("sortedFiles:\(self.sortedFiles)")
                                        print("selectedFiles:\(self.sortedFiles[self.selectedFileIndex])")

//                                        print("originalFileName:\(file)")
//                                        print("newFileName:\(self.editingFileName)")
                                    })
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .padding()
                                    .onAppear {
                                        // 編集開始時に現在のファイル名を編集用の変数にコピー
                                        self.editingFileName = file
                                    }
                                }
                                Spacer()
                                
//                                // 再生中を示すアイコン
//                                if (file == self.playingFile){
//                                    Image(systemName: "speaker.wave.2.circle")
//                                        .resizable()
//                                        .frame(width: 20, height: 20)
//                                        .foregroundColor(.blue)
//                                }
                                
                                Spacer()
                                // お気に入りボタン追加
                                Button(action: {
                                    self.favorites[file, default: false].toggle()
                                }) {
                                    Image(systemName: self.favorites[file, default: false] ? "star.fill" : "star")
                                        .foregroundColor(self.favorites[file, default: false] ? .yellow : .gray)
                                }
                                .buttonStyle(PlainButtonStyle())
                                Spacer().frame(width: 5)
                            }
                            if (file == selectedFile)&&(self.isButtonVisible == true){
                                // 選択されたファイル名と一致すれば再生ボタンを表示
                                HStack{
                                    Spacer()
                                    PlayButton(isPlaying: $isPlaying, historyView: self, player: self.player)
                                        .buttonStyle(PlainButtonStyle())
                                    Spacer()
                                    DeleteButton(historyView: self)
                                        .buttonStyle(PlainButtonStyle())
                                        .alert(isPresented: $showingDeleteAlert) {
                                            Alert(title: Text("削除確認"),
                                                  message: Text("本当に削除しますか？"),
                                                  primaryButton: .destructive(Text("削除")) {
                                                    delete(file: file) // 削除ボタンが押されたときのアクション
                                                    self.showingDeleteAlert = false
                                                  },
                                                  secondaryButton: .cancel()
                                            )
                                        }
                                    Spacer()
                                    FileNameEditButton(historyView: self)
                                        .buttonStyle(PlainButtonStyle())
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                .onAppear {
                    loadFiles()
                }
            }
            .navigationBarTitle("録音ファイル一覧", displayMode: .inline)
            .background(Color(.systemGroupedBackground))
        }
    }

    func loadFiles() {
        do {
            files = try fileManager.contentsOfDirectory(atPath: self.path)
        } catch {
            print("Error loading files: \(error)")
        }
    }

    func delete(file: String) {
        do {
            try fileManager.removeItem(atPath: "\(path)/\(file)")
            loadFiles()
            if selectedFile == file {
                selectedFile = nil
            }
            
        } catch {
            print("Error deleting file: \(error)")
        }
    }
    
    func startPlaying() {
        self.player.startPlaying(file: self.filePath!)
        
        print("startPlayaing    self.isPlaying = \(self.isPlaying)")
        print("self.filePath:\(self.filePath!)")
    }
    
    func stopPlaying() {
        self.player.stopPlaying()

        print("stopPlayaing     self.isPlaying = \(self.isPlaying)")
    }
    
    mutating func playingFileUpdate() {
        self.playingFile = self.selectedFile
    }
    
    func commitEdit(originalFileName: String, newFileName: String) {
        let fileManager = FileManager.default
        let originalFilePath = (self.path as NSString).appendingPathComponent(originalFileName)
        let newFilePath = (self.path as NSString).appendingPathComponent(newFileName)

        do {
            try fileManager.moveItem(atPath: originalFilePath, toPath: newFilePath)
        } catch {
            // ファイル名の変更に失敗した場合の処理
            print("ファイル名の変更に失敗しました: \(error)")
        }
        self.isEditing = false
    }
    
    func deleteNonFavoriteFiles(allfiles: [String]) {
        let fileManager = FileManager.default
        let allfiles:[String] = allfiles
        print("allfiles:\(allfiles)")
        
        // UserDefaultsからお気に入り情報を読み込む
        guard let savedFavorites = UserDefaults.standard.dictionary(forKey: "favorites") as? [String: Bool] else {
            return
        }
        print("savedFavorites:\(savedFavorites)")
        
        // ファイル一覧とお気に入りとの差分＝お気に入りでないファイルを抽出し、削除する
        // Setを使って差分を抽出
        let set1 = Set(allfiles)
        let set2 = Set(savedFavorites.keys)
        // array1からarray2を引いた差分を取得
        let difference = set1.subtracting(set2)
        // 差分のSetを配列に変換
        let differenceArray = Array(difference)
        // 結果を表示
        print("set1:\(set1)")
        print("set2:\(set2)")
        print("differenceArray:\(differenceArray)")
        
        // UserDefaultsを更新する
        // UserDefaultsからfavoritesを取得
        if var favorites = UserDefaults.standard.dictionary(forKey: "favorites") as? [String: Bool] {
            // 削除したいキーを指定して削除
            for key in differenceArray {
                favorites.removeValue(forKey: key)
                do {
                    try fileManager.removeItem(atPath: "\(path)/\(key)")
                    loadFiles()
                } catch {
                    print("Error deleting file: \(error)")
                }
                print("key:\(key)")
            }
            // 更新したfavoritesをUserDefaultsに保存
            UserDefaults.standard.set(favorites, forKey: "favorites")
            // UserDefaultsの同期を確実に行う
            UserDefaults.standard.synchronize()
        }
    }

}

class Player: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying: Bool = false
    var audioPlayer: AVAudioPlayer?
    
    func startPlaying(file: String) {
        let url = URL(fileURLWithPath: file)
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            self.audioPlayer?.delegate = self
            audioPlayer?.play()
            self.isPlaying = true
        } catch {
            print("Failed to play audio: \(error)")
        }
    }
    
    func stopPlaying() {
        audioPlayer?.stop()
        self.isPlaying = false
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // 再生終了時の処理
        self.isPlaying = false
    }
}


struct PlayButton: View {
    @Binding var isPlaying : Bool
    var historyView: HistoryView
    @ObservedObject var player: Player

    init(isPlaying: Binding<Bool>, historyView: HistoryView, player: Player) {
        self.historyView = historyView
        self.player = player
        self._isPlaying = isPlaying
    }

    var body: some View {
        Button(action: {
            if self.player.isPlaying == true{
                historyView.stopPlaying()
                self.isPlaying = false
            } else{
                historyView.startPlaying()
                self.isPlaying = true
//                self.historyView.playingFileUpdate()
            }
        }) {
            Image(systemName: self.player.isPlaying ? "stop.fill" : "play.fill")
                .resizable()
                .frame(width: 30, height: 30)
        }
    }
}

struct DeleteButton: View {
    var historyView: HistoryView

    init(historyView: HistoryView) {
        self.historyView = historyView
    }
    
    var body: some View {
        Button(action: {
            historyView.showingDeleteAlert = true
            print("削除")
        }) {
            Image(systemName: "trash")
                .resizable()
                .frame(width: 30, height: 30)
                .foregroundColor(.white)
        }
    }
}

struct FileNameEditButton:  View {
    var historyView: HistoryView
//    let file: String
    
    init(historyView: HistoryView) {
        self.historyView = historyView
    }
    
    var body: some View {
        Button(action: {
//            historyView.editingFileName = file // 編集対象のファイル名を設定
            historyView.isEditing = true
            print("名前変更")
        }) {
            Image(systemName: "square.and.pencil")
                .resizable()
                .frame(width: 30, height: 30)
        }
    }
}
