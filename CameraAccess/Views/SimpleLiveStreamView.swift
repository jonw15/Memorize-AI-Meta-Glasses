/*
 * Simple Live Stream View
 * Simplified live stream view - for platforms like TikTok/Kuaishou
 */

import SwiftUI

struct SimpleLiveStreamView: View {
    @ObservedObject var streamViewModel: StreamSessionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showUI = true // Controls UI show/hide

    var body: some View {
        ZStack {
            // Black background
            Color.black
                .edgesIgnoringSafeArea(.all)

            // Video feed
            if let videoFrame = streamViewModel.currentVideoFrame {
                GeometryReader { geometry in
                    Image(uiImage: videoFrame)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
                .edgesIgnoringSafeArea(.all)
            } else {
                VStack(spacing: AppSpacing.lg) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .foregroundColor(.white)
                    Text("Connecting to video stream...")
                        .font(AppTypography.body)
                        .foregroundColor(.white)
                }
            }

            // UI elements - tap screen to hide
            if showUI {
                VStack {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding()
                        }

                        Spacer()

                        // Status indicator
                        HStack(spacing: AppSpacing.sm) {
                            Circle()
                                .fill(streamViewModel.isStreaming ? Color.red : Color.gray)
                                .frame(width: 8, height: 8)
                            Text(streamViewModel.isStreaming ? "Live" : "Not Connected")
                                .font(AppTypography.caption)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.xs)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(AppCornerRadius.lg)
                        .padding(AppSpacing.md)
                    }

                    Spacer()

                    // Instructions
                    VStack(spacing: AppSpacing.md) {
                        Text("Live Stream Tips")
                            .font(AppTypography.headline)
                            .foregroundColor(.white)

                        Text("1. Open a live streaming platform (e.g. TikTok)")
                            .font(AppTypography.caption)
                            .foregroundColor(.white.opacity(0.8))

                        Text("2. Select the screen recording feature")
                            .font(AppTypography.caption)
                            .foregroundColor(.white.opacity(0.8))

                        Text("3. Start recording this screen to go live")
                            .font(AppTypography.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(AppSpacing.lg)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(AppCornerRadius.lg)
                    .padding(.bottom, AppSpacing.xl)
                }
                .transition(.opacity)
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                showUI.toggle()
            }
        }
        .onAppear {
            // Start video stream
            Task {
                print("🎥 SimpleLiveStreamView: Starting video stream")
                await streamViewModel.handleStartStreaming()
            }
        }
        .onDisappear {
            // Stop video stream
            Task {
                print("🎥 SimpleLiveStreamView: Stopping video stream")
                if streamViewModel.streamingStatus != .stopped {
                    await streamViewModel.stopSession()
                }
            }
        }
    }
}
