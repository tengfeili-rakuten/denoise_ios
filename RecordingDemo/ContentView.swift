//
//  ContentView.swift
//  RecordingDemo
//
//  Created by Li, Tengfei on 2025/12/1.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var audioManager = AudioManager()
    
    var body: some View {
        VStack(spacing: 30) {
            Text("音频录音演示")
                .font(.title)
                .fontWeight(.bold)
            
            Text("AVAudioEngine + 实时音频处理")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            // Recording status indicator
            HStack {
                Circle()
                    .fill(audioManager.isRecording ? Color.red : Color.gray)
                    .frame(width: 20, height: 20)
                
                Text(audioManager.isRecording ? "录音中..." : "未录音")
                    .font(.headline)
            }
            .padding(.vertical, 10)
            
            // Real-time audio level visualizer
            if audioManager.isRecording {
                VStack(spacing: 10) {
                    Text("实时音量")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Audio level bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 20)
                            
                            // Level indicator
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.green, .yellow, .orange, .red]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * CGFloat(audioManager.audioLevel),
                                       height: 20)
                                .animation(.easeInOut(duration: 0.1), value: audioManager.audioLevel)
                        }
                    }
                    .frame(height: 20)
                    .padding(.horizontal, 40)
                    
                    // Numeric level display
                    Text(String(format: "%.0f%%", audioManager.audioLevel * 100))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 20)
                .transition(.opacity)
            }
            
            Spacer()
            
            // Start recording button
            Button {
                audioManager.startRecording()
            } label: {
                Text("开始录音")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 200, height: 60)
                    .background(audioManager.isRecording ? Color.gray : Color.blue)
                    .cornerRadius(12)
            }
            .disabled(audioManager.isRecording)
            
            // Stop recording button
            Button {
                audioManager.stopRecording()
            } label: {
                Text("停止录音")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 200, height: 60)
                    .background(audioManager.isRecording ? Color.red : Color.gray)
                    .cornerRadius(12)
            }
            .disabled(!audioManager.isRecording)
            
            Spacer()
            
            VStack(spacing: 8) {
                Text("✨ AVAudioEngine 特性")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Text("• 实时音频级别监测")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("• 支持音频缓冲区访问")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("• 可添加实时音效处理")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 10)
            
            Text("提示：先在其他 App 播放音乐，然后测试录音以查看后台音乐恢复效果")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
