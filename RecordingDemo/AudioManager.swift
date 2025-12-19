//
//  AudioManager.swift
//  RecordingDemo
//
//  Created by tengfei Li on 2025-12-01.
//

import AVFoundation
import Combine

@MainActor
class AudioManager: ObservableObject {
    
    @Published var isRecording: Bool = false
    @Published var audioLevel: Float = 0.0 // Real-time audio level (0.0 - 1.0)
    @Published var denoiseEnabled: Bool = true // 降噪开关，默认开启
    @Published var recordingFileURL: URL? = nil // 当前录音文件 URL
    @Published var isUploading: Bool = false // 上传状态
    @Published var uploadProgress: Double = 0.0 // 上传进度
    @Published var uploadMessage: String = "" // 上传状态消息
    
    private var audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode?
    private var audioFile: AVAudioFile?
    
    // MARK: - Toggle Recording (Start/Stop)
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    // MARK: - Configure AudioSession and Start Recording (Bluetooth HFP)
    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        
        do {
            // 根据 denoiseEnabled 选择不同的音频会话模式
            if denoiseEnabled {
                // 降噪模式：Voice chat mode + Bluetooth CVC, suitable for low latency with simultaneous recording & playback
                try session.setCategory(.playAndRecord,
                                        mode: .voiceChat,
                                        options: [.allowBluetooth])
                print("🔇 录音模式：降噪 (voiceChat)")
            } else {
                // 普通模式：Default mode, no noise cancellation
                try session.setCategory(.playAndRecord,
                                        mode: .default,
                                        options: [.allowBluetooth])
                print("🎵 录音模式：普通 (default)")
            }
            
            try session.setActive(true)
            
            // Setup audio engine
            inputNode = audioEngine.inputNode
            guard let inputNode = inputNode else {
                print("❌ Failed to get input node")
                return
            }
            
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            // Create audio file for recording
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("record.caf")
            
            // Remove existing file if any
            try? FileManager.default.removeItem(at: url)
            
            audioFile = try AVAudioFile(forWriting: url,
                                        settings: recordingFormat.settings)
            
            // 保存录音文件 URL
            recordingFileURL = url
            
            // Install tap to access real-time audio buffer
            inputNode.installTap(onBus: 0,
                                bufferSize: 4096,
                                format: recordingFormat) { [weak self] buffer, time in
                guard let self = self else { return }
                
                // Write audio to file
                try? self.audioFile?.write(from: buffer)
                
                // Calculate real-time audio level
                Task { @MainActor in
                    self.calculateAudioLevel(from: buffer)
                }
            }
            
            // Start audio engine
            audioEngine.prepare()
            try audioEngine.start()
            
            isRecording = true
            
            print("🎤 AVAudioEngine recording started (Bluetooth entered HFP voice mode)")
            print("📁 Recording to: \(url.path)")
            
        } catch {
            print("❌ startRecording error:", error)
        }
    }
    
    // MARK: - Stop Recording and Restore Background Music
    func stopRecording() {
        // Remove tap and stop engine
        inputNode?.removeTap(onBus: 0)
        audioEngine.stop()
        
        // Close audio file
        audioFile = nil
        
        let session = AVAudioSession.sharedInstance()
        
        // Critical: Release audio focus + notify other apps to resume playback
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        
        isRecording = false
        audioLevel = 0.0
        
        print("🟢 AVAudioEngine recording stopped, background music restored")
    }
    
    // MARK: - Upload Configuration
    struct UploadConfig {
        var baseURL: String = "https://dev.companion.ai.public.rakuten-it.com"
//        var baseURL: String = "https://ai.rakuten.co.jp"
        var authToken: String = "at_WkxMQNd0DBws2pEtw2PZqDmTwnsb3306PNrp4dDK0LmwXuns6IO47K5mQIXpEgzC"
        var userId: String = "NxhYRzYcGiQ6ckRjcmV0SyAeBw-Gm5DlW-swC34sZeY"
        var deviceId: String = "03EAA6A9-511C-4702-8D68-C499FDD92D58"
    }
    
    var uploadConfig = UploadConfig()
    
    /// 生成上传文件路径
    /// 格式: speech-recognition-message/mobile_nr_eval/iOS/{requestId}_phone_{nr|raw}.wav
    private func generateUploadPath() -> (path: String, filename: String) {
        let requestId = UUID().uuidString
        let suffix = denoiseEnabled ? "nr" : "raw"
        let filename = "\(requestId)_phone_\(suffix).wav"
        let path = "speech-recognition-message/mobile_nr_eval/iOS/\(filename)"
        return (path, filename)
    }
    
    // MARK: - Upload Recording File
    func uploadRecording() {
        guard let fileURL = recordingFileURL else {
            uploadMessage = "❌ 没有可上传的录音文件"
            return
        }
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            uploadMessage = "❌ 录音文件不存在"
            return
        }
        
        isUploading = true
        uploadProgress = 0.0
        uploadMessage = "⏳ 正在上传..."
        
        Task {
            do {
                let result = try await performUpload(fileURL: fileURL)
                await MainActor.run {
                    self.uploadProgress = 1.0
                    self.uploadMessage = "✅ 上传成功，文件ID: \(result)"
                    self.isUploading = false
                }
            } catch {
                await MainActor.run {
                    self.uploadMessage = "❌ 上传失败: \(error.localizedDescription)"
                    self.isUploading = false
                }
            }
        }
    }
    
    // MARK: - Upload Response Model
    struct UploadResponse: Codable {
        let code: String  // 服务器返回的是字符串类型
        let message: String
        let data: UploadData?
        
        struct UploadData: Codable {
            let id: String
            let bytes: Int
            let originalFilename: String
        }
        
        /// 是否成功 (code == "0")
        var isSuccess: Bool {
            return code == "0"
        }
    }
    
    // MARK: - Perform Upload Request
    private func performUpload(fileURL: URL) async throws -> String {
        let urlString = "\(uploadConfig.baseURL)/api/v1/files/save"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // 设置请求头
        request.setValue("Bearer \(uploadConfig.authToken)", forHTTPHeaderField: "Authorization")
        request.setValue(uploadConfig.userId, forHTTPHeaderField: "X-Ninja-User-Id")
        request.setValue(uploadConfig.deviceId, forHTTPHeaderField: "Device-Id")
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // 读取文件数据
        let fileData = try Data(contentsOf: fileURL)
        
        // 生成上传路径和文件名
        let (uploadPath, uploadFilename) = generateUploadPath()
        
        // 构建 request JSON
        let requestJSON: [String: String] = [
            "path": uploadPath,
            "mimeType": "audio/wav"
        ]
        let requestJSONData = try JSONSerialization.data(withJSONObject: requestJSON)
        let requestJSONString = String(data: requestJSONData, encoding: .utf8) ?? ""
        
        // 构建 multipart form data
        var body = Data()
        
        // 添加 file 字段
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(uploadFilename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        
        // 添加 request 字段 (JSON 字符串)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"request\"\r\n\r\n".data(using: .utf8)!)
        body.append(requestJSONString.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // 结束边界
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // 打印请求信息用于调试
        print("📤 请求 URL: \(urlString)")
        print("📤 请求头:")
        request.allHTTPHeaderFields?.forEach { key, value in
            if key == "Authorization" {
                // 隐藏部分 token
                let maskedValue = String(value.prefix(20)) + "..." + String(value.suffix(10))
                print("   \(key): \(maskedValue)")
            } else {
                print("   \(key): \(value)")
            }
        }
        print("📤 上传路径: \(uploadPath)")
        print("📤 文件名: \(uploadFilename)")
        print("📤 文件大小: \(fileData.count) bytes")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        // 打印原始响应用于调试
        let responseString = String(data: data, encoding: .utf8) ?? "无法解码响应"
        print("📥 服务器响应 (\(httpResponse.statusCode)): \(responseString)")
        
        if httpResponse.statusCode == 200 {
            // 解析响应
            do {
                let decoder = JSONDecoder()
                let uploadResponse = try decoder.decode(UploadResponse.self, from: data)
                
                if uploadResponse.isSuccess, let fileData = uploadResponse.data {
                    return fileData.id
                } else {
                    throw NSError(domain: "UploadError", code: Int(uploadResponse.code) ?? -1,
                                 userInfo: [NSLocalizedDescriptionKey: uploadResponse.message])
                }
            } catch {
                print("❌ JSON 解析错误: \(error)")
                print("📄 原始响应: \(responseString)")
                throw error
            }
        } else {
            print("❌ HTTP 错误: \(httpResponse.statusCode)")
            throw URLError(.init(rawValue: httpResponse.statusCode))
        }
    }
    
    // MARK: - Calculate Real-time Audio Level
    private func calculateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let channelDataValue = channelData.pointee
        let channelDataValueArray = stride(from: 0,
                                           to: Int(buffer.frameLength),
                                           by: buffer.stride)
            .map { channelDataValue[$0] }
        
        // Calculate RMS (Root Mean Square) for audio level
        let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
        
        // Convert to 0.0 - 1.0 range
        let avgPower = 20 * log10(rms)
        let normalizedLevel = max(0.0, min(1.0, (avgPower + 60) / 60))
        
        audioLevel = normalizedLevel
    }
}
