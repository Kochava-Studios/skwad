import SwiftUI
import AppKit

struct ContentView: View {
  @EnvironmentObject var agentManager: AgentManager
  @ObservedObject private var settings = AppSettings.shared
  @StateObject private var voiceManager = VoiceInputManager.shared
  @StateObject private var pushToTalk = PushToTalkMonitor.shared
  @State private var showGitPanel = false
  @State private var sidebarWidth: CGFloat = 250
  @State private var showVoiceOverlay = false
  @State private var escapeMonitor: Any?
  @State private var showNewAgentSheet = false
  
  private let minSidebarWidth: CGFloat = 200
  private let maxSidebarWidth: CGFloat = 400
  
  private var selectedAgent: Agent? {
    agentManager.agents.first { $0.id == agentManager.selectedAgentId }
  }
  
  private var canShowGitPanel: Bool {
    guard let agent = selectedAgent else { return false }
    return GitWorktreeManager.shared.isGitRepo(agent.folder)
  }
  
  var body: some View {
    HStack(spacing: 0) {
      if !agentManager.agents.isEmpty {
        SidebarView()
          .frame(width: sidebarWidth)
          .transition(.move(edge: .leading).combined(with: .opacity))
        
        // Resize handle
        Rectangle()
          .fill(Color.clear)
          .frame(width: 6)
          .contentShape(Rectangle())
          .onHover { hovering in
            if hovering {
              NSCursor.resizeLeftRight.push()
            } else {
              NSCursor.pop()
            }
          }
          .gesture(
            DragGesture()
              .onChanged { value in
                let newWidth = sidebarWidth + value.translation.width
                sidebarWidth = min(max(newWidth, minSidebarWidth), maxSidebarWidth)
              }
          )
      }
      
      ZStack {
        // Keep all terminals alive, show/hide based on selection
        // Use restartToken in id() to force terminal recreation on restart
        ForEach(agentManager.agents) { agent in
          AgentTerminalView(agent: agent) {
            if GitWorktreeManager.shared.isGitRepo(agent.folder) {
              withAnimation(.easeInOut(duration: 0.2)) {
                showGitPanel.toggle()
              }
            }
          }
            .id("\(agent.id)-\(agent.restartToken)")
            .opacity(agentManager.selectedAgentId == agent.id ? 1 : 0)
            .allowsHitTesting(agentManager.selectedAgentId == agent.id)
        }
        
        // Empty state
        if agentManager.agents.isEmpty {
          VStack(spacing: 16) {
            
            Image(nsImage: NSApplication.shared.applicationIconImage)
              .resizable()
              .frame(width: 128, height: 128)
              .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            
            VStack(spacing: 0) {
              Text("Welcome to Skwad!")
                .font(.system(size: 36, weight: .semibold))
                .foregroundColor(.primary)
              
              Text("Start assembling your skwad by creating your first agent")
                .font(.title)
                .foregroundColor(.secondary)
            }

            VStack(spacing: 12) {
              
              Button {
                showNewAgentSheet = true
              } label: {
                Label("Create New Agent", systemImage: "plus")
                  .font(.title2.weight(.semibold))
              }
              .buttonStyle(.borderedProminent)
              .padding(.vertical, 48)
              
              HStack(spacing: 8) {
                ForEach(settings.recentAgents.prefix(5)) { savedAgent in
                  Button {
                    agentManager.addAgent(folder: savedAgent.folder, name: savedAgent.name, avatar: savedAgent.avatar, agentType: savedAgent.agentType)
                  } label: {
                    HStack(spacing: 6) {
                      AvatarView(avatar: savedAgent.avatar, size: 20, font: .caption)
                      Text(savedAgent.name)
                        .font(.caption)
                        .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)
                  }
                  .buttonStyle(.plain)
                }
              }
              
            }

            VStack(spacing: 24) {

              Text("Install Skwad MCP Server to enable agent‑to‑agent communication")
                .font(.title2)
                .foregroundColor(.secondary)
              
              MCPCommandView(
                serverURL: settings.mcpServerURL,
                fontSize: .title3,
                backgroundColor: Color.black.opacity(0.08),
                iconSize: 20
              )
              .frame(maxWidth: 820)
            }
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(settings.effectiveBackgroundColor)
        }
        
        // Git toggle button
        if canShowGitPanel {
          VStack {
            Spacer()
            HStack {
              Spacer()
              gitToggleButton
                .padding(16)
            }
          }
        }
      }
      
      // Git panel (sliding from right)
      if showGitPanel, let agent = selectedAgent {
        GitPanelView(folder: agent.folder) {
          withAnimation(.easeInOut(duration: 0.2)) {
            showGitPanel = false
          }
        }
        .transition(.move(edge: .trailing))
      }
    }
    .background(settings.sidebarBackgroundColor)
    .frame(minWidth: 900, minHeight: 600)
    .ignoresSafeArea()
    .animation(.easeInOut(duration: 0.25), value: agentManager.agents.count)
    .overlay {
      // Voice input overlay
      if showVoiceOverlay {
        voiceOverlay
      }
    }
    .onChange(of: agentManager.selectedAgentId) { _, _ in
      // Close git panel when switching agents
      if showGitPanel {
        showGitPanel = false
      }
    }
    .onAppear {
      if settings.voiceEnabled {
        pushToTalk.start()
      }
    }
    .onChange(of: settings.voiceEnabled) { _, enabled in
      if enabled {
        pushToTalk.start()
      } else {
        pushToTalk.stop()
      }
    }
    .onChange(of: pushToTalk.isKeyDown) { _, isDown in
      handleVoiceKeyStateChange(isDown: isDown)
    }
    .onChange(of: showVoiceOverlay) { _, showing in
      if showing {
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
          if event.keyCode == 53 {  // Escape key
            DispatchQueue.main.async {
              self.dismissVoiceOverlay()
            }
            return nil  // Consume the event
          }
          return event
        }
      } else {
        if let monitor = escapeMonitor {
          NSEvent.removeMonitor(monitor)
          escapeMonitor = nil
        }
      }
    }
    .sheet(isPresented: $showNewAgentSheet) {
      AgentSheet()
        .environmentObject(agentManager)
    }
  }
  
  // MARK: - Voice Input
  
  @ViewBuilder
  private var voiceOverlay: some View {
    ZStack {
      Color.black.opacity(0.4)
        .ignoresSafeArea()
        .onTapGesture {
          dismissVoiceOverlay()
        }
      
      VStack(spacing: 20) {
        // Header with close button
        HStack(spacing: 16) {
          Image(systemName: voiceManager.isListening ? "mic.fill" : "mic")
            .font(.system(size: 32))
            .foregroundColor(voiceManager.isListening ? .red : .secondary)
            .symbolEffect(.pulse, isActive: voiceManager.isListening)
          
          VStack(alignment: .leading, spacing: 6) {
            Text(voiceManager.isListening ? "Listening..." : "Voice Input")
              .font(.title2.bold())
            
            if let error = voiceManager.error {
              Text(error)
                .font(.body)
                .foregroundColor(.red)
                .lineLimit(2)
            } else {
              Text("Release key to stop • Escape to cancel")
                .font(.body)
                .foregroundColor(.secondary)
            }
          }
          
          Spacer()
          
          Button {
            dismissVoiceOverlay()
          } label: {
            Image(systemName: "xmark.circle.fill")
              .font(.title)
              .foregroundColor(.secondary)
          }
          .buttonStyle(.plain)
          .keyboardShortcut(.escape, modifiers: [])
        }
        
        // Audio waveform visualization
        if voiceManager.isListening {
          AudioWaveformView(samples: voiceManager.waveformSamples)
            .frame(height: 32)
        }
        
        // Transcribed text
        if !voiceManager.transcribedText.isEmpty {
          VStack(alignment: .leading, spacing: 10) {
            Text("Transcription:")
              .font(.body)
              .foregroundColor(.secondary)
            
            Text(voiceManager.transcribedText)
              .font(.title3)
              .padding(14)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(Color.black.opacity(0.2))
              .cornerRadius(8)
          }
          
          // Action buttons (only if not auto-insert)
          if !settings.voiceAutoInsert && !voiceManager.isListening {
            HStack {
              Button("Cancel") {
                dismissVoiceOverlay()
              }
              .font(.body)
              
              Spacer()
              
              Button("Insert") {
                insertVoiceText()
              }
              .font(.body)
              .keyboardShortcut(.return, modifiers: [])
              .buttonStyle(.borderedProminent)
            }
          }
        }
      }
      .padding(24)
      .frame(width: 480)
      .background(settings.effectiveBackgroundColor)
      .cornerRadius(12)
      .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
    }
    .onKeyPress(.escape) {
      dismissVoiceOverlay()
      return .handled
    }
  }
  
  private func handleVoiceKeyStateChange(isDown: Bool) {
    guard settings.voiceEnabled else { return }
    
    if isDown {
      // Key pressed - start recording
      showVoiceOverlay = true
      Task {
        await voiceManager.startListening()
      }
    } else {
      // Key released - only inject if overlay wasn't cancelled
      guard showVoiceOverlay else { return }
      
      let finalText = voiceManager.transcribedText
      voiceManager.stopListening()
      
      // Always insert text if we have it
      if !finalText.isEmpty {
        voiceManager.injectText(finalText, into: agentManager, submit: settings.voiceAutoInsert)
      }
      dismissVoiceOverlay()
    }
  }
  
  private func insertVoiceText() {
    guard !voiceManager.transcribedText.isEmpty else { return }
    voiceManager.injectText(voiceManager.transcribedText, into: agentManager, submit: settings.voiceAutoInsert)
    dismissVoiceOverlay()
  }
  
  private func dismissVoiceOverlay() {
    voiceManager.stopListening()
    voiceManager.transcribedText = ""
    voiceManager.error = nil
    showVoiceOverlay = false
  }
  
  private var gitToggleButton: some View {
    Button {
      withAnimation(.easeInOut(duration: 0.2)) {
        showGitPanel.toggle()
      }
    } label: {
      Image(systemName: showGitPanel ? "xmark" : "arrow.triangle.branch")
        .font(.system(size: 14, weight: .medium))
        .foregroundColor(.white)
        .frame(width: 36, height: 36)
        .background(Color.accentColor)
        .clipShape(Circle())
        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
    }
    .buttonStyle(.plain)
    .help(showGitPanel ? "Close Git panel" : "Open Git panel")
  }
}

#Preview {
  ContentView()
    .environmentObject(AgentManager())
}

// MARK: - Audio Waveform Visualization (Dictation style)

struct AudioWaveformView: View {
  let samples: [Float]
  private let barCount = 64
  private let barWidth: CGFloat = 2
  private let spacing: CGFloat = 1.5
  
  var body: some View {
    TimelineView(.animation(minimumInterval: 1/60)) { _ in
      Canvas { context, size in
        let totalWidth = CGFloat(barCount) * (barWidth + spacing) - spacing
        let startX = (size.width - totalWidth) / 2
        let midY = size.height / 2
        let maxHeight = size.height * 0.9
        
        for i in 0..<barCount {
          // Map bar index to sample index
          let sampleIndex = samples.count > 0 ? i * samples.count / barCount : 0
          let sample = sampleIndex < samples.count ? samples[sampleIndex] : 0
          
          // Minimum bar height of 2 for visibility
          let height = max(2, CGFloat(sample) * maxHeight)
          
          let x = startX + CGFloat(i) * (barWidth + spacing)
          let rect = CGRect(
            x: x,
            y: midY - height / 2,
            width: barWidth,
            height: height
          )
          
          context.fill(
            Path(roundedRect: rect, cornerRadius: 1),
            with: .color(.white.opacity(0.85))
          )
        }
      }
    }
  }
}
