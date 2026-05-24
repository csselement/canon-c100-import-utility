import AVFoundation
import SwiftUI

struct PosterFrameView: View {
    let url: URL
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.quaternary)

            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "film")
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: url) {
            image = await PosterFrameGenerator.image(for: url)
        }
    }
}

enum PosterFrameGenerator {
    static func image(for url: URL) async -> NSImage? {
        await Task.detached(priority: .utility) {
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 640, height: 360)

            do {
                let cgImage = try generator.copyCGImage(at: CMTime(seconds: 0.5, preferredTimescale: 600), actualTime: nil)
                return NSImage(cgImage: cgImage, size: .zero)
            } catch {
                return nil
            }
        }.value
    }
}

