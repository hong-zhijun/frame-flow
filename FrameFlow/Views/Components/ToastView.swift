import SwiftUI

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.body)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
}

struct ToastModifier: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let current = message {
                ToastView(message: current)
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: current) {
                        try? await Task.sleep(nanoseconds: 2_500_000_000)
                        if !Task.isCancelled, message == current {
                            withAnimation { message = nil }
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: message)
            }
        }
    }
}

extension View {
    func toast(message: Binding<String?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}
