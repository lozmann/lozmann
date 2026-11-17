import SwiftUI
import Observation
import UIKit

// MARK: - Match session

struct CarEvent: Identifiable {
    enum Kind { case usGoal, myGoal, myAssist, themGoal, chance, info }
    let id = UUID()
    let minute: Int
    let text: String
    let kind: Kind
}

enum ShotOutcome {
    case goal, saved, missed, blocked, overBar, assist, passFailed
}

@Observable
final class MatchSession {
    let fixture: CarFixture
    let attrs: CarAttributes
    let energy: Double
    let opponentRating: Int

    var minute = 0
    var us = 0
    var them = 0
    var myGoals = 0
    var myAssists = 0
    var chancesMissed = 0
    var events: [CarEvent] = []
    var inChance = false
    var finished = false
    var started = false
    var speed = 1.0

    private var chanceMinutes: [Int] = []
    private var mateGoals: [Int] = []
    private var oppGoals: [Int] = []

    static let mates = ["Okafor", "Lindqvist", "Ramírez", "Thompson", "Diallo", "Costa", "Hayes"]

    init(fixture: CarFixture, attrs: CarAttributes, energy: Double) {
        self.fixture = fixture
        self.attrs = attrs
        self.energy = energy
        self.opponentRating = CarTeams.rating(fixture.opponent)
        let ours = CarTeams.rating(CarTeams.me)
        let mates = CarSim.goals(ours, vs: opponentRating, home: fixture.home, factor: 0.55)
        let opp = CarSim.goals(opponentRating, vs: ours, home: !fixture.home)
        var count = 2 + Int.random(in: 0...2) + (energy > 70 ? 1 : 0)
        if energy < 35 { count -= 1 }
        chanceMinutes = Self.minutes(max(1, count))
        mateGoals = Self.minutes(mates).filter { !chanceMinutes.contains($0) }
        oppGoals = Self.minutes(opp)
    }

    private static func minutes(_ n: Int) -> [Int] {
        var set = Set<Int>()
        while set.count < n { set.insert(Int.random(in: 3...89)) }
        return set.sorted()
    }

    var homeName: String { fixture.home ? CarTeams.me : fixture.opponent }
    var awayName: String { fixture.home ? fixture.opponent : CarTeams.me }
    var homeScore: Int { fixture.home ? us : them }
    var awayScore: Int { fixture.home ? them : us }

    func start() {
        started = true
        events.insert(CarEvent(minute: 0, text: "Maç başladı. \(CareerHistory.shortName) 10 numarayla sahada.", kind: .info), at: 0)
    }

    func tick() {
        guard started, !inChance, !finished else { return }
        minute += 1
        if mateGoals.contains(minute) {
            us += 1
            let scorer = Self.mates.randomElement() ?? "Okafor"
            events.insert(CarEvent(minute: minute, text: "GOL! \(scorer) ağları buldu.", kind: .usGoal), at: 0)
            Sfx.play("correct")
        }
        if oppGoals.contains(minute) {
            them += 1
            events.insert(CarEvent(minute: minute, text: "\(fixture.opponent) golü.", kind: .themGoal), at: 0)
            Sfx.play("wrong")
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        if chanceMinutes.contains(minute) {
            inChance = true
            events.insert(CarEvent(minute: minute, text: "Pozisyon! Top \(CareerHistory.shortName)'de…", kind: .chance), at: 0)
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
        if minute == 45 {
            events.insert(CarEvent(minute: 45, text: "İlk yarı sona erdi: \(homeScore)-\(awayScore)", kind: .info), at: 0)
        }
        if minute >= 90 {
            finished = true
            events.insert(CarEvent(minute: 90, text: "Maç bitti: \(homeName) \(homeScore)-\(awayScore) \(awayName)", kind: .info), at: 0)
        }
    }

    func resolve(_ outcome: ShotOutcome, mate: String) {
        switch outcome {
        case .goal:
            us += 1
            myGoals += 1
            let text = myGoals == 3 ? "HAT-TRICK! \(CareerHistory.shortName) üçüncü golünü attı!" : "GOOOL! \(CareerHistory.shortName) ağları sarstı!"
            events.insert(CarEvent(minute: minute, text: text, kind: .myGoal), at: 0)
        case .assist:
            us += 1
            myAssists += 1
            events.insert(CarEvent(minute: minute, text: "GOL! \(mate) attı, asist \(CareerHistory.shortName)'den.", kind: .myAssist), at: 0)
        case .saved:
            chancesMissed += 1
            events.insert(CarEvent(minute: minute, text: "\(fixture.opponent) kalecisi kurtardı.", kind: .info), at: 0)
        case .missed, .overBar:
            chancesMissed += 1
            events.insert(CarEvent(minute: minute, text: "Şut az farkla dışarıda.", kind: .info), at: 0)
        case .blocked:
            chancesMissed += 1
            events.insert(CarEvent(minute: minute, text: "Şut savunmaya çarptı.", kind: .info), at: 0)
        case .passFailed:
            events.insert(CarEvent(minute: minute, text: "Pas kesildi.", kind: .info), at: 0)
        }
        inChance = false
    }

    var matchRating: Double {
        var r = 6.2 + Double(myGoals) * 1.1 + Double(myAssists) * 0.7 - Double(chancesMissed) * 0.15
        if us > them { r += 0.4 } else if us < them { r -= 0.3 }
        r += Double.random(in: -0.2...0.2)
        return (min(10, max(4, r)) * 10).rounded() / 10
    }
}

// MARK: - Match screen

struct MatchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CareerStore.self) private var career
    @State private var session: MatchSession
    @State private var finalRating: Double?
    @State private var confetti = 0
    @State private var saved = false
    @State private var mate = MatchSession.mates.randomElement() ?? "Okafor"

    init(fixture: CarFixture, attrs: CarAttributes, energy: Double) {
        _session = State(initialValue: MatchSession(fixture: fixture, attrs: attrs, energy: energy))
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.25, blue: 0.12), Color(red: 0.02, green: 0.10, blue: 0.06)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                scoreboard
                feed
                controls
            }
            .padding()

            if session.inChance {
                ShotGameView(attrs: session.attrs, energy: session.energy, keeper: session.opponentRating, mate: mate) { outcome in
                    session.resolve(outcome, mate: mate)
                    if outcome == .goal || outcome == .assist { confetti += 1 }
                    mate = MatchSession.mates.randomElement() ?? "Okafor"
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(2)
            }
            if session.finished { summary.transition(.scale.combined(with: .opacity)).zIndex(3) }
            ConfettiView(trigger: confetti).allowsHitTesting(false).zIndex(4)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: session.inChance)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: session.finished)
        .task(id: session.started) {
            guard session.started else { return }
            while !session.finished && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(120_000_000 / session.speed))
                session.tick()
            }
        }
        .preferredColorScheme(.dark)
    }

    private var scoreboard: some View {
        VStack(spacing: 6) {
            Text("\(session.fixture.compName) · \(session.fixture.round)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
            HStack {
                Text(session.homeName)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .foregroundStyle(session.fixture.home ? Color.red : .white)
                Text("\(session.homeScore) - \(session.awayScore)")
                    .font(.system(size: 34, weight: .black, design: .rounded).monospacedDigit())
                    .padding(.horizontal, 12)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: session.us + session.them)
                Text(session.awayName)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(session.fixture.home ? .white : Color.red)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            HStack(spacing: 12) {
                Text("\(session.minute)'")
                    .font(.headline.monospacedDigit())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.35), in: Capsule())
                Label("\(session.myGoals)", systemImage: "soccerball")
                Label("\(session.myAssists)", systemImage: "arrow.turn.up.right")
            }
            .font(.subheadline)
            ProgressView(value: Double(session.minute), total: 90).tint(.green)
        }
        .foregroundStyle(.white)
        .padding()
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 18))
    }

    private var feed: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                if session.events.isEmpty {
                    Text("Takımlar sahada. Hazır olduğunda maçı başlat.")
                        .foregroundStyle(.white.opacity(0.7))
                }
                ForEach(session.events) { e in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(e.minute)'")
                            .font(.caption.monospacedDigit().weight(.bold))
                            .frame(width: 30, alignment: .trailing)
                            .foregroundStyle(.white.opacity(0.6))
                        Text(e.text)
                            .font(e.kind == .myGoal || e.kind == .myAssist ? .body.weight(.heavy) : .body)
                            .foregroundStyle(color(e.kind))
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: session.events.count)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 18))
    }

    private func color(_ k: CarEvent.Kind) -> Color {
        switch k {
        case .myGoal, .myAssist: return .yellow
        case .usGoal: return .green
        case .themGoal: return .red
        case .chance: return .orange
        case .info: return .white.opacity(0.85)
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            if !session.started {
                Button {
                    session.start()
                    Sfx.play("pop")
                } label: {
                    Text("MAÇI BAŞLAT").font(.headline.weight(.heavy)).frame(maxWidth: .infinity, minHeight: 54)
                        .background(Color.loz, in: Capsule()).foregroundStyle(.white)
                }
                Button("Çık") { dismiss() }.foregroundStyle(.white.opacity(0.7))
            } else {
                Picker("Hız", selection: $session.speed) {
                    Text("1x").tag(1.0)
                    Text("2x").tag(2.0)
                    Text("4x").tag(4.0)
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var summary: some View {
        let won = session.us > session.them
        let draw = session.us == session.them
        let rating = finalRating ?? 0
        return VStack(spacing: 14) {
            Text(won ? "GALİBİYET" : (draw ? "BERABERLİK" : "MAĞLUBİYET"))
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(won ? Color.green : (draw ? .white : .red))
            Text("\(session.homeName) \(session.homeScore) - \(session.awayScore) \(session.awayName)")
                .font(.headline)
            HStack(spacing: 22) {
                stat("Gol", "\(session.myGoals)")
                stat("Asist", "\(session.myAssists)")
                stat("Puan", String(format: "%.1f", rating))
            }
            if rating >= 8.5 {
                Label("Maçın oyuncusu", systemImage: "star.fill").foregroundStyle(.yellow).font(.headline)
            }
            Button {
                guard !saved else { return }
                saved = true
                career.finish(session.fixture.id, goalsFor: session.us, goalsAgainst: session.them,
                              myGoals: session.myGoals, myAssists: session.myAssists, rating: rating)
                dismiss()
            } label: {
                Text("Devam").font(.headline).frame(width: 220, height: 50)
                    .background(Color.loz, in: Capsule()).foregroundStyle(.white)
            }
        }
        .foregroundStyle(.white)
        .padding(28)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26))
        .onAppear {
            if finalRating == nil {
                finalRating = session.matchRating
                if won {
                    Sfx.play("levelup")
                    confetti += 1
                } else {
                    Sfx.play(draw ? "pop" : "wrong")
                }
                UINotificationFeedbackGenerator().notificationOccurred(won ? .success : .warning)
            }
        }
    }

    private func stat(_ t: String, _ v: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.title.weight(.heavy).monospacedDigit())
            Text(t).font(.caption).foregroundStyle(.white.opacity(0.7))
        }
    }
}

// MARK: - Shot mini-game

/// One chance in a match: swipe toward the goal to shoot, or pass to a team-mate.
struct ShotGameView: View {
    let attrs: CarAttributes
    let energy: Double
    let keeper: Int
    let mate: String
    let onDone: (ShotOutcome) -> Void

    @State private var size: CGSize = .zero
    @State private var ball: CGPoint = .zero
    @State private var mateSpot: CGPoint = .zero
    @State private var defenders: [CGPoint] = []
    @State private var aim: CGSize = .zero
    @State private var aiming = false
    @State private var shotKeeperX: CGFloat?
    @State private var result: ShotOutcome?
    @State private var busy = false
    @State private var start = Date()

    private var goalW: CGFloat { size.width * 0.40 }
    private var goalY: CGFloat { size.height * 0.12 }
    private var cx: CGFloat { size.width / 2 }

    var body: some View {
        VStack(spacing: 12) {
            Text(result.map(resultText) ?? "POZİSYON!")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(result == .goal || result == .assist ? Color.yellow : .white)
                .contentTransition(.opacity)
            GeometryReader { geo in
                TimelineView(.animation) { tl in
                    let kx = keeperX(at: tl.date)
                    ZStack {
                        pitch
                        // keeper
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.yellow)
                            .frame(width: 34, height: 14)
                            .overlay(Circle().fill(Color(red: 0.95, green: 0.8, blue: 0.6)).frame(width: 12, height: 12))
                            .position(x: kx, y: goalY + 6)
                        // defenders
                        ForEach(Array(defenders.enumerated()), id: \.offset) { _, d in
                            player(color: .white, at: d)
                        }
                        // team-mate
                        player(color: .red, at: mateSpot)
                            .overlay(alignment: .top) {
                                Text(mate).font(.caption2.weight(.bold)).foregroundStyle(.white)
                                    .position(x: mateSpot.x, y: mateSpot.y - 22)
                            }
                        // me
                        player(color: Color.red, at: CGPoint(x: ball.x - 12, y: ball.y + 14), ring: true)
                        // aim line
                        if aiming && result == nil {
                            Path { p in
                                p.move(to: ball)
                                p.addLine(to: CGPoint(x: ball.x + aim.width * 1.6, y: ball.y + aim.height * 1.6))
                            }
                            .stroke(Color.white.opacity(0.8), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [6, 6]))
                        }
                        // ball
                        Circle()
                            .fill(RadialGradient(colors: [.white, Color(white: 0.8)], center: .init(x: 0.35, y: 0.3), startRadius: 1, endRadius: 10))
                            .frame(width: 16, height: 16)
                            .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
                            .position(ball)
                    }
                }
                .onAppear { setup(geo.size) }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 6)
                        .onChanged { v in
                            guard !busy, result == nil else { return }
                            aiming = true
                            aim = v.translation
                        }
                        .onEnded { v in
                            guard !busy, result == nil else { return }
                            aiming = false
                            shoot(v.translation, velocity: v.velocity)
                        }
                )
            }
            .aspectRatio(0.85, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 18))

            if result == nil {
                Text("Kaleye doğru kaydır. Hızlı kaydırma sert şut demek, köşelere çek.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                Button {
                    pass()
                } label: {
                    Label("\(mate)'a pas ver", systemImage: "arrow.turn.up.right")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(.white.opacity(0.15), in: Capsule())
                        .foregroundStyle(.white)
                }
                .disabled(busy)
            }
        }
        .padding()
        .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 26))
        .padding()
    }

    private var pitch: some View {
        ZStack {
            Rectangle().fill(
                LinearGradient(colors: [Color(red: 0.16, green: 0.55, blue: 0.24), Color(red: 0.12, green: 0.45, blue: 0.20)],
                               startPoint: .top, endPoint: .bottom)
            )
            // mowing stripes
            VStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { i in
                    Rectangle().fill(Color.white.opacity(i % 2 == 0 ? 0.04 : 0))
                }
            }
            // penalty box and six-yard box
            Path { p in
                p.addRect(CGRect(x: cx - size.width * 0.38, y: goalY, width: size.width * 0.76, height: size.height * 0.42))
                p.addRect(CGRect(x: cx - size.width * 0.2, y: goalY, width: size.width * 0.4, height: size.height * 0.14))
                p.addEllipse(in: CGRect(x: cx - 3, y: goalY + size.height * 0.3 - 3, width: 6, height: 6))
                p.move(to: CGPoint(x: 0, y: goalY))
                p.addLine(to: CGPoint(x: size.width, y: goalY))
            }
            .stroke(Color.white.opacity(0.7), lineWidth: 2)
            // goal
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: goalW, height: goalY - 6)
                .overlay(
                    Path { p in
                        var x: CGFloat = 0
                        while x <= goalW { p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: goalY)); x += 8 }
                    }
                    .stroke(Color.white.opacity(0.25), lineWidth: 0.6)
                )
                .overlay(Rectangle().stroke(Color.white, lineWidth: 4))
                .position(x: cx, y: (goalY - 6) / 2 + 3)
        }
    }

    private func player(color: Color, at p: CGPoint, ring: Bool = false) -> some View {
        Circle()
            .fill(color)
            .frame(width: 20, height: 20)
            .overlay(Circle().stroke(Color.white, lineWidth: ring ? 2.5 : 1))
            .shadow(color: .black.opacity(0.35), radius: 2, y: 2)
            .position(p)
    }

    private func setup(_ s: CGSize) {
        size = s
        start = Date()
        ball = CGPoint(x: s.width * CGFloat.random(in: 0.28...0.72), y: s.height * CGFloat.random(in: 0.56...0.78))
        let toGoal = CGPoint(x: s.width / 2 - ball.x, y: s.height * 0.12 - ball.y)
        let count = keeper >= 84 ? 2 : Int.random(in: 1...2)
        defenders = (0..<count).map { _ in
            let t = CGFloat.random(in: 0.3...0.6)
            let side = CGFloat.random(in: -45...45)
            return CGPoint(x: ball.x + toGoal.x * t + side, y: ball.y + toGoal.y * t)
        }
        mateSpot = CGPoint(x: ball.x < s.width / 2 ? s.width * CGFloat.random(in: 0.62...0.8) : s.width * CGFloat.random(in: 0.2...0.38),
                           y: s.height * CGFloat.random(in: 0.28...0.4))
    }

    private func keeperX(at t: Date) -> CGFloat {
        if let x = shotKeeperX { return x }
        let elapsed = t.timeIntervalSince(start)
        return cx + CGFloat(sin(elapsed * 2.1)) * goalW * 0.3
    }

    private func distanceToSegment(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let len2 = dx * dx + dy * dy
        guard len2 > 0 else { return hypot(p.x - a.x, p.y - a.y) }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2))
        return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
    }

    private func shoot(_ drag: CGSize, velocity: CGSize) {
        busy = true
        let len = hypot(drag.width, drag.height)
        let speed = hypot(velocity.width, velocity.height)
        let power = min(1, Double(len) / 320 * 0.4 + Double(speed) / 2600 * 0.6)
        let kx = keeperX(at: Date())

        // Wrong direction or a feeble poke.
        guard drag.height < -10 else { finishShot(.missed, target: CGPoint(x: ball.x + drag.width, y: ball.y + drag.height), duration: 0.4, keeperTo: kx); return }

        let k = (goalY - ball.y) / drag.height
        var tx = ball.x + drag.width * k
        let accuracy = attrs.sho / 100 * (0.65 + 0.35 * energy / 100)
        tx += CGFloat(Double.random(in: -1...1) * (1 - accuracy) * Double(goalW) * 0.35)
        if power > 0.85 { tx += CGFloat(Double.random(in: -1...1) * (power - 0.85) * Double(goalW)) }
        let target = CGPoint(x: tx, y: goalY)
        let duration = 0.22 + (1 - power) * 0.45 + Double(hypot(target.x - ball.x, target.y - ball.y)) / 1600

        if power > 0.9, Double.random(in: 0...1) < (power - 0.9) * 5 * (1.15 - accuracy) {
            finishShot(.overBar, target: CGPoint(x: tx, y: -30), duration: duration, keeperTo: kx)
            return
        }
        if abs(tx - cx) > goalW / 2 - 6 {
            finishShot(.missed, target: CGPoint(x: tx + (tx - cx) * 0.1, y: goalY - 20), duration: duration, keeperTo: kx)
            return
        }
        for d in defenders where distanceToSegment(d, ball, target) < 17 {
            finishShot(.blocked, target: d, duration: duration * 0.5, keeperTo: kx)
            return
        }
        let reaction = 0.13 + Double(90 - keeper) * 0.006
        let diveSpeed = Double(goalW) * 0.95 * Double(keeper) / 85
        let reach = 18 + CGFloat(diveSpeed * max(0, duration - reaction))
        let gap = abs(tx - kx)
        if power < 0.28 || gap <= reach {
            finishShot(.saved, target: CGPoint(x: tx, y: goalY + 4), duration: duration, keeperTo: tx)
        } else {
            let lean = kx + (tx > kx ? 1 : -1) * reach
            finishShot(.goal, target: CGPoint(x: tx, y: goalY - 14), duration: duration, keeperTo: lean)
        }
    }

    private func finishShot(_ outcome: ShotOutcome, target: CGPoint, duration: Double, keeperTo: CGFloat) {
        shotKeeperX = keeperX(at: Date())
        withAnimation(.easeOut(duration: duration)) {
            ball = target
            shotKeeperX = min(cx + goalW / 2, max(cx - goalW / 2, keeperTo))
        }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.05) {
            withAnimation(.snappy) { result = outcome }
            switch outcome {
            case .goal:
                Sfx.play("levelup")
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .saved, .blocked:
                Sfx.play("wrong")
            default:
                Sfx.play("pop")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { onDone(outcome) }
        }
    }

    private func pass() {
        busy = true
        let chance = 0.35 + attrs.pas / 100 * 0.45
        let ok = Double.random(in: 0...1) < chance
        withAnimation(.easeOut(duration: 0.35)) { ball = mateSpot }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if ok {
                let tx = cx + CGFloat.random(in: -goalW * 0.35...goalW * 0.35)
                finishPass(target: CGPoint(x: tx, y: goalY - 14))
            } else {
                withAnimation(.snappy) { result = .passFailed }
                Sfx.play("wrong")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { onDone(.passFailed) }
            }
        }
    }

    private func finishPass(target: CGPoint) {
        shotKeeperX = keeperX(at: Date())
        withAnimation(.easeOut(duration: 0.35)) { ball = target }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.snappy) { result = .assist }
            Sfx.play("combo")
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { onDone(.assist) }
        }
    }

    private func resultText(_ o: ShotOutcome) -> String {
        switch o {
        case .goal: return "GOOOL!"
        case .saved: return "Kaleci kurtardı"
        case .missed: return "Dışarıda!"
        case .overBar: return "Üstten auta"
        case .blocked: return "Savunmaya takıldı"
        case .assist: return "ASİST! \(mate) attı"
        case .passFailed: return "Pas kesildi"
        }
    }
}
