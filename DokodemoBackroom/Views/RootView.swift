import SwiftUI

struct RootView: View {
    @StateObject private var controller = PortalARController()
    @StateObject private var capture = CaptureController()

    var body: some View {
        ZStack {
            ARPortalView(controller: controller)
                .ignoresSafeArea()

            VStack {
                topBar
                if !controller.debugText.isEmpty {
                    Text(controller.debugText)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 6))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer()
                if capture.isRecording {
                    recordingBar
                } else {
                    controls
                }
            }
            .padding()

            if let toast = capture.toast {
                Text(toast)
                    .font(.callout).bold()
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
        .animation(.easeInOut, value: capture.isRecording)
        .animation(.easeInOut, value: capture.toast)
    }

    private var topBar: some View {
        HStack(alignment: .top) {
            if !controller.statusText.isEmpty {
                Text(controller.statusText)
                    .font(.subheadline)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            Spacer()
            Text(controller.isLiDAR ? "LiDAR" : "矩形")
                .font(.caption).bold()
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
        }
    }

    private var controls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "slider.horizontal.3")
                Text("感度")
                Slider(value: $controller.sensitivity, in: 0...1)
            }
            .font(.footnote)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))

            HStack(spacing: 32) {
                Button {
                    controller.clearPortal()
                } label: {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.system(size: 42))
                        .symbolRenderingMode(.hierarchical)
                }
                .disabled(!controller.hasPortal)
                .opacity(controller.hasPortal ? 1 : 0.35)

                Button {
                    capture.takePhoto(controller.arView)
                } label: {
                    ZStack {
                        Circle().fill(.white).frame(width: 68, height: 68)
                        Circle().stroke(.white, lineWidth: 4).frame(width: 82, height: 82)
                    }
                }

                Button {
                    capture.toggleRecording()
                } label: {
                    Image(systemName: "record.circle.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(.red, .white)
                }
            }
        }
    }

    private var recordingBar: some View {
        Button {
            capture.toggleRecording()
        } label: {
            Label("録画を停止", systemImage: "stop.circle.fill")
                .font(.title3).bold()
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(.red, in: Capsule())
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    RootView()
}
