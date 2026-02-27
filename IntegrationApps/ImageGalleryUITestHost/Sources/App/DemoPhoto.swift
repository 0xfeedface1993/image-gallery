import SwiftUI
import Core

struct DemoPhoto: Identifiable, ImageProvider {
    let id: String
    let url: URL
    let sourceSize: CGSize
    let color: Color
}

extension DemoPhoto {
    static let fixtures: [DemoPhoto] = [
        .init(
            id: "landscape",
            url: URL(string: "https://images.duanlndzi.bar/ecdb7c18e93fc76d336a787b7e357de5.jpg")!,
            sourceSize: CGSize(width: 180, height: 96),
            color: Color(red: 0.23, green: 0.65, blue: 0.97)
        ),
        .init(
            id: "portrait",
            url: URL(string: "https://images.duanlndzi.bar/1f004901f2efc537f58733b2253ecb9e.jpg")!,
            sourceSize: CGSize(width: 96, height: 180),
            color: Color(red: 0.34, green: 0.80, blue: 0.52)
        ),
        .init(
            id: "square",
            url: URL(string: "https://images.duanlndzi.bar/ecdb7c18e93fc76d336a787b7e357de5.jpg?variant=square")!,
            sourceSize: CGSize(width: 120, height: 120),
            color: Color(red: 0.96, green: 0.62, blue: 0.18)
        )
    ]
}
