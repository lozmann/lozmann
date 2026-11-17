import SwiftUI
import Observation
import UIKit

struct Cell: Hashable {
    var x: Int
    var y: Int
}

@Observable
final class SnakeGame {
    enum State { case ready, running, paused, over }

    let cols = 17
    let rows = 25

    var snake: [Cell] = []
    var direction = Cell(x: 1, y: 0)
    private var queued: [Cell] = []
    var food = Cell(x: 10, y: 10)
    var goldenFood = false
    var score = 0
    var eaten = 0
    var best = UserDefaults.standard.integer(forKey: "snakeBest")
    var state: State = .ready
    var newBest = false
    var runID = 0
    var flash: String?
    var confetti = 0

    init() { reset() }

    var interval: UInt64 {
        // Starts calm, speeds up as the snake grows.
        let ms = max(65, 150 - eaten * 3)
        return UInt64(ms) * 1_000_000
    }

    func reset() {
        let midY = rows / 2
        snake = [Cell(x: 6, y: midY), Cell(x: 5, y: midY), Cell(x: 4, y: midY)]
        direction = Cell(x: 1, y: 0)
        queued = []
        score = 0
        eaten = 0
        newBest = false
        flash = nil
        placeFood()
    }

    func start() {
        if state == .over || state == .ready { reset() }
        state = .running
        runID += 1
    }

    func pause() {
        if state == .running { state = .paused }
    }

    func turn(_ d: Cell) {
        if state != .running { start() }
        let last = queued.last ?? direction
        // No turning straight back into yourself, and no duplicate input.
        guard d != last, d.x != -last.x || d.y != -last.y else { return }
        if queued.count < 3 { queued.append(d) }
    }

    private func placeFood() {
        var spot: Cell
        repeat {
            spot = Cell(x: Int.random(in: 0..<cols), y: Int.random(in: 0..<rows))
        } while snake.contains(spot)
        food = spot
        goldenFood = (eaten + 1) % 7 == 0
    }

    func tick() {
        guard state == .running, let head = snake.first else { return }
        if !queued.isEmpty { direction = queued.removeFirst() }
        let next = Cell(x: head.x + direction.x, y: head.y + direction.y)

        let hitsWall = next.x < 0 || next.y < 0 || next.x >= cols || next.y >= rows
        let hitsSelf = snake.dropLast().contains(next)
        if hitsWall || hitsSelf {
            state = .over
            if score > best {
                best = score
                newBest = true
                UserDefaults.standard.set(best, forKey: "snakeBest")
                confetti += 1
                Sfx.play("levelup")
                Sfx.success()
            } else {
                Sfx.play("wrong")
                Sfx.failure()
            }
            return
        }

        snake.insert(next, at: 0)
        if next == food {
            eaten += 1
            let points = goldenFood ? 5 : 1
            score += points
            if goldenFood {
                flash = "Altın elma +5"
                Sfx.play("combo")
                Sfx.success()
            } else if eaten % 5 == 0 {
                flash = "\(eaten) elma!"
                Sfx.play("combo")
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } else {
                Sfx.play("correct")
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            placeFood()
        } else {
            snake.removeLast()
        }
    }
}

struct SnakeView: View {
    @State private var game = SnakeGame()

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                scoreBox("Skor", "\(game.score)")
                scoreBox("Rekor", "\(game.best)")
                scoreBox("Uzunluk", "\(game.snake.count)")
            }

            GeometryReader { geo in
                let cell = min(geo.size.width / CGFloat(game.cols), geo.size.height / CGFloat(game.rows))
                let w = cell * CGFloat(game.cols), h = cell * CGFloat(game.rows)
                ZStack {
                    board(cell: cell)
                        .frame(width: w, height: h)
                    overlay
                }
                .frame(width: w, height: h)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 12)
                        .onEnded { v in
                            let dx = v.translation.width, dy = v.translation.height
                            if abs(dx) > abs(dy) {
                                game.turn(Cell(x: dx > 0 ? 1 : -1, y: 0))
                            } else {
                                game.turn(Cell(x: 0, y: dy > 0 ? 1 : -1))
                            }
                        }
                )
                .onTapGesture {
                    if game.state != .running { game.start() }
                }
            }

            controls
        }
        .padding()
        .overlay(alignment: .top) {
            if let f = game.flash, game.state == .running {
                Text(f)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.loz, in: Capsule())
                    .padding(.top, 60)
                    .transition(.scale.combined(with: .opacity))
                    .task(id: f + "\(game.eaten)") {
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        withAnimation { game.flash = nil }
                    }
            }
        }
        .overlay { ConfettiView(trigger: game.confetti).allowsHitTesting(false) }
        .navigationTitle("Yılan")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: game.runID) {
            while game.state == .running && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: game.interval)
                game.tick()
            }
        }
        .onDisappear { game.pause() }
    }

    private func scoreBox(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.weight(.bold).monospacedDigit())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func board(cell: CGFloat) -> some View {
        Canvas { ctx, size in
            // Checkerboard background
            for y in 0..<game.rows {
                for x in 0..<game.cols where (x + y) % 2 == 0 {
                    ctx.fill(Path(CGRect(x: CGFloat(x) * cell, y: CGFloat(y) * cell, width: cell, height: cell)),
                             with: .color(Color.primary.opacity(0.035)))
                }
            }
            // Food
            let f = CGRect(x: CGFloat(game.food.x) * cell, y: CGFloat(game.food.y) * cell, width: cell, height: cell).insetBy(dx: cell * 0.12, dy: cell * 0.12)
            ctx.fill(Path(ellipseIn: f), with: .color(game.goldenFood ? .yellow : .red))
            if game.goldenFood {
                ctx.stroke(Path(ellipseIn: f.insetBy(dx: -2, dy: -2)), with: .color(.orange), lineWidth: 2)
            }
            // Snake: bright head, body fading towards the tail
            let n = max(1, game.snake.count)
            for (i, c) in game.snake.enumerated() {
                let r = CGRect(x: CGFloat(c.x) * cell, y: CGFloat(c.y) * cell, width: cell, height: cell).insetBy(dx: 1, dy: 1)
                let fade = 1.0 - 0.55 * Double(i) / Double(n)
                ctx.fill(Path(roundedRect: r, cornerRadius: cell * 0.3), with: .color(Color.loz.opacity(i == 0 ? 1 : fade)))
                if i == 0 {
                    let eye = cell * 0.16
                    let cx = r.midX + CGFloat(game.direction.x) * cell * 0.18
                    let cy = r.midY + CGFloat(game.direction.y) * cell * 0.18
                    let ox = CGFloat(game.direction.y) * cell * 0.2, oy = CGFloat(game.direction.x) * cell * 0.2
                    for s in [-1.0, 1.0] {
                        ctx.fill(Path(ellipseIn: CGRect(x: cx + ox * s - eye / 2, y: cy + oy * s - eye / 2, width: eye, height: eye)), with: .color(.white))
                    }
                }
            }
        }
        .background(Color(.secondarySystemBackground).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.loz.opacity(0.35), lineWidth: 2))
    }

    @ViewBuilder
    private var overlay: some View {
        switch game.state {
        case .ready:
            message(title: "Yılan", subtitle: "Kaydırarak yön ver. Başlamak için dokun.", button: "Başla")
        case .paused:
            message(title: "Durdu", subtitle: "Skor: \(game.score)", button: "Devam et")
        case .over:
            message(title: game.newBest ? "Yeni rekor!" : "Oyun bitti",
                    subtitle: "Skor: \(game.score) · Rekor: \(game.best)", button: "Tekrar oyna")
        case .running:
            EmptyView()
        }
    }

    private func message(title: String, subtitle: String, button: String) -> some View {
        VStack(spacing: 10) {
            Text(title).font(.title.weight(.heavy))
            Text(subtitle).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button(button) { game.start() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var controls: some View {
        HStack(spacing: 18) {
            Button { game.pause() } label: {
                Image(systemName: "pause.fill").frame(width: 44, height: 44)
            }
            .buttonStyle(.bordered)
            .disabled(game.state != .running)
            .accessibilityLabel("Durdur")
            Spacer()
            HStack(spacing: 6) {
                arrow("arrow.left", Cell(x: -1, y: 0))
                VStack(spacing: 6) {
                    arrow("arrow.up", Cell(x: 0, y: -1))
                    arrow("arrow.down", Cell(x: 0, y: 1))
                }
                arrow("arrow.right", Cell(x: 1, y: 0))
            }
        }
    }

    private func arrow(_ icon: String, _ d: Cell) -> some View {
        Button { game.turn(d) } label: {
            Image(systemName: icon)
                .font(.headline)
                .frame(width: 46, height: 40)
        }
        .buttonStyle(.bordered)
        .tint(.loz)
    }
}
