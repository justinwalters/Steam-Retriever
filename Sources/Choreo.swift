import Foundation

// Choreography for Sprocket, the retriever pup. Pure math: state(trick, t, D) says where the pup is,
// which way it faces, how its body is posed and which props are on stage at time t of a D-second trick.

@inline(__always) func cl(_ x: Double, _ a: Double, _ b: Double) -> Double { min(max(x, a), b) }
func sm(_ x: Double) -> Double { let c = cl(x, 0, 1); return c * c * (3 - 2 * c) }
func seg(_ u: Double, _ a: Double, _ b: Double) -> Double { cl((u - a) / (b - a), 0, 1) }
func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
private func jump(_ u: Double, _ a: Double, _ b: Double, _ h: Double) -> Double {
    let k = seg(u, a, b)
    return (k > 0 && k < 1) ? sin(Double.pi * k) * h : 0
}

enum Trick: String, CaseIterable {
    case fetch, zoomies, gamer, roll, dig, spin, dead, flip, fly

    var caption: String {
        switch self {
        case .fetch: return "Sprocket is fetching the brass ball"
        case .zoomies: return "Sprocket has the zoomies"
        case .gamer: return "Sprocket is speedrunning a level"
        case .roll: return "Sprocket is rolling over"
        case .dig: return "Sprocket is digging for treasure"
        case .spin: return "Sprocket is chasing his tail"
        case .dead: return "Sprocket is playing dead"
        case .flip: return "Sprocket is practising backflips"
        case .fly: return "Sprocket spotted a clockwork butterfly"
        }
    }
}

struct Pose {
    var phase = 0.0, gait = 0.0, sit = 0.0, lift = 0.0, bodyRot = 0.0
    var tail = 0.0, ear = 0.0, headRot = 0.0, mouth = 0.0, tongue = 0.0
    var eyes = 0              // 0 open, 1 happy, 2 X, 3 cross-eyed
    var pawFront = 0.0, dig = 0.0
    var sy = 1.0, squash = 1.0, spin = 0.0
    var ballMouth = false, boneMouth = false, bflyNose = false
    var t = 0.0
}

struct Props {
    var ball: (x: Double, z: Double, h: Double)?
    var hole = 0.0
    var digging = false
    var bone: (k: Double, ground: Bool)?
    var pad: Double?
    var text: (s: String, k: Double)?
    var hearts: Double?
    var stars: Double?
    var bang: Double?
    var bfly: (x: Double, z: Double, h: Double)?
}

struct PupState {
    var x = 0.0, z = 0.14, face = 1.0
    var pose = Pose()
    var props = Props()
}

enum Choreo {
    static let z0 = 0.14

    static func spinTheta(_ u: Double) -> Double { 2 * Double.pi * 4 * sm(seg(u, 0.08, 0.62)) }

    static func path(_ n: Trick, _ t: Double, _ D: Double) -> (Double, Double) {
        let u = t / D
        switch n {
        case .fetch:
            if u < 0.12 { return (0, z0) }
            if u < 0.40 { let k = sm(seg(u, 0.12, 0.40)); return (lerp(0, 0.6, k), lerp(z0, 0.7, k)) }
            if u < 0.48 { return (0.6, 0.7) }
            if u < 0.80 { let k = sm(seg(u, 0.48, 0.80)); return (lerp(0.6, -0.02, k), lerp(0.7, z0, k)) }
            return (-0.02, z0)
        case .zoomies:
            let env = sm(seg(u, 0, 0.08)) * sm(seg(1 - u, 0, 0.08))
            let x = 1.38 * env * sin(4 * Double.pi * u)
            let z = z0 + env * 0.4 * (1 - cos(8 * Double.pi * u)) * 0.5
            return (x, min(z, 0.8))
        case .dig:
            if u < 0.14 { let k = sm(seg(u, 0, 0.14)); return (lerp(0, -0.42, k), lerp(z0, 0.3, k)) }
            if u < 0.86 { return (-0.42, 0.3) }
            let k = sm(seg(u, 0.86, 1)); return (lerp(-0.42, 0, k), lerp(0.3, z0, k))
        case .spin:
            let th = spinTheta(u)
            return (0.04 * sin(th), 0.16 + 0.03 * cos(th))
        case .fly:
            if u < 0.52 { return (0, z0) }
            if u < 0.66 { let k = sm(seg(u, 0.52, 0.66)); return (lerp(0, 0.62, k), lerp(z0, 0.8, k)) }
            if u < 0.86 { return (0.62, 0.8) }
            let k = sm(seg(u, 0.86, 0.98)); return (lerp(0.62, 0, k), lerp(0.8, z0, k))
        default:
            return (0, z0)
        }
    }

    static func face(_ n: Trick, _ t: Double, _ D: Double, _ vx: Double) -> Double {
        let u = t / D
        switch n {
        case .fetch:
            if u < 0.44 { return 1 }
            if u < 0.5 { return lerp(1, -1, sm(seg(u, 0.44, 0.5))) }
            if u < 0.80 { return -1 }
            return lerp(-1, 1, sm(seg(u, 0.80, 0.86)))
        case .zoomies:
            if u < 0.03 { return 1 }
            let f = cl(vx / 0.25, -1, 1)
            if abs(f) < 0.25 { return f < 0 ? -0.25 : 0.25 }
            return f
        case .dig:
            if u < 0.02 { return lerp(1, -1, sm(seg(u, 0, 0.02))) }
            if u < 0.88 { return -1 }
            return lerp(-1, 1, sm(seg(u, 0.88, 0.92)))
        case .spin:
            let c = cos(spinTheta(u))
            if abs(c) < 0.16 { return c < 0 ? -0.16 : 0.16 }
            return c
        case .fly:
            if u < 0.72 { return 1 }
            if u < 0.86 { return lerp(1, -1, sm(seg(u, 0.72, 0.78))) }
            if u < 0.96 { return -1 }
            return lerp(-1, 1, sm(seg(u, 0.96, 1)))
        default:
            return 1
        }
    }

    static func speed(_ n: Trick, _ t: Double, _ D: Double) -> Double {
        let a = path(n, max(0, t - 0.05), D), b = path(n, min(D, t + 0.05), D)
        return hypot(b.0 - a.0, (b.1 - a.1) * 0.5) / 0.1
    }

    static func phase(_ n: Trick, _ t: Double, _ D: Double) -> Double {
        var ph = 0.0
        var s = 0.0
        while s < t {
            let sp = speed(n, s, D)
            if sp > 0.05 { ph += 0.1 * cl(8 + sp * 9, 8, 19) }
            s += 0.1
        }
        return ph
    }

    static func state(_ n: Trick, _ t: Double, _ D: Double) -> PupState {
        let u = t / D
        let (x, z) = path(n, t, D)
        let sp = speed(n, t, D)
        let vx = (path(n, min(D, t + 0.05), D).0 - path(n, max(0, t - 0.05), D).0) / 0.1
        let fc = face(n, t, D, vx)
        let g = cl(sp / 0.18, 0, 1)
        var p = Pose()
        p.phase = phase(n, t, D)
        p.gait = g
        p.t = t
        p.tail = sin(t * 9) * 10
        p.ear = sin(t * 3) * 3
        if g > 0.05 {
            p.lift = abs(sin(p.phase)) * 3.5 * g
            p.tongue = 1; p.mouth = 0.5
            p.tail = sin(t * 16) * 14 + 8
            p.ear = -18 * g + sin(p.phase * 2) * 6
            p.bodyRot = sin(p.phase * 2) * 2
        }
        var pr = Props()

        switch n {
        case .fetch:
            let k = seg(u, 0.05, 0.2)
            if u >= 0.05 && u < 0.42 {
                let bx = lerp(0.05, 0.6, k), bz = lerp(z0, 0.7, k)
                var h = sin(Double.pi * k) * 260 * (k < 1 ? 1 : 0)
                if u >= 0.2 && u < 0.24 { h += sin(Double.pi * seg(u, 0.2, 0.24)) * 40 }
                pr.ball = (bx, bz, h)
            }
            p.headRot = (u > 0.38 && u < 0.5) ? 24 * sin(Double.pi * seg(u, 0.38, 0.5)) : 0
            p.ballMouth = u >= 0.46 && u < 0.82
            if p.ballMouth { p.tongue = 0; p.mouth = 0 }
            p.sit = sm(seg(u, 0.84, 0.9))
            if u >= 0.82 {
                pr.ball = (-0.02 + 0.13, z0, abs(sin(seg(u, 0.82, 0.88) * Double.pi * 2)) * 30 * (1 - seg(u, 0.82, 0.9)))
                p.tongue = 1; p.mouth = 0.5; p.eyes = 1
                p.tail = sin(t * 16) * 18
            }

        case .zoomies:
            p.tail = sin(t * 20) * 22

        case .gamer:
            p.sit = sm(seg(u, 0.06, 0.16)) * sm(seg(1 - u, 0, 0.1))
            if u > 0.18 && u < 0.94 { pr.pad = sin(t * 14) }
            let play = sm(seg(u, 0.2, 0.26)) * (1 - sm(seg(u, 0.68, 0.74)))
            p.pawFront = play * (0.5 + 0.5 * sin(t * 9))
            p.headRot = 8 * play
            p.tongue = play
            p.mouth = 0.3 * play
            p.eyes = u > 0.78 ? 1 : 0
            if u > 0.46 && u < 0.64 { pr.text = ("LEVEL UP!", seg(u, 0.46, 0.64)) }
            if u > 0.74 && u < 0.9 { pr.hearts = seg(u, 0.74, 0.9) }

        case .roll:
            let th = 2 * Double.pi * 2 * sm(seg(u, 0.2, 0.72))
            let rolling = u > 0.2 && u < 0.72
            p.sy = rolling ? cos(th) : 1
            p.squash = 1 - 0.12 * sm(seg(u, 0.06, 0.18)) * (1 - sm(seg(u, 0.72, 0.8)))
            p.headRot = 10 * sm(seg(u, 0.06, 0.18)) * (1 - sm(seg(u, 0.2, 0.24)))
            if rolling {
                let back = cl(-p.sy + 0.35, 0, 1)
                p.gait = 0.8 * back
                p.phase = t * 13
                p.eyes = back > 0.3 ? 1 : 0
                p.tongue = 1; p.mouth = 0.5
                p.bodyRot = sin(th) * 6
                p.lift = 0
            }
            if u > 0.8 && u < 0.92 {
                let e = sm(seg(u, 0.8, 0.83)) * (1 - sm(seg(u, 0.86, 0.92)))
                p.bodyRot = sin(t * 34) * 7 * e
                p.ear = sin(t * 30) * 25 * e
            }
            if u > 0.72 { p.eyes = 1; p.tongue = 1; p.mouth = 0.4 }

        case .dig:
            let digK = sm(seg(u, 0.16, 0.2)) * (1 - sm(seg(u, 0.56, 0.62)))
            p.dig = digK > 0.5 ? 1 : 0
            p.headRot = 28 * digK + ((u > 0.62 && u < 0.7) ? -12 * sm(seg(u, 0.62, 0.66)) : 0)
            if g < 0.1 { p.tail = sin(t * 14) * 16 }
            pr.digging = digK > 0.5
            pr.hole = sm(seg(u, 0.16, 0.5)) * (1 - sm(seg(u, 0.9, 0.97)))
            if u > 0.54 && u < 0.97 { pr.bone = (sm(seg(u, 0.54, 0.7)), false) }
            p.boneMouth = u >= 0.72 && u < 0.93
            if p.boneMouth { p.tongue = 0; p.mouth = 0 }
            if u > 0.62 {
                p.eyes = 1
                p.lift += jump(u, 0.64, 0.7, 14) + jump(u, 0.7, 0.76, 10)
            }
            if u >= 0.93 && u < 0.99 { pr.bone = (1, true) }

        case .spin:
            let th = spinTheta(u)
            p.tail = sin(t * 22) * 34
            p.mouth = 0.4; p.tongue = 1
            p.headRot = 14 * sin(th)
            p.bodyRot = sin(th) * 5
            let dz = sm(seg(u, 0.62, 0.7)) * (1 - sm(seg(u, 0.9, 0.97)))
            if dz > 0 {
                p.bodyRot = sin(t * 7) * 14 * dz
                p.eyes = 3
                p.headRot = sin(t * 5) * 12 * dz
                pr.stars = dz
            }
            if u > 0.95 { p.eyes = 1 }

        case .dead:
            if u >= 0.1 && u < 0.3 { pr.bang = seg(u, 0.1, 0.3) }
            let fall = sm(seg(u, 0.2, 0.3)), wake = sm(seg(u, 0.72, 0.78))
            p.sy = cos(Double.pi * cl(fall - wake, 0, 1))
            let down = fall * (1 - wake)
            p.lift = ((u > 0.3 && u < 0.34) ? sin(seg(u, 0.3, 0.34) * Double.pi) * 8 : 0) + jump(u, 0.78, 0.9, 34)
            if down > 0.5 { p.eyes = (u > 0.6 && u < 0.66) ? 0 : 2 } else { p.eyes = u > 0.78 ? 1 : 0 }
            if down > 0.4 { p.tongue = 1; p.tail = 0 }
            p.mouth = down * 0.5
            p.gait = 0
            p.ear = down * 30
            if down > 0.9 {
                p.gait = (u > 0.48 && u < 0.54) ? 0.6 : 0
                p.phase = t * 16
            }
            if u > 0.78 { p.eyes = 1 }

        case .flip:
            let c1 = sm(seg(u, 0.06, 0.14)) * (1 - sm(seg(u, 0.14, 0.16)))
            let k1 = seg(u, 0.14, 0.32), k2 = seg(u, 0.46, 0.68)
            var spinA = 0.0, liftA = 0.0
            if k1 > 0 && k1 < 1 { spinA = -360 * sm(k1); liftA = sin(Double.pi * k1) * 70 }
            if k2 > 0 && k2 < 1 { spinA = -360 * sm(k2); liftA = sin(Double.pi * k2) * 110 }
            p.spin = spinA; p.lift = liftA
            let c2 = sm(seg(u, 0.38, 0.46)) * (1 - sm(seg(u, 0.46, 0.48)))
            var land = 0.0
            if u > 0.32 && u < 0.4 { land += sm(seg(u, 0.32, 0.34)) * (1 - sm(seg(u, 0.36, 0.42))) }
            if u > 0.68 && u < 0.76 { land += sm(seg(u, 0.68, 0.7)) * (1 - sm(seg(u, 0.72, 0.78))) }
            p.squash = 1 - 0.22 * max(c1, c2, land)
            let bow = sm(seg(u, 0.76, 0.82)) * (1 - sm(seg(u, 0.9, 0.95)))
            p.bodyRot = bow * 16
            p.headRot = bow * 14
            p.tail = sin(t * 20) * 24
            p.tongue = 1; p.mouth = 0.5
            p.eyes = bow > 0.3 ? 1 : 0
            if u > 0.14 && u < 0.32 { p.mouth = 0.7 }

        case .fly:
            var b: (x: Double, z: Double, h: Double)?
            if u < 0.5 {
                let a = 2 * Double.pi * 2.2 * u
                b = (0.14 * cos(a) + 0.04, z0 + 0.03 * sin(a * 1.3), 150 + 55 * sin(a * 1.7))
                p.headRot = -16 * sin(a + 1) * sm(seg(u, 0.02, 0.1))
                p.mouth = 0.3; p.tongue = 1
                p.lift += jump(u, 0.28, 0.34, 18) + jump(u, 0.36, 0.42, 22) + jump(u, 0.44, 0.5, 26)
            } else if u < 0.66 {
                let k = sm(seg(u, 0.5, 0.64))
                b = (lerp(0.04, 0.78, k), lerp(z0, 0.86, k), lerp(120, 60, k) + 20 * sin(t * 5))
            } else if u < 0.72 {
                b = (0.78 + 0.03 * sin(t * 3), 0.86, 60 + 10 * sin(t * 5))
                p.headRot = -10
            } else if u < 0.84 {
                let k = sm(seg(u, 0.72, 0.84))
                b = (lerp(0.78, 0.66, k), lerp(0.86, 0.82, k), lerp(60, 50, k) + 8 * sin(t * 6))
                p.headRot = -10 * (1 - k)
            }
            if u < 0.84 { pr.bfly = b }
            if u >= 0.84 && u < 0.985 {
                p.bflyNose = true; p.eyes = 3; p.tongue = 0; p.mouth = 0; p.headRot = 6
            }
            if u >= 0.985 { pr.bfly = (x + 0.02, z, 60 + (u - 0.985) / 0.015 * 160) }
        }
        return PupState(x: x, z: z, face: fc, pose: p, props: pr)
    }
}
