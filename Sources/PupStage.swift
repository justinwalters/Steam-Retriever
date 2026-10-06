import SwiftUI
import AppKit

// MARK: - the pup rig (painted parts, posed like a puppet)

enum Rig {
    static func leg(_ c: GraphicsContext, _ art: ArtStore, x: Double, y: Double, a1: Double, a2: Double, far: Bool, front: Bool) {
        var d = c
        d.translateBy(x: x, y: y)
        d.rotate(by: .degrees(-a1))
        d.scaleBy(x: 1, y: 1.12)
        art.draw(&d, (front ? "front_up" : "hind_up") + (far ? "_far" : ""))
        d.translateBy(x: 0, y: 11)
        d.rotate(by: .degrees(a2))
        art.draw(&d, (front ? "front_low" : "hind_low") + (far ? "_far" : ""))
        if front && !far {
            var w = d
            w.translateBy(x: 0, y: 7)
            w.scaleBy(x: 0.8, y: 0.8)
            art.draw(&w, "wrist")
        }
    }

    static func part(_ c: GraphicsContext, _ art: ArtStore, _ name: String, x: Double, y: Double,
                     rot: Double = 0, sx: Double = 1, sy: Double = 1) {
        var d = c
        d.translateBy(x: x, y: y)
        if rot != 0 { d.rotate(by: .degrees(rot)) }
        if sx != 1 || sy != 1 { d.scaleBy(x: sx, y: sy) }
        art.draw(&d, name)
    }

    /// Draw the pup standing on the ground at the origin, facing +x, 1 unit = 1 point.
    static func pup(_ ctx: GraphicsContext, _ art: ArtStore, _ p: Pose) {
        let ph = p.phase, g = p.gait, sit = p.sit, t = p.t
        let pf = p.pawFront, dg = p.dig
        func sw(_ o: Double, _ a: Double) -> Double { sin(ph + o) * a * g }
        func kn(_ o: Double, _ a: Double) -> Double { max(0, sin(ph + o + 1.3)) * a * g }
        let pi = Double.pi
        let fa = [sw(0, 44), sw(0.6, 44)]
        let ha = [sw(pi * 0.95, 40), sw(pi * 0.95 + 0.6, 40)]
        var fk = [-kn(0, 50), -kn(0.6, 50)]
        let hk = [kn(pi * 0.95, 55), kn(pi * 0.95 + 0.6, 55)]
        let bodyRot = -sit * 24 + p.bodyRot
        var frontA = fa.map { $0 * (1 - sit) + sit * bodyRot }
        if pf > 0 {
            frontA[0] = frontA[0] * (1 - pf) + (66 + sin(t * 13) * 16) * pf
            fk[0] = fk[0] * (1 - pf) - 35 * pf
        }
        if dg > 0 {
            let s = sin(t * 20)
            frontA = [-30 + s * 40, -30 - s * 40]
            fk = [40 + s * 20, 40 - s * 20]
        }
        let syv = abs(p.sy) < 0.03 ? (p.sy < 0 ? -0.03 : 0.03) : p.sy

        var c = ctx
        c.translateBy(x: 0, y: -p.lift + ((1 - p.sy) / 2) * 11)
        c.translateBy(x: -5, y: -40)
        c.rotate(by: .degrees(p.spin))
        c.translateBy(x: 5, y: 40)
        c.translateBy(x: 0, y: -34)
        c.scaleBy(x: 1, y: syv * p.squash)
        c.translateBy(x: 0, y: 34)
        c.translateBy(x: -30, y: 0)
        c.rotate(by: .degrees(bodyRot))
        c.translateBy(x: 30, y: 0)
        c.translateBy(x: 0, y: -3)

        if sit < 0.5 { leg(c, art, x: -26, y: -30, a1: ha[1], a2: hk[1], far: true, front: false) }
        leg(c, art, x: 16, y: -30, a1: frontA[1], a2: fk[1], far: true, front: true)
        part(c, art, "tail", x: -37, y: -40, rot: p.tail - 6, sx: 0.8, sy: 0.8)
        var body = c
        art.draw(&body, "body")
        if sit >= 0.5 {
            part(c, art, "haunch", x: -22, y: -18)
            part(c, art, "hpaw", x: -4, y: -3)
        } else {
            leg(c, art, x: -26, y: -30, a1: ha[0], a2: hk[0], far: false, front: false)
        }
        leg(c, art, x: 16, y: -30, a1: frontA[0], a2: fk[0], far: false, front: true)
        part(c, art, "pack", x: -16, y: -49, sx: 0.55, sy: 0.55)
        part(c, art, "collar", x: 19, y: -43)
        part(c, art, "badge", x: 21, y: -43, rot: sin(ph) * 8 * g + p.bodyRot * -0.5, sx: 0.55, sy: 0.55)
        part(c, art, "cap", x: 31, y: -35, rot: sin(ph + 1) * 10 * g, sx: 0.85, sy: 0.85)

        // head
        var h = c
        h.translateBy(x: 19, y: -43)
        h.rotate(by: .degrees(p.headRot))
        h.scaleBy(x: 0.8, y: 0.8)
        part(h, art, "ear_far", x: 34, y: -46, rot: p.ear + 8)
        do {
            var j = h
            j.translateBy(x: 26, y: -6)
            j.rotate(by: .degrees(p.mouth * 28))
            if p.tongue > 0 {
                var tg = j
                tg.translateBy(x: 19, y: -5)
                tg.rotate(by: .radians(0.1))
                tg.scaleBy(x: 1, y: p.tongue)
                art.draw(&tg, "tongue")
            }
            j.scaleBy(x: 0.6, y: 0.6)
            art.draw(&j, "jaw")
        }
        var head = h
        art.draw(&head, "head")
        if p.ballMouth { part(h, art, "ball", x: 48, y: -8 + p.mouth * 4, sx: 0.95, sy: 0.95) }
        if p.boneMouth {
            var b = h
            b.translateBy(x: 46, y: -6)
            b.rotate(by: .radians(-0.25))
            b.scaleBy(x: 1.1, y: 1.1)
            art.draw(&b, "bone")
        }

        func eye(_ x: Double, _ y: Double, _ rx: Double, _ ry: Double, _ dx: Double) {
            let ink = Color(hex: "1B100C")
            var d = h
            switch p.eyes {
            case 0, 3:
                let px = p.eyes == 3 ? dx : 0
                d.fill(Path(ellipseIn: CGRect(x: x - rx, y: y - ry, width: 2 * rx, height: 2 * ry)), with: .color(ink))
                let r1 = rx * 0.42
                d.fill(Path(ellipseIn: CGRect(x: x + rx * 0.35 + px * 0.3 - r1, y: y - ry * 0.38 - r1, width: 2 * r1, height: 2 * r1)), with: .color(.white))
                let r2 = rx * 0.2
                d.fill(Path(ellipseIn: CGRect(x: x - rx * 0.4 - r2, y: y + ry * 0.4 - r2, width: 2 * r2, height: 2 * r2)), with: .color(.white))
            case 1:
                var path = Path()
                path.move(to: CGPoint(x: x - rx, y: y + 1))
                path.addQuadCurve(to: CGPoint(x: x + rx, y: y + 1), control: CGPoint(x: x, y: y - ry * 0.9))
                d.stroke(path, with: .color(ink), style: StrokeStyle(lineWidth: 1.9, lineCap: .round))
            default:
                var path = Path()
                path.move(to: CGPoint(x: x - rx * 0.9, y: y - rx * 0.9))
                path.addLine(to: CGPoint(x: x + rx * 0.9, y: y + rx * 0.9))
                path.move(to: CGPoint(x: x + rx * 0.9, y: y - rx * 0.9))
                path.addLine(to: CGPoint(x: x - rx * 0.9, y: y + rx * 0.9))
                d.stroke(path, with: .color(ink), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
            }
        }
        eye(22, -27, 6, 7.4, 4)
        eye(38, -29, 4.6, 6.2, -2)
        part(h, art, "goggles", x: 16, y: -47, rot: -0.2 * 180 / pi)
        part(h, art, "ear", x: -1, y: -41, rot: p.ear + 6)
        if p.bflyNose {
            part(h, art, "bfly", x: 52, y: -30 + sin(t * 5) * 1.2,
                 sx: 0.8 * (0.6 + 0.4 * abs(sin(t * 14))), sy: 0.8)
        }
    }
}

// MARK: - the stage

enum StageScene {
    static func hash(_ i: Int) -> Double {
        var h = UInt32(truncatingIfNeeded: i &+ 1) &* 2654435761
        h ^= h >> 15
        h = h &* 2246822519
        h ^= h >> 13
        return Double(h) / 4294967296.0
    }

    static func place(_ x: Double, _ z: Double) -> (sx: Double, sy: Double, sc: Double) {
        (960 + x * 960, lerp(0.92 * 1080, 0.54 * 1080, z), lerp(4.0, 1.1, z))
    }

    private static func star(_ r1: Double, _ r2: Double, points: Int) -> Path {
        var path = Path()
        for j in 0..<(points * 2) {
            let r = j % 2 == 0 ? r1 : r2
            let a = Double(j) / Double(points * 2) * Double.pi * 2
            let pt = CGPoint(x: cos(a) * r, y: sin(a) * r)
            if j == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }

    private static func disc(_ x: Double, _ y: Double, _ rx: Double, _ ry: Double) -> Path {
        Path(ellipseIn: CGRect(x: x - rx, y: y - ry, width: 2 * rx, height: 2 * ry))
    }

    static func draw(_ ctx: GraphicsContext, size: CGSize, trick: Trick, t: Double, D: Double, art: ArtStore) {
        var base = ctx
        base.clip(to: Path(CGRect(origin: .zero, size: size)))
        let k = max(size.width / 1920, size.height / 1080)
        var c = base
        c.translateBy(x: (size.width - 1920 * k) / 2, y: size.height - 1080 * k)
        c.scaleBy(x: k, y: k)

        if let bd = art.backdrop {
            c.draw(c.resolve(bd), in: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        } else {
            c.fill(Path(CGRect(x: 0, y: 0, width: 1920, height: 1080)), with: .color(Color(hex: "0A0D13")))
        }

        let S = Choreo.state(trick, t, D)
        let (sx, sy, sc) = place(S.x, S.z)
        let p = S.pose, pr = S.props, face = S.face

        // dug hole
        if pr.hole > 0 {
            let hx = sx + face * 68 * sc, hy = sy + sc
            let hp = disc(hx, hy, 36 * sc * pr.hole, 10 * sc * pr.hole)
            c.fill(hp, with: .color(Color(hex: "05080A")))
            c.stroke(hp, with: .color(Color(hex: "46301A")), lineWidth: 2 * sc)
        }

        // shadow
        do {
            var s = c
            s.opacity = 0.4 * (1 - cl(p.lift * sc / (120 * sc), 0, 0.7))
            s.fill(disc(sx, sy + 2 * sc, 56 * sc, 9 * sc), with: .color(.black))
        }

        // steam from the boiler pipe, left hanging in the air where the pup was
        for i in 0..<7 {
            let age = (t * 0.8 + Double(i) / 7).truncatingRemainder(dividingBy: 1)
            let tp = max(0, t - age * 1.2)
            let s2 = Choreo.state(trick, tp, D)
            let q = place(s2.x, s2.z)
            let cx = q.sx + (-20.4 * s2.face) * q.sc + age * 10 * sc
            let cy = q.sy - 66 * q.sc - age * 70 * sc
            let r = (5 + age * 20) * sc
            let sh = GraphicsContext.Shading.radialGradient(
                Gradient(colors: [Color(red: 0.85, green: 0.9, blue: 0.94, opacity: 0.5 * (1 - age)),
                                  Color(red: 0.85, green: 0.9, blue: 0.94, opacity: 0)]),
                center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: r)
            c.fill(disc(cx, cy, r, r), with: sh)
        }

        // buried bone
        if let b = pr.bone {
            let hx = sx + face * 68 * sc
            let by = sy - (b.ground ? 0 : (b.k * 34 + sin(t * 3) * 2)) * sc
            if !b.ground && b.k > 0.3 {
                let sh = GraphicsContext.Shading.radialGradient(
                    Gradient(colors: [Color(red: 1, green: 0.9, blue: 0.6, opacity: 0.5), Color(red: 1, green: 0.9, blue: 0.6, opacity: 0)]),
                    center: CGPoint(x: hx, y: by), startRadius: 0, endRadius: 40 * sc)
                c.fill(disc(hx, by, 40 * sc, 40 * sc), with: sh)
            }
            var d = c
            d.translateBy(x: b.ground ? sx + face * 58 * sc : hx, y: by)
            d.rotate(by: .radians(-0.3 + (b.ground ? 0 : sin(t * 3) * 0.1)))
            let s = 1.5 * sc * (b.ground ? 1 : b.k)
            d.scaleBy(x: s, y: s)
            art.draw(&d, "bone")
        }

        // game pad
        if let wob = pr.pad {
            var d = c
            d.translateBy(x: sx + 62 * sc, y: sy - 4 * sc)
            d.rotate(by: .radians(wob * 0.04))
            d.scaleBy(x: 1.5 * sc, y: 1.5 * sc)
            art.draw(&d, "pad")
        }

        // the pup
        do {
            var d = c
            d.translateBy(x: sx, y: sy)
            d.scaleBy(x: sc * face, y: sc)
            Rig.pup(d, art, p)
        }

        // flying dirt
        if pr.digging {
            for kk in 0..<14 {
                let id = Int(floor(t / 0.05)) - kk
                let age = t - Double(id) * 0.05
                if age < 0 || age > 0.8 { continue }
                let r = hash(id), r2 = hash(id + 999)
                let sxp = sx + face * 62 * sc, syp = sy - 2 * sc
                let X = sxp + (-face) * (40 + r * 130) * age * sc
                let Y = syp - (160 + r2 * 120) * age * sc + 260 * age * age * sc
                var d = c
                d.opacity = 1 - age / 0.8
                d.fill(disc(X, Y, (2.6 + r * 3) * sc, (2.6 + r * 3) * sc), with: .color(Color(hex: r2 < 0.5 ? "4A3320" : "6B4A2C")))
            }
        }

        // brass ball
        if let b = pr.ball {
            let q = place(b.x, b.z)
            var s = c
            s.opacity = 0.35
            s.fill(disc(q.sx, q.sy + 2 * q.sc, 10 * q.sc, 3 * q.sc), with: .color(.black))
            var d = c
            d.translateBy(x: q.sx, y: q.sy - b.h * q.sc * 0.45 - 8 * q.sc)
            d.rotate(by: .radians(t * 6))
            d.scaleBy(x: 1.3 * q.sc, y: 1.3 * q.sc)
            art.draw(&d, "ball")
        }

        // "LEVEL UP!"
        if let tx = pr.text {
            var d = c
            d.opacity = min(1, tx.k * 6) * min(1, (1 - tx.k) * 5)
            let pt = CGPoint(x: sx + 40 * sc, y: sy - (125 + tx.k * 70) * sc)
            let font = Font.system(size: 17 * sc, weight: .heavy, design: .monospaced)
            for (ox, oy) in [(-2.0, 0.0), (2.0, 0.0), (0.0, -2.0), (0.0, 2.0), (-1.5, -1.5), (1.5, 1.5)] {
                d.draw(Text(tx.s).font(font).foregroundColor(Color(hex: "04210F")),
                       at: CGPoint(x: pt.x + ox * sc, y: pt.y + oy * sc), anchor: .center)
            }
            d.draw(Text(tx.s).font(font).foregroundColor(Color(hex: "6BFFA8")), at: pt, anchor: .center)
        }

        // hearts
        if let hs = pr.hearts {
            for i in 0..<3 {
                let kk = cl(hs * 1.3 - Double(i) * 0.15, 0, 1)
                if kk <= 0 || kk >= 1 { continue }
                let hx = sx + (20 + Double(i) * 22 + sin(kk * 6 + Double(i)) * 8) * sc
                let hy = sy - (100 + kk * 90) * sc
                var d = c
                d.opacity = 1 - kk
                d.translateBy(x: hx, y: hy)
                d.scaleBy(x: sc * (i % 2 == 0 ? 0.8 : 1.1), y: sc * 0.8)
                var heart = Path()
                heart.move(to: CGPoint(x: 0, y: 5))
                heart.addCurve(to: CGPoint(x: 0, y: -5), control1: CGPoint(x: -12, y: -4), control2: CGPoint(x: -6, y: -12))
                heart.addCurve(to: CGPoint(x: 0, y: 5), control1: CGPoint(x: 6, y: -12), control2: CGPoint(x: 12, y: -4))
                d.fill(heart, with: .color(Color(hex: "FF5C7A")))
            }
        }

        // dizzy stars
        if let st = pr.stars {
            for i in 0..<4 {
                let a = t * 6 + Double(i) * Double.pi / 2
                var d = c
                d.opacity = st
                d.translateBy(x: sx + (34 + cos(a) * 26) * sc, y: sy - (92 + sin(a) * 8) * sc)
                d.rotate(by: .radians(t * 5))
                d.scaleBy(x: sc, y: sc)
                d.fill(star(7, 3, points: 5), with: .color(Color(hex: "FFD34A")))
            }
        }

        // BANG!
        if let bk = pr.bang {
            let s2 = sc * (0.6 + 0.5 * sm(seg(bk, 0, 0.2))) * (1 - sm(seg(bk, 0.7, 1)))
            var d = c
            d.translateBy(x: sx + 70 * sc, y: sy - 110 * sc)
            d.scaleBy(x: s2, y: s2)
            let burst = star(44, 26, points: 8)
            d.fill(burst, with: .color(Color(hex: "FFD34A")))
            d.stroke(burst, with: .color(Color(hex: "8A3A10")), lineWidth: 3)
            d.draw(Text("BANG!").font(.system(size: 20, weight: .black, design: .monospaced)).foregroundColor(Color(hex: "B3261E")),
                   at: .zero, anchor: .center)
        }

        // clockwork butterfly
        if let b = pr.bfly {
            let q = place(b.x, b.z)
            var d = c
            d.translateBy(x: q.sx, y: q.sy - b.h * q.sc * 0.5)
            d.rotate(by: .radians(sin(t * 3) * 0.3))
            d.scaleBy(x: 1.7 * q.sc * (0.5 + 0.5 * abs(sin(t * 16))), y: 1.7 * q.sc)
            let glow = GraphicsContext.Shading.radialGradient(
                Gradient(colors: [Color(red: 0.47, green: 1, blue: 0.9, opacity: 0.35), Color(red: 0.47, green: 1, blue: 0.9, opacity: 0)]),
                center: .zero, startRadius: 0, endRadius: 26)
            d.fill(disc(0, 0, 26, 26), with: glow)
            art.draw(&d, "bfly")
        }
    }
}

// MARK: - picks a random trick, 10-15 seconds each

final class PupDirector: ObservableObject {
    struct Segment {
        let trick: Trick
        let start: Double
        let dur: Double
    }
    let origin = Date()
    private(set) var segments: [Segment] = []

    init() {
        var t = 0.0
        var last: Trick?
        var out: [Segment] = []
        while t < 1800 {
            var tr = Trick.allCases.randomElement() ?? .zoomies
            while tr == last { tr = Trick.allCases.randomElement() ?? .zoomies }
            let d = Double.random(in: 10...15)
            out.append(Segment(trick: tr, start: t, dur: d))
            t += d
            last = tr
        }
        segments = out
    }

    func current(at date: Date) -> (segment: Segment, t: Double) {
        let e = date.timeIntervalSince(origin)
        let s = segments.last(where: { $0.start <= e }) ?? segments[0]
        return (s, min(max(e - s.start, 0), s.dur))
    }
}

struct PupStage: View {
    @StateObject private var director = PupDirector()
    private let art = ArtStore.shared

    var body: some View {
        TimelineView(.animation) { tl in
            let cur = director.current(at: tl.date)
            ZStack(alignment: .bottom) {
                Canvas { ctx, size in
                    StageScene.draw(ctx, size: size, trick: cur.segment.trick, t: cur.t, D: cur.segment.dur, art: art)
                }
                Text(cur.segment.trick.caption)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.78))
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Capsule().fill(Color.black.opacity(0.45)))
                    .padding(.bottom, 12)
            }
        }
    }
}

// MARK: - the waiting panel that sits over the game list

struct SplashView: View {
    let game: String
    @EnvironmentObject var lib: Library

    var body: some View {
        ZStack(alignment: .top) {
            PupStage()
            TimelineView(.animation) { ctx in
                let secs = ctx.date.timeIntervalSinceReferenceDate
                let dots = String(repeating: ".", count: Int(secs * 2) % 4)
                VStack(spacing: 9) {
                    Text("Fetching your game to play" + dots)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 240, height: 5)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(Theme.accent)
                                .frame(width: 70, height: 5)
                                .offset(x: CGFloat((sin(secs * 2.2) + 1) / 2 * 170))
                        }
                        .clipShape(Capsule())
                    Text(lib.splashPhase)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.muted)
                        .frame(height: 16)
                    HStack(spacing: 10) {
                        Text(game)
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Capsule().fill(Color.white.opacity(0.1)))
                            .foregroundStyle(Color.white.opacity(0.9))
                        Button("Hide") { lib.splashGame = nil }
                            .buttonStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.muted)
                    }
                }
                .padding(.horizontal, 28).padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(hex: "0B1020").opacity(0.78))
                )
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                .shadow(color: .black.opacity(0.45), radius: 18, y: 6)
            }
            .padding(.top, 18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 24, y: 10)
        .padding(14)
    }
}
