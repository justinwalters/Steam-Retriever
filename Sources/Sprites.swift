import AppKit
import SwiftUI

struct Sprite {
    let ox: Double, oy: Double, w: Double, h: Double
}

/// The pup's painted parts (PNGs in the app bundle) and where each one sits relative to its joint.
final class ArtStore {
    static let shared = ArtStore()

    let table: [String: Sprite] = [
        "front_up": Sprite(ox: -16, oy: -8, w: 32, h: 26),
        "front_up_far": Sprite(ox: -16, oy: -8, w: 32, h: 26),
        "hind_up": Sprite(ox: -16, oy: -8, w: 32, h: 26),
        "hind_up_far": Sprite(ox: -16, oy: -8, w: 32, h: 26),
        "front_low": Sprite(ox: -18, oy: -6, w: 36, h: 32),
        "front_low_far": Sprite(ox: -18, oy: -6, w: 36, h: 32),
        "hind_low": Sprite(ox: -18, oy: -6, w: 36, h: 32),
        "hind_low_far": Sprite(ox: -18, oy: -6, w: 36, h: 32),
        "body": Sprite(ox: -56, oy: -76, w: 108, h: 72),
        "haunch": Sprite(ox: -34, oy: -30, w: 68, h: 60),
        "hpaw": Sprite(ox: -24, oy: -12, w: 48, h: 24),
        "tail": Sprite(ox: -60, oy: -56, w: 76, h: 72),
        "head": Sprite(ox: -28, oy: -70, w: 104, h: 86),
        "ear": Sprite(ox: -34, oy: -8, w: 60, h: 68),
        "ear_far": Sprite(ox: -34, oy: -8, w: 60, h: 68),
        "jaw": Sprite(ox: -8, oy: -16, w: 64, h: 38),
        "tongue": Sprite(ox: -14, oy: -4, w: 28, h: 30),
        "goggles": Sprite(ox: -30, oy: -22, w: 70, h: 44),
        "collar": Sprite(ox: -16, oy: -8, w: 42, h: 34),
        "gear": Sprite(ox: -9, oy: -9, w: 18, h: 18),
        "pack": Sprite(ox: -30, oy: -34, w: 60, h: 52),
        "ball": Sprite(ox: -12, oy: -12, w: 24, h: 24),
        "bone": Sprite(ox: -18, oy: -9, w: 36, h: 18),
        "bfly": Sprite(ox: -14, oy: -12, w: 28, h: 24),
        "wrist": Sprite(ox: -11, oy: -9, w: 22, h: 18),
        "badge": Sprite(ox: -14, oy: -4, w: 30, h: 48),
        "cap": Sprite(ox: -8, oy: -8, w: 16, h: 16),
        "pad": Sprite(ox: -18, oy: -11, w: 36, h: 22),
    ]

    private var cache: [String: Image] = [:]
    private(set) var backdrop: Image?

    private init() {
        for name in table.keys {
            if let url = Bundle.main.url(forResource: name, withExtension: "png"), let ns = NSImage(contentsOf: url) {
                cache[name] = Image(nsImage: ns)
            }
        }
        if let url = Bundle.main.url(forResource: "backdrop", withExtension: "jpg"), let ns = NSImage(contentsOf: url) {
            backdrop = Image(nsImage: ns)
        }
    }

    func draw(_ c: inout GraphicsContext, _ name: String) {
        guard let s = table[name], let img = cache[name] else { return }
        c.draw(c.resolve(img), in: CGRect(x: s.ox, y: s.oy, width: s.w, height: s.h))
    }
}
