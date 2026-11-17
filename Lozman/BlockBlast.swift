import SwiftUI
import Observation
import UIKit

struct BBCell: Hashable {
    let r: Int
    let c: Int
}

struct BBPiece: Identifiable, Equatable {
    let id = UUID()
    let cells: [BBCell]
    let color: Int
    var rows: Int { (cells.map(\.r).max() ?? 0) + 1 }
    var cols: Int { (cells.map(\.c).max() ?? 0) + 1 }
}

enum BBShapes {
    static let colors: [Color] = [
        Color(red: 1.00, green: 0.45, blue: 0.15), Color(red: 1.00, green: 0.78, blue: 0.18),
        Color(red: 0.30, green: 0.82, blue: 0.40), Color(red: 0.22, green: 0.68, blue: 1.00),
        Color(red: 0.62, green: 0.42, blue: 1.00), Color(red: 1.00, green: 0.35, blue: 0.55),
        Color(red: 0.20, green: 0.85, blue: 0.80)
    ]

    static let shapes: [[(Int, Int)]] = [
        [(0, 0)],
        [(0, 0), (0, 1)], [(0, 0), (1, 0)],
        [(0, 0), (0, 1), (0, 2)], [(0, 0), (1, 0), (2, 0)],
        [(0, 0), (0, 1), (0, 2), (0, 3)], [(0, 0), (1, 0), (2, 0), (3, 0)],
        [(0, 0), (0, 1), (0, 2), (0, 3), (0, 4)], [(0, 0), (1, 0), (2, 0), (3, 0), (4, 0)],
        [(0, 0), (0, 1), (1, 0), (1, 1)],
        [(0, 0), (0, 1), (0, 2), (1, 0), (1, 1), (1, 2), (2, 0), (2, 1), (2, 2)],
        [(0, 0), (1, 0), (1, 1)], [(0, 0), (0, 1), (1, 0)], [(0, 0), (0, 1), (1, 1)], [(0, 1), (1, 0), (1, 1)],
        [(0, 0), (1, 0), (2, 0), (2, 1)], [(0, 0), (0, 1), (0, 2), (1, 0)], [(0, 0), (0, 1), (1, 1), (2, 1)], [(0, 2), (1, 0), (1, 1), (1, 2)],
        [(0, 0), (0, 1), (0, 2), (1, 1)], [(0, 1), (1, 0), (1, 1), (2, 1)], [(0, 1), (1, 0), (1, 1), (1, 2)], [(0, 0), (1, 0), (1, 1), (2, 0)],
        [(0, 0), (0, 1), (1, 1), (1, 2)], [(0, 1), (0, 2), (1, 0), (1, 1)],
        [(0, 0), (1, 0), (2, 0), (2, 1), (2, 2)], [(0, 0), (0, 1), (0, 2), (1, 2), (2, 2)]
    ]

    static func random() -> BBPiece {
        let s = shapes.randomElement() ?? [(0, 0)]
        return BBPiece(cells: s.map { BBCell(r: $0.0, c: $0.1) }, color: Int.random(in: 0..<colors.count))
    }
}

@Observable
final class BlockGame {
    let n = 8
    var grid: [[Int?]] = []
    var tray: [BBPiece?] = []
    var score = 0
    var best = UserDefaults.standard.integer(forKey: "blockBest")
    var combo = 0
    private var movesSinceClear = 0
    var burst: [BBCell: Int] = [:]
    var burstID = 0
    var over = false
    var newBest = false
    var flash: String?
    var flashID = 0
    var confetti = 0

    init() { reset() }

    func reset() {
        grid = Array(repeating: Array(repeating: nil, count: n), count: n)
        tray = (0..<3).map { _ in BBShapes.random() }
        score = 0
        combo = 0
        movesSinceClear = 0
        burst = [:]
        over = false
        newBest = false
        flash = nil
    }

    func canPlace(_ p: BBPiece, at r: Int, _ c: Int) -> Bool {
        for cell in p.cells {
            let rr = r + cell.r, cc = c + cell.c
            if rr < 0 || cc < 0 || rr >= n || cc >= n { return false }
            if grid[rr][cc] != nil { return false }
        }
        return true
    }

    private func fitsAnywhere(_ p: BBPiece) -> Bool {
        for r in 0..<n {
            for c in 0..<n where canPlace(p, at: r, c) { return true }
        }
        return false
    }

    @discardableResult
    func place(_ index: Int, at r: Int, _ c: Int) -> Bool {
        guard index < tray.count, let p = tray[index], canPlace(p, at: r, c) else { return false }
        for cell in p.cells { grid[r + cell.r][c + cell.c] = p.color }
        tray[index] = nil
        score += p.cells.count

        // Find full rows and columns.
        var cleared = Set<BBCell>()
        var lines = 0
        for row in 0..<n where grid[row].allSatisfy({ $0 != nil }) {
            lines += 1
            for col in 0..<n { cleared.insert(BBCell(r: row, c: col)) }
        }
        for col in 0..<n where (0..<n).allSatisfy({ grid[$0][col] != nil }) {
            lines += 1
            for row in 0..<n { cleared.insert(BBCell(r: row, c: col)) }
        }

        if lines > 0 {
            combo += 1
            movesSinceClear = 0
            var colors: [BBCell: Int] = [:]
            for cell in cleared {
                colors[cell] = grid[cell.r][cell.c] ?? p.color
                grid[cell.r][cell.c] = nil
            }
            burst = colors
            burstID += 1
            let points = lines * 10 * combo + (lines >= 2 ? lines * 20 : 0)
            score += points
            if lines >= 3 {
                flash = "MUHTEŞEM! +\(points)"
                confetti += 1
                Sfx.play("levelup")
            } else if lines == 2 || combo >= 3 {
                flash = combo >= 3 ? "Kombo x\(combo)! +\(points)" : "Çift! +\(points)"
                Sfx.play("combo")
            } else {
                flash = "+\(points)"
                Sfx.play("correct")
            }
            flashID += 1
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            movesSinceClear += 1
            if movesSinceClear >= 3 { combo = 0 }
            Sfx.play("pop")
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        if tray.allSatisfy({ $0 == nil }) {
            tray = (0..<3).map { _ in BBShapes.random() }
        }
        if !tray.compactMap({ $0 }).contains(where: fitsAnywhere) {
            finish()
        }
        return true
    }

    private func finish() {
        over = true
        if score > best {
            best = score
            newBest = true
            UserDefaults.standard.set(best, forKey: "blockBest")
            confetti += 1
            Sfx.play("levelup")
        } else {
            Sfx.play("wrong")
        }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

private struct BoardFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}

struct BlockBlastView: View {
    @State private var game = BlockGame()
    @State private var boardFrame: CGRect = .zero
    @State private var dragIndex: Int?
    @State private var dragPoint: CGPoint = .zero
    @State private var burstVisible = false
    private let lift: CGFloat = 90

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width - 32, geo.size.height * 0.6, 440)
            let cell = side / CGFloat(game.n)
            VStack(spacing: 16) {
                header
                board(cell: cell)
                    .frame(width: side, height: side)
                    .background(GeometryReader { g in
                        Color.clear.preference(key: BoardFrameKey.self, value: g.frame(in: .named("bb")))
                    })
                tray(cell: cell, width: side)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                if let i = dragIndex, i < game.tray.count, let p = game.tray[i] {
                    pieceShape(p, cell: cell, alpha: 0.95)
                        .frame(width: CGFloat(p.cols) * cell, height: CGFloat(p.rows) * cell)
                        .position(x: dragPoint.x, y: dragPoint.y - lift)
                        .shadow(color: .black.opacity(0.3), radius: 10, y: 6)
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .top) { flashBanner }
            .overlay { if game.over { gameOverCard } }
            .overlay { ConfettiView(trigger: game.confetti).allowsHitTesting(false) }
            .coordinateSpace(name: "bb")
            .onPreferenceChange(BoardFrameKey.self) { boardFrame = $0 }
            .onChange(of: game.burstID) { _, _ in
                burstVisible = true
                withAnimation(.easeOut(duration: 0.45)) { burstVisible = false }
            }
        }
        .padding(.top, 8)
        .background(Color(red: 0.10, green: 0.11, blue: 0.17).ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .navigationTitle("Blok Patlat")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(game.score)")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .contentTransition(.numericText())
                    .animation(.snappy, value: game.score)
                if game.combo >= 2 {
                    Text("Kombo x\(game.combo)").font(.caption.weight(.bold)).foregroundStyle(Color.loz)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Label("\(game.best)", systemImage: "crown.fill").foregroundStyle(.yellow)
                Button("Yeniden") { withAnimation { game.reset() } }.font(.caption)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
    }

    /// Which cell the dragged piece's top-left would land on.
    private func target(for p: BBPiece, cell: CGFloat) -> (Int, Int) {
        let topLeftX = dragPoint.x - CGFloat(p.cols) * cell / 2
        let topLeftY = dragPoint.y - lift - CGFloat(p.rows) * cell / 2
        let c = Int(((topLeftX - boardFrame.minX) / cell).rounded())
        let r = Int(((topLeftY - boardFrame.minY) / cell).rounded())
        return (r, c)
    }

    private func board(cell: CGFloat) -> some View {
        var ghost = Set<BBCell>()
        var ghostColor = 0
        var willClear = Set<Int>()
        if let i = dragIndex, i < game.tray.count, let p = game.tray[i] {
            let (r, c) = target(for: p, cell: cell)
            if game.canPlace(p, at: r, c) {
                ghost = Set(p.cells.map { BBCell(r: r + $0.r, c: c + $0.c) })
                ghostColor = p.color
                for row in 0..<game.n where (0..<game.n).allSatisfy({ game.grid[row][$0] != nil || ghost.contains(BBCell(r: row, c: $0)) }) {
                    willClear.insert(row)
                }
                for col in 0..<game.n where (0..<game.n).allSatisfy({ game.grid[$0][col] != nil || ghost.contains(BBCell(r: $0, c: col)) }) {
                    willClear.insert(100 + col)
                }
            }
        }
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.35))
            ForEach(0..<(game.n * game.n), id: \.self) { k in
                gridCell(r: k / game.n, c: k % game.n, cell: cell, ghost: ghost, ghostColor: ghostColor, willClear: willClear)
            }
            // Cleared cells flash white and burst outward.
            ForEach(Array(game.burst.keys), id: \.self) { b in
                RoundedRectangle(cornerRadius: cell * 0.2)
                    .fill(Color.white)
                    .frame(width: cell, height: cell)
                    .scaleEffect(burstVisible ? 1 : 1.6)
                    .opacity(burstVisible ? 0.9 : 0)
                    .offset(x: CGFloat(b.c) * cell, y: CGFloat(b.r) * cell)
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private func gridCell(r: Int, c: Int, cell: CGFloat, ghost: Set<BBCell>, ghostColor: Int, willClear: Set<Int>) -> some View {
        let lit = willClear.contains(r) || willClear.contains(100 + c)
        Group {
            if let color = game.grid[r][c] {
                blockTile(BBShapes.colors[color], size: cell, glow: lit)
            } else if ghost.contains(BBCell(r: r, c: c)) {
                blockTile(BBShapes.colors[ghostColor], size: cell, glow: lit).opacity(0.45)
            } else {
                RoundedRectangle(cornerRadius: cell * 0.18)
                    .fill(Color.white.opacity(0.05))
                    .padding(1.5)
            }
        }
        .frame(width: cell, height: cell)
        .offset(x: CGFloat(c) * cell, y: CGFloat(r) * cell)
    }

    private func blockTile(_ color: Color, size: CGFloat, glow: Bool) -> some View {
        RoundedRectangle(cornerRadius: size * 0.2)
            .fill(LinearGradient(colors: [color.opacity(0.95), color], startPoint: .top, endPoint: .bottom))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.2)
                    .strokeBorder(Color.white.opacity(glow ? 0.9 : 0.35), lineWidth: glow ? 3 : 1.5)
            )
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: size * 0.12)
                    .fill(Color.white.opacity(0.25))
                    .frame(height: size * 0.22)
                    .padding(size * 0.12)
            }
            .shadow(color: glow ? color : .clear, radius: glow ? 8 : 0)
            .padding(1.5)
    }

    private func pieceShape(_ p: BBPiece, cell: CGFloat, alpha: Double) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(p.cells, id: \.self) { c in
                blockTile(BBShapes.colors[p.color], size: cell, glow: false)
                    .frame(width: cell, height: cell)
                    .offset(x: CGFloat(c.c) * cell, y: CGFloat(c.r) * cell)
            }
        }
        .frame(width: CGFloat(p.cols) * cell, height: CGFloat(p.rows) * cell, alignment: .topLeading)
        .opacity(alpha)
    }

    private func tray(cell: CGFloat, width: CGFloat) -> some View {
        let small = cell * 0.55
        return HStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { i in
                ZStack {
                    if i < game.tray.count, let p = game.tray[i] {
                        pieceShape(p, cell: small, alpha: dragIndex == i ? 0.15 : 1)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: width / 3, height: small * 5 + 10)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("bb"))
                        .onChanged { v in
                            guard !game.over, i < game.tray.count, game.tray[i] != nil else { return }
                            if dragIndex == nil { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                            dragIndex = i
                            dragPoint = v.location
                        }
                        .onEnded { _ in
                            defer { dragIndex = nil }
                            guard let idx = dragIndex, idx < game.tray.count, let p = game.tray[idx] else { return }
                            let (r, c) = target(for: p, cell: cell)
                            withAnimation(.snappy(duration: 0.2)) { _ = game.place(idx, at: r, c) }
                        }
                )
            }
        }
        .frame(width: width)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: game.tray.map { $0?.id })
    }

    @ViewBuilder
    private var flashBanner: some View {
        if let f = game.flash {
            Text(f)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(Color.loz, in: Capsule())
                .shadow(color: Color.loz.opacity(0.6), radius: 12)
                .padding(.top, 70)
                .transition(.scale(scale: 0.5).combined(with: .opacity))
                .id(game.flashID)
                .task(id: game.flashID) {
                    try? await Task.sleep(nanoseconds: 900_000_000)
                    withAnimation(.easeOut) { game.flash = nil }
                }
                .allowsHitTesting(false)
        }
    }

    private var gameOverCard: some View {
        VStack(spacing: 14) {
            Text(game.newBest ? "YENİ REKOR!" : "Yer kalmadı")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(game.newBest ? .yellow : .white)
            Text("Skor: \(game.score) · Rekor: \(game.best)").foregroundStyle(.white.opacity(0.8))
            Button {
                withAnimation { game.reset() }
            } label: {
                Text("Tekrar oyna").font(.headline).frame(width: 200, height: 50)
                    .background(Color.loz, in: Capsule()).foregroundStyle(.white)
            }
        }
        .padding(28)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .transition(.scale.combined(with: .opacity))
    }
}
