import SwiftUI
import Observation
import UIKit

struct Tile2048: Identifiable, Equatable {
    let id = UUID()
    var value: Int
    var r: Int
    var c: Int
    var dying = false
    var pop = 0
}

@Observable
final class Game2048 {
    var tiles: [Tile2048] = []
    var score = 0
    var best = UserDefaults.standard.integer(forKey: "g2048Best")
    var bestTile = UserDefaults.standard.integer(forKey: "g2048BestTile")
    var over = false
    var newBest = false
    var reached: Set<Int> = []
    var flash: String?
    var flashID = 0
    var confetti = 0

    enum Dir { case left, right, up, down }

    init() { reset() }

    func reset() {
        tiles = []
        score = 0
        over = false
        newBest = false
        reached = []
        flash = nil
        spawn()
        spawn()
    }

    private func spawn() {
        var free: [(Int, Int)] = []
        for r in 0..<4 {
            for c in 0..<4 where !tiles.contains(where: { $0.r == r && $0.c == c && !$0.dying }) {
                free.append((r, c))
            }
        }
        guard let spot = free.randomElement() else { return }
        tiles.append(Tile2048(value: Int.random(in: 0..<10) == 0 ? 4 : 2, r: spot.0, c: spot.1))
    }

    private func line(_ dir: Dir, _ i: Int) -> [(Int, Int)] {
        switch dir {
        case .left: return (0..<4).map { (i, $0) }
        case .right: return (0..<4).reversed().map { (i, $0) }
        case .up: return (0..<4).map { ($0, i) }
        case .down: return (0..<4).reversed().map { ($0, i) }
        }
    }

    func move(_ dir: Dir) {
        guard !over else { return }
        tiles.removeAll { $0.dying }
        var moved = false
        var gained = 0
        var biggest = 0
        for i in 0..<4 {
            let spots = line(dir, i)
            let indices = spots.compactMap { s in tiles.firstIndex { $0.r == s.0 && $0.c == s.1 } }
            var slot = 0
            var lastIdx: Int?
            var lastMerged = false
            for idx in indices {
                if let li = lastIdx, !lastMerged, tiles[li].value == tiles[idx].value {
                    tiles[li].value *= 2
                    tiles[li].pop += 1
                    tiles[idx].r = tiles[li].r
                    tiles[idx].c = tiles[li].c
                    tiles[idx].dying = true
                    gained += tiles[li].value
                    biggest = max(biggest, tiles[li].value)
                    lastMerged = true
                    moved = true
                } else {
                    let s = spots[slot]
                    if tiles[idx].r != s.0 || tiles[idx].c != s.1 { moved = true }
                    tiles[idx].r = s.0
                    tiles[idx].c = s.1
                    lastIdx = idx
                    lastMerged = false
                    slot += 1
                }
            }
        }
        guard moved else {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.4)
            return
        }
        score += gained
        if gained > 0 {
            if biggest >= 512 { Sfx.play("combo") } else if biggest >= 64 { Sfx.play("correct") } else { Sfx.play("pop") }
            UIImpactFeedbackGenerator(style: biggest >= 128 ? .heavy : .light).impactOccurred()
            for milestone in [256, 512, 1024, 2048, 4096] where biggest >= milestone && !reached.contains(milestone) {
                reached.insert(milestone)
                flash = milestone == 2048 ? "2048! KAZANDIN!" : "\(milestone)!"
                flashID += 1
                if milestone >= 1024 { confetti += 1; Sfx.play("levelup") }
            }
            if biggest > bestTile {
                bestTile = biggest
                UserDefaults.standard.set(biggest, forKey: "g2048BestTile")
            }
        }
        spawn()
        if score > best {
            best = score
            UserDefaults.standard.set(best, forKey: "g2048Best")
            if !newBest && score > 200 { newBest = true }
        }
        if !canMove() {
            over = true
            Sfx.play(newBest ? "levelup" : "wrong")
            if newBest { confetti += 1 }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func value(_ r: Int, _ c: Int) -> Int? {
        tiles.first { $0.r == r && $0.c == c && !$0.dying }?.value
    }

    private func canMove() -> Bool {
        for r in 0..<4 {
            for c in 0..<4 {
                guard let v = value(r, c) else { return true }
                if c < 3, value(r, c + 1) == v { return true }
                if r < 3, value(r + 1, c) == v { return true }
            }
        }
        return false
    }
}

struct Game2048View: View {
    @State private var game = Game2048()

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width - 32, 420)
            let gap: CGFloat = 10
            let cell = (side - gap * 5) / 4
            VStack(spacing: 18) {
                HStack {
                    scoreBox("Skor", game.score)
                    scoreBox("Rekor", game.best)
                    Button {
                        withAnimation(.snappy) { game.reset() }
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title3.weight(.bold))
                            .frame(width: 54, height: 54)
                            .background(Color.loz, in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("Yeniden başla")
                }
                .frame(width: side)

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 16).fill(Color(red: 0.73, green: 0.68, blue: 0.63))
                    ForEach(0..<16, id: \.self) { k in
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.25))
                            .frame(width: cell, height: cell)
                            .offset(x: gap + CGFloat(k % 4) * (cell + gap), y: gap + CGFloat(k / 4) * (cell + gap))
                    }
                    ForEach(game.tiles) { t in
                        TileView(tile: t, size: cell)
                            .offset(x: gap + CGFloat(t.c) * (cell + gap), y: gap + CGFloat(t.r) * (cell + gap))
                            .zIndex(t.dying ? 0 : 1)
                            .transition(.scale(scale: 0.2).combined(with: .opacity))
                    }
                }
                .frame(width: side, height: side)
                .animation(.snappy(duration: 0.13), value: game.tiles)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 18).onEnded { v in
                        let dx = v.translation.width, dy = v.translation.height
                        let dir: Game2048.Dir = abs(dx) > abs(dy) ? (dx > 0 ? .right : .left) : (dy > 0 ? .down : .up)
                        game.move(dir)
                    }
                )
                Text("Kaydırarak aynı sayıları birleştir. 2048'e ulaş!")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
        }
        .overlay(alignment: .top) {
            if let f = game.flash {
                Text(f)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.loz, in: Capsule())
                    .padding(.top, 90)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
                    .id(game.flashID)
                    .task(id: game.flashID) {
                        try? await Task.sleep(nanoseconds: 1_100_000_000)
                        withAnimation { game.flash = nil }
                    }
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            if game.over {
                VStack(spacing: 12) {
                    Text(game.newBest ? "YENİ REKOR!" : "Hamle kalmadı")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                    Text("Skor: \(game.score) · En büyük taş: \(game.bestTile)").foregroundStyle(.secondary)
                    Button {
                        withAnimation { game.reset() }
                    } label: {
                        Text("Tekrar oyna").font(.headline).frame(width: 200, height: 50)
                            .background(Color.loz, in: Capsule()).foregroundStyle(.white)
                    }
                }
                .padding(28)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
                .transition(.scale.combined(with: .opacity))
            }
        }
        .overlay { ConfettiView(trigger: game.confetti).allowsHitTesting(false) }
        .navigationTitle("2048")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func scoreBox(_ title: String, _ value: Int) -> some View {
        VStack(spacing: 0) {
            Text(title.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(.white.opacity(0.8))
            Text("\(value)")
                .font(.title3.weight(.heavy).monospacedDigit())
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.snappy, value: value)
        }
        .frame(maxWidth: .infinity, minHeight: 54)
        .background(Color(red: 0.55, green: 0.50, blue: 0.46), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct TileView: View {
    let tile: Tile2048
    let size: CGFloat
    @State private var bump = false

    private var colors: (Color, Color) {
        switch tile.value {
        case 2: return (Color(red: 0.93, green: 0.89, blue: 0.85), Color(red: 0.47, green: 0.43, blue: 0.40))
        case 4: return (Color(red: 0.93, green: 0.88, blue: 0.78), Color(red: 0.47, green: 0.43, blue: 0.40))
        case 8: return (Color(red: 0.95, green: 0.69, blue: 0.47), .white)
        case 16: return (Color(red: 0.96, green: 0.58, blue: 0.39), .white)
        case 32: return (Color(red: 0.96, green: 0.49, blue: 0.37), .white)
        case 64: return (Color(red: 0.96, green: 0.37, blue: 0.23), .white)
        case 128: return (Color(red: 0.93, green: 0.81, blue: 0.45), .white)
        case 256: return (Color(red: 0.93, green: 0.80, blue: 0.38), .white)
        case 512: return (Color(red: 0.93, green: 0.78, blue: 0.31), .white)
        case 1024: return (Color(red: 0.93, green: 0.77, blue: 0.25), .white)
        case 2048: return (Color(red: 0.93, green: 0.76, blue: 0.18), .white)
        default: return (Color(red: 0.24, green: 0.23, blue: 0.20), .white)
        }
    }

    var body: some View {
        let digits = String(tile.value).count
        RoundedRectangle(cornerRadius: 10)
            .fill(colors.0)
            .overlay(
                Text("\(tile.value)")
                    .font(.system(size: size * (digits <= 2 ? 0.45 : (digits == 3 ? 0.36 : 0.28)), weight: .heavy, design: .rounded))
                    .foregroundStyle(colors.1)
                    .minimumScaleFactor(0.5)
            )
            .shadow(color: tile.value >= 128 ? colors.0.opacity(0.8) : .clear, radius: tile.value >= 128 ? 10 : 0)
            .frame(width: size, height: size)
            .scaleEffect(bump ? 1.14 : 1)
            .onChange(of: tile.pop) { _, _ in
                withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) { bump = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) { bump = false }
                }
            }
    }
}
