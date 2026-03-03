/*
 * Live Chat View
 * Create or join WebRTC video chat rooms
 */

import SwiftUI
import CoreImage.CIFilterBuiltins

struct LiveChatView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var streamViewModel: StreamSessionViewModel
    @State private var mode: ChatMode = .menu
    @State private var roomCode: String = ""
    @State private var joinCode: String = ""

    enum ChatMode {
        case menu
        case newRoom
        case joinRoom
        case inCall
    }

    private var activeRoomCode: String {
        roomCode.isEmpty ? joinCode : roomCode
    }

    private func closeAndReturnToChatLog() {
        NotificationCenter.default.post(name: .liveChatClosedToLiveAI, object: nil)
        dismiss()
    }

    var body: some View {
        ZStack {
            if mode == .inCall {
                LiveChatWebView(
                    roomCode: activeRoomCode,
                    streamViewModel: streamViewModel,
                    onDismiss: {
                        Task {
                            await streamViewModel.stopSession()
                            await MainActor.run {
                                closeAndReturnToChatLog()
                            }
                        }
                    }
                )
                .ignoresSafeArea()
                .onAppear {
                    Task { await streamViewModel.handleStartStreaming() }
                }
            } else {
                NavigationView {
                    ZStack {
                        LinearGradient(
                            colors: [
                                AppColors.liveChat.opacity(0.1),
                                AppColors.secondary.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .ignoresSafeArea()

                        VStack(spacing: AppSpacing.xl) {
                            switch mode {
                            case .menu:
                                menuView
                            case .newRoom:
                                newRoomView
                            case .joinRoom:
                                joinRoomView
                            default:
                                EmptyView()
                            }
                        }
                        .padding(.horizontal, AppSpacing.lg)
                    }
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: {
                                if mode == .menu {
                                    closeAndReturnToChatLog()
                                } else {
                                    withAnimation { mode = .menu }
                                }
                            }) {
                                Image(systemName: mode == .menu ? "xmark" : "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(AppColors.textPrimary)
                            }
                        }

                        ToolbarItem(placement: .principal) {
                            Text("livechat.title".localized)
                                .font(AppTypography.headline)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Menu View

    private var menuView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            Image(systemName: "video.bubble.fill")
                .font(.system(size: 60))
                .foregroundColor(AppColors.liveChat)

            Text("livechat.title".localized)
                .font(AppTypography.title)
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Button(action: {
                roomCode = generateRoomCode()
                joinCode = ""
                withAnimation { mode = .newRoom }
            }) {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                    Text("livechat.new".localized)
                        .font(AppTypography.title2)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(
                    LinearGradient(
                        colors: [AppColors.liveChat, AppColors.liveChat.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(AppCornerRadius.lg)
                .shadow(color: AppColors.liveChat.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(ScaleButtonStyle())

            Button(action: {
                joinCode = ""
                roomCode = ""
                withAnimation { mode = .joinRoom }
            }) {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 24))
                    Text("livechat.join".localized)
                        .font(AppTypography.title2)
                }
                .foregroundColor(AppColors.liveChat)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(
                    AppColors.liveChat.opacity(0.12)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.lg)
                        .stroke(AppColors.liveChat.opacity(0.3), lineWidth: 1.5)
                )
                .cornerRadius(AppCornerRadius.lg)
            }
            .buttonStyle(ScaleButtonStyle())

            Spacer()
        }
    }

    // MARK: - New Room View

    private var newRoomView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            VStack(spacing: AppSpacing.md) {
                Text("livechat.roomcode".localized)
                    .font(AppTypography.callout)
                    .foregroundColor(AppColors.textSecondary)

                Text(roomCode)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(AppColors.liveChat)
                    .tracking(8)
            }

            if let qrImage = generateQRCode(from: webRTCURL(for: roomCode)) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .background(Color.white)
                    .cornerRadius(AppCornerRadius.md)
                    .shadow(color: AppShadow.medium(), radius: 10, x: 0, y: 5)
            }

            Text("livechat.scanning".localized)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            Button(action: { mode = .inCall }) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 20))
                    Text("livechat.start".localized)
                        .font(AppTypography.title2)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [AppColors.liveChat, AppColors.liveChat.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(AppCornerRadius.lg)
                .shadow(color: AppColors.liveChat.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.bottom, AppSpacing.xl)
        }
    }

    // MARK: - Join Room View

    private var joinRoomView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            Image(systemName: "person.2.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(AppColors.liveChat)

            Text("livechat.join".localized)
                .font(AppTypography.title)
                .foregroundColor(AppColors.textPrimary)

            TextField("livechat.entercode".localized, text: $joinCode)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .padding()
                .background(AppColors.secondaryBackground)
                .cornerRadius(AppCornerRadius.md)

            Spacer()

            Button(action: {
                guard !joinCode.isEmpty else { return }
                mode = .inCall
            }) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 20))
                    Text("livechat.start".localized)
                        .font(AppTypography.title2)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: joinCode.isEmpty
                            ? [Color.gray, Color.gray.opacity(0.8)]
                            : [AppColors.liveChat, AppColors.liveChat.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(AppCornerRadius.lg)
                .shadow(color: AppColors.liveChat.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .disabled(joinCode.isEmpty)
            .buttonStyle(ScaleButtonStyle())
            .padding(.bottom, AppSpacing.xl)
        }
    }

    // MARK: - Helpers

    private func generateRoomCode() -> String {
        String(format: "%04d", Int.random(in: 0...9999))
    }

    private func webRTCURL(for code: String) -> String {
        "https://app.ariaspark.com/webrtc/?a=\(code)&autostart=true"
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let data = string.data(using: .ascii)
        let filter = CIFilter(name: "CIQRCodeGenerator")
        filter?.setValue(data, forKey: "inputMessage")
        filter?.setValue("M", forKey: "inputCorrectionLevel")
        guard let ciImage = filter?.outputImage else { return nil }
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = ciImage.transformed(by: transform)
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
