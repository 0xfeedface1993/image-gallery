import SwiftUI

struct DefaultPanelView: View {
    let currentPage: Int
    let totalPages: Int
    let isVisible: Bool
    let onTapBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text("\(max(currentPage, 1)) / \(max(totalPages, 1))")
                    .foregroundColor(.white)
                    .bold()
                Spacer()
            }
            .frame(height: 44)
            .overlay(alignment: .leading) {
                Button(action: onTapBack) {
                    Image(systemName: "arrow.left")
                        .foregroundColor(.white)
                        .padding(.leading)
                        .frame(width: 44, height: 44)
                }
            }
            .background {
                Color.black.opacity(0.5).ignoresSafeArea(edges: .top)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
        .animation(.easeInOut(duration: 0.2), value: isVisible)
    }
}
