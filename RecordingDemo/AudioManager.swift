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
    
    private var audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode?
    private var audioFile: AVAudioFile?
    
    // MARK: - Configure AudioSession and Start Recording (Bluetooth HFP)
    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        
        do {
            //帅俊请看 ： 加一个开关：
            
//            var mode = voiceChat|.default
            //降噪
            // Voice chat mode + Bluetooth CVC, suitable for low latency with simultaneous recording & playback
            try session.setCategory(.playAndRecord,
                                    mode: .voiceChat,
                                    options: [.allowBluetooth])
            
            //非降噪
//            try session.setCategory(.playAndRecord,
//                                    mode: .default,
//                                    options: [.allowBluetooth])
            
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

