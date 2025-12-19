//
//  ContentView.swift
//  RecordingDemo
//
//  Created by Li, Tengfei on 2025/12/1.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var audioManager = AudioManager()
    @State private var showUploadAlert = false
    
    var body: some View {
        VStack(spacing: 24) {
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
                    .overlay(
                        audioManager.isRecording ?
                        Circle()
                            .stroke(Color.red.opacity(0.4), lineWidth: 4)
                            .scaleEffect(1.5)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: audioManager.isRecording)
                        : nil
                    )
                
                Text(audioManager.isRecording ? "录音中..." : "未录音")
                    .font(.headline)
            }
            .padding(.vertical, 10)
            
            // 降噪开关
            HStack {
                Image(systemName: audioManager.denoiseEnabled ? "waveform.badge.minus" : "waveform")
                    .font(.title2)
                    .foregroundColor(audioManager.denoiseEnabled ? .blue : .gray)
                
                Toggle("降噪模式", isOn: $audioManager.denoiseEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
            )
            .padding(.horizontal, 20)
            .disabled(audioManager.isRecording) // 录音中不能切换模式
            .opacity(audioManager.isRecording ? 0.6 : 1.0)
            
            // 当前模式提示
            Text(audioManager.denoiseEnabled ? "使用 voiceChat 模式进行降噪" : "使用 default 模式，无降噪")
                .font(.caption)
                .foregroundColor(.secondary)
            
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
                .padding(.vertical, 16)
                .transition(.opacity)
            }
            
            Spacer()
            
            // 合并的开始/停止录音按钮
            Button {
                withAnimation(.spring(response: 0.3)) {
                    audioManager.toggleRecording()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: audioManager.isRecording ? "stop.fill" : "mic.fill")
                        .font(.title2)
                    
                    Text(audioManager.isRecording ? "停止录音" : "开始录音")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(width: 200, height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(audioManager.isRecording ? Color.red : Color.blue)
                )
                .shadow(color: (audioManager.isRecording ? Color.red : Color.blue).opacity(0.4),
                        radius: 8, x: 0, y: 4)
            }
            
            // 上传按钮
            Button {
                showUploadAlert = true
            } label: {
                HStack(spacing: 12) {
                    if audioManager.isUploading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "icloud.and.arrow.up.fill")
                            .font(.title2)
                    }
                    
                    Text(audioManager.isUploading ? "上传中..." : "上传录音")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(width: 200, height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(canUpload ? Color.green : Color.gray)
                )
                .shadow(color: canUpload ? Color.green.opacity(0.4) : Color.clear,
                        radius: 8, x: 0, y: 4)
            }
            .disabled(!canUpload)
            .alert("上传录音", isPresented: $showUploadAlert) {
                Button("取消", role: .cancel) { }
                Button("确认上传") {
                    audioManager.uploadRecording()
                }
            } message: {
                Text("确定要将录音文件上传到服务器吗？")
            }
            
            // 上传状态消息
            if !audioManager.uploadMessage.isEmpty {
                Text(audioManager.uploadMessage)
                    .font(.caption)
                    .foregroundColor(audioManager.uploadMessage.contains("✅") ? .green :
                                    audioManager.uploadMessage.contains("❌") ? .red : .secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
            
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
        .animation(.easeInOut, value: audioManager.uploadMessage)
    }
    
    // 是否可以上传
    private var canUpload: Bool {
        !audioManager.isRecording &&
        !audioManager.isUploading &&
        audioManager.recordingFileURL != nil
    }
}

#Preview {
    ContentView()
}
