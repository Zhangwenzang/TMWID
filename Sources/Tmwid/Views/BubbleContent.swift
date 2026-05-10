import SwiftUI
import AppKit

/// NSVisualEffectView wrapper for behind-window blur.
/// Requires host NSWindow to have .titled styleMask (borderless doesn't support behind-window blending).
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        v.isEmphasized = true
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct BubbleContent: View {
    @ObservedObject var state: AppState
    var onMinimize: (() -> Void)?
    var onStatusTap: ((StatusKind) -> Void)?
    var onSessionTap: ((SessionState) -> Void)?
    var onHover: (() -> Void)?
    var onSizeChange: ((Bool) -> Void)?
    var activator: SessionActivator?
    @State private var isHovered = false
    @State private var isButtonHovered = false
    @State private var expandedStatus: StatusKind?

    var body: some View {
        bubbleBody
            .fixedSize(horizontal: true, vertical: true)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onChange(of: expandedStatus) { newValue in
                // Keep hover transitions structurally stable: resize the transparent
                // host window only after SwiftUI has produced the new intrinsic size,
                // with no intermediate frame animation that can clip the bubble.
                _ = newValue
                DispatchQueue.main.async { onSizeChange?(false) }
            }
    }

    private var bubbleBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section 1 — status icons, left-aligned, independent width
            HStack(spacing: 14) {
                if state.workingCount > 0 {
                    StatusItemView(kind: .working, count: state.workingCount, onTap: {
                        onStatusTap?(.working)
                    }, onHover: { hovering in
                        if hovering { expandedStatus = .working }
                    })
                }
                if state.askCount > 0 {
                    StatusItemView(kind: .ask, count: state.askCount, onTap: {
                        onStatusTap?(.ask)
                    }, onHover: { hovering in
                        if hovering { expandedStatus = .ask }
                    })
                }
                if state.doneCount > 0 {
                    StatusItemView(kind: .done, count: state.doneCount, onTap: {
                        onStatusTap?(.done)
                    }, onHover: { hovering in
                        if hovering { expandedStatus = .done }
                    })
                }
                if state.apiErrCount > 0 {
                    StatusItemView(kind: .apiErr, count: state.apiErrCount, onTap: {
                        onStatusTap?(.apiErr)
                    }, onHover: { hovering in
                        if hovering { expandedStatus = .apiErr }
                    })
                }
            }

            // Section 2 — session list, appears on hover, independent width (180pt)
            if let status = expandedStatus, let activator = activator {
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.top, 10)

                SessionListView(
                    sessions: state.sessions(for: status),
                    activator: activator,
                    onTap: { session in onSessionTap?(session) }
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            ZStack {
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                Color(red: 30/255, green: 30/255, blue: 40/255).opacity(0.45)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                .allowsHitTesting(false)
        )
        .overlay(alignment: .topTrailing) {
            Button(action: { onMinimize?() }) {
                Text("\u{2212}")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(isButtonHovered ? 0.25 : 0.15))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .onHover { hovering in isButtonHovered = hovering }
            .opacity(isHovered ? 1 : 0)
            .padding(.top, 2)
            .padding(.trailing, 2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onHover { hovering in
            isHovered = hovering
            if hovering { onHover?() }
            if !hovering { expandedStatus = nil }
        }
    }
}
