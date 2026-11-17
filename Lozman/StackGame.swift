import SwiftUI
import Observation
import UIKit

/// "Kule": a sliding block moves back and forth; tap to drop it on the tower.
/// Whatever hangs over the edge is cut off. Perfect drops keep the full width.
@Observable
final class StackGame {
    enum Phase { case ready, playing, over }

    struct Block {
        var x: CGFloat
        var w: CGFloat
        var hue: Double
    }

    struct Falling {
        var x: CGFloat
        var w: CGFloat
        var level: Int
        var hue: Double
        var start: Date
        var drift: CGFloat
    }

    let worldW: CGFloat = 320
    let blockH: CGFloat = 28

    var phase: Phase = .ready
    var blocks: [Block] = []
    var falling: [Falling] = []
    var movingW: CGFloat = 200
    var movingHue: Double = 0
    var spawnTime = Date()
    var fromRight = false
    var speed: CGFloat = 170
    var score = 0
    var perfects = 0
    var best = UserDefaults.standard.integer(forKey: "stackBest")
    var newBest = false
    var perfectAt: Date?
    var camFrom: CGFloat = 0
    var camTo: CGFloat = 0
    var camStart = Date()
    var confetti = 0
    var flash: String?
    var flashID = 0
    private let baseHue = Double.random(in: 0...1)

    init() { reset() }

    func reset() {
        blocks = [Block(x: (worldW - 200) / 2, w: 200, hue: baseHue)]
        falling = []
        movingW = 200
        score = 0
        perfects = 0
        speed = 170
        newBest = false
        camFrom = 0
        camTo = 0
        flash = nil
        nextBlock()
    }

    private func nextBlock() {
        movingHue = (baseHue + Double(blocks.count) * 0.035).truncatingRemainder(dividingBy: 1)
        fromRight.toggle()
        spawnTime = Date()
    }

    /// Position of the moving block at a given time (it bounces between the edges).
    func movingX(at t: Date) -> CGFloat {
        let range = worldW + movingW
        let travel = CGFloat(t.timeIntervalSince(spawnTime)) * speed
        var p = travel.truncatingRemainder(dividingBy: range * 2)
        if p > range { p = range * 2 - p }
        return fromRight ? worldW - p : p - movingW
    }

    func camera(at t: Date) -> CGFloat {
        let k = min(1, CGFloat(t.timeIntervalSince(camStart)) / 0.3)
        let e = 1 - pow(1 - k, 3)
        return camFrom + (camTo - camFrom) * e
    }

    func tap() {
        switch phase {
        case .ready:
            phase = .playing
            spawnTime = Date()
        case .over:
            reset()
            phase = .playing
        case .playing:
            drop()
        }
    }

    private func drop() {
        let now = Date()
        guard let top = blocks.last else { return }
        let x = movingX(at: now)
        let left = max(x, top.x)
        let right = min(x + movingW, top.x + top.w)
        let overlap = right - left

        if overlap <= 0 {
            falling.append(Falling(x: x, w: movingW, level: blocks.count, hue: movingHue, start: now, drift: x < top.x ? -40 : 40))
            gameOver()
            return
        }

        if abs(x - top.x) < 5 {
            // Perfect: snap into place and keep the width.
            perfects += 1
            var w = top.w
            if perfects >= 3 { w = min(worldW * 0.8, w + 10) }
            blocks.append(Block(x: top.x - (w - top.w) / 2, w: w, hue: movingHue))
            movingW = w
            perfectAt = now
            if perfects >= 3 {
                Sfx.play("combo")
                flash = "Mükemmel x\(perfects)!"
                flashID += 1
            } else {
                Sfx.play("correct")
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            perfects = 0
            blocks.append(Block(x: left, w: overlap, hue: movingHue))
            let cutX = x < top.x ? x : right
            let cutW = movingW - overlap
            falling.append(Falling(x: cutX, w: cutW, level: blocks.count - 1, hue: movingHue, start: now, drift: x < top.x ? -30 : 30))
            movingW = overlap
            Sfx.play("pop")
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        score += 1
        if score % 10 == 0 {
            flash = "\(score) kat!"
            flashID += 1
            confetti += 1
        }
        speed = min(420, 170 + CGFloat(score) * 5)
        falling.removeAll { now.timeIntervalSince($0.start) > 2.5 }
        camFrom = camera(at: now)
        camTo = max(0, CGFloat(blocks.count - 7)) * blockH
        camStart = now
        nextBlock()
    }

    private func gameOver() {
        phase = .over
        if score > best {
            best = score
            newBest = true
            UserDefaults.standard.set(best, forKey: "stackBest")
            confetti += 1
            Sfx.play("levelup")
        } else {
            Sfx.play("wrong")
        }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

struct StackGameView: View {
    @State private var game = StackGame()

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date
            Canvas { ctx, size in
                draw(ctx: ctx, size: size, now: now)
            }
        }
        .background(background.ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture { game.tap() }
        .overlay(alignment: .top) { hud }
        .overlay { overlayCard }
        .overlay { ConfettiView(trigger: game.confetti).allowsHitTesting(false) }
        .navigationTitle("Kule")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var background: some View {
        let h = (Double(game.blocks.count) * 0.012).truncatingRemainder(dividingBy: 1)
        return LinearGradient(
            colors: [Color(hue: h, saturation: 0.35, brightness: 0.30), Color(hue: (h + 0.08).truncatingRemainder(dividingBy: 1), saturation: 0.45, brightness: 0.14)],
            startPoint: .top, endPoint: .bottom
        )
        .animation(.easeInOut(duration: 0.6), value: game.blocks.count)
    }

    private func color(_ hue: Double, _ shade: Double) -> Color {
        Color(hue: hue, saturation: 0.55, brightness: 0.62 + shade)
    }

    private func draw(ctx: GraphicsContext, size: CGSize, now: Date) {
        let scale = size.width / game.worldW
        let bh = game.blockH * scale
        let baseY = size.height * 0.72
        let cam = game.camera(at: now) * scale

        func rect(x: CGFloat, w: CGFloat, level: Int) -> CGRect {
            CGRect(x: x * scale, y: baseY - CGFloat(level) * bh + cam, width: w * scale, height: bh)
        }

        func block(_ r: CGRect, hue: Double, glow: Bool = false) {
            let path = Path(roundedRect: r.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 5)
            ctx.fill(path, with: .linearGradient(Gradient(colors: [color(hue, 0.18), color(hue, -0.05)]),
                                                 startPoint: CGPoint(x: r.midX, y: r.minY), endPoint: CGPoint(x: r.midX, y: r.maxY)))
            let shine = Path(roundedRect: CGRect(x: r.minX + 4, y: r.minY + 3, width: max(0, r.width - 8), height: r.height * 0.22), cornerRadius: 3)
            ctx.fill(shine, with: .color(.white.opacity(0.22)))
            if glow {
                ctx.stroke(path, with: .color(.white.opacity(0.9)), lineWidth: 2)
            }
        }

        // Pillar under the first block so the tower stands on something.
        if let first = game.blocks.first {
            let r = rect(x: first.x, w: first.w, level: 0)
            ctx.fill(Path(CGRect(x: r.minX, y: r.maxY, width: r.width, height: size.height)), with: .color(color(first.hue, -0.25).opacity(0.6)))
        }

        for (i, b) in game.blocks.enumerated() {
            let isTop = i == game.blocks.count - 1
            block(rect(x: b.x, w: b.w, level: i), hue: b.hue, glow: isTop && game.perfectAt.map { now.timeIntervalSince($0) < 0.25 } == true)
        }

        // Perfect ripple
        if let p = game.perfectAt, let top = game.blocks.last {
            let t = now.timeIntervalSince(p)
            if t < 0.5 {
                let r = rect(x: top.x, w: top.w, level: game.blocks.count - 1)
                let grow = CGFloat(t) * 60
                ctx.stroke(Path(roundedRect: r.insetBy(dx: -grow, dy: -grow * 0.5), cornerRadius: 6),
                           with: .color(.white.opacity(0.8 * (1 - t / 0.5))), lineWidth: 2)
            }
        }

        // Cut-off pieces falling and spinning away
        for f in game.falling {
            let t = CGFloat(now.timeIntervalSince(f.start))
            var r = rect(x: f.x, w: f.w, level: f.level)
            r.origin.y += 0.5 * 1800 * t * t
            r.origin.x += f.drift * t * scale
            var c = ctx
            c.translateBy(x: r.midX, y: r.midY)
            c.rotate(by: .radians(Double(f.drift > 0 ? t * 2 : -t * 2)))
            c.opacity = max(0, 1 - Double(t) / 1.6)
            let local = CGRect(x: -r.width / 2, y: -r.height / 2, width: r.width, height: r.height)
            c.fill(Path(roundedRect: local, cornerRadius: 5), with: .color(color(f.hue, 0.05)))
        }

        // The moving block
        if game.phase == .playing {
            let x = game.movingX(at: now)
            block(rect(x: x, w: game.movingW, level: game.blocks.count), hue: game.movingHue)
        }
    }

    private var hud: some View {
        VStack(spacing: 2) {
            Text("\(game.score)")
                .font(.system(size: 64, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.snappy, value: game.score)
                .shadow(color: .black.opacity(0.3), radius: 6)
            if game.perfects >= 2 {
                Text("Mükemmel seri: \(game.perfects)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.yellow)
            }
            if let f = game.flash {
                Text(f)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.loz, in: Capsule())
                    .transition(.scale.combined(with: .opacity))
                    .id(game.flashID)
                    .task(id: game.flashID) {
                        try? await Task.sleep(nanoseconds: 900_000_000)
                        withAnimation { game.flash = nil }
                    }
            }
        }
        .padding(.top, 20)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var overlayCard: some View {
        switch game.phase {
        case .ready:
            card(title: "KULE", subtitle: "Blok tam üstteki bloğun üstüne gelince dokun.\nTaşan kısım kesilir, tam isabet seri yapar.", button: "Başlamak için dokun", best: true)
        case .over:
            card(title: game.newBest ? "YENİ REKOR!" : "Kule yıkıldı", subtitle: "\(game.score) kat", button: "Tekrar için dokun", best: true)
        case .playing:
            EmptyView()
        }
    }

    private func card(title: String, subtitle: String, button: String, best: Bool) -> some View {
        VStack(spacing: 10) {
            Text(title).font(.system(size: 36, weight: .black, design: .rounded)).foregroundStyle(.white)
            Text(subtitle).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.85))
            if best { Label("Rekor: \(game.best)", systemImage: "crown.fill").foregroundStyle(.yellow) }
            Text(button).font(.headline).foregroundStyle(.white).padding(.top, 6)
        }
        .padding(26)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 22))
        .allowsHitTesting(false)
    }
}
