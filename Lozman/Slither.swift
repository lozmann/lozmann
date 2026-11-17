import SwiftUI
import SpriteKit
import Observation
import UIKit

// MARK: - HUD state shared with SwiftUI

struct Leader: Identifiable {
    let id: Int
    let name: String
    let length: Int
    let isPlayer: Bool
}

@Observable
final class SlitherHUD {
    enum Phase { case menu, playing, dead }
    var phase: Phase = .menu
    var length = 0
    var kills = 0
    var rank = 1
    var total = 1
    var leaders: [Leader] = []
    var best = UserDefaults.standard.integer(forKey: "slitherBest")
    var bestKills = UserDefaults.standard.integer(forKey: "slitherBestKills")
    var newBest = false
    var flash: String?
    var flashID = 0
    var confetti = 0
    var map = CGPoint(x: 0.5, y: 0.5)
    var canBoost = false

    func show(_ text: String) {
        flash = text
        flashID += 1
    }
}

// MARK: - Art (generated once, no image files needed)

enum SlitherArt {
    static let palette: [(UIColor, UIColor)] = [
        (UIColor(red: 0.98, green: 0.45, blue: 0.10, alpha: 1), UIColor(red: 1.00, green: 0.78, blue: 0.20, alpha: 1)), // player: orange / gold
        (UIColor(red: 0.20, green: 0.80, blue: 0.95, alpha: 1), UIColor(red: 0.10, green: 0.45, blue: 0.95, alpha: 1)),
        (UIColor(red: 0.55, green: 0.95, blue: 0.35, alpha: 1), UIColor(red: 0.15, green: 0.70, blue: 0.40, alpha: 1)),
        (UIColor(red: 0.95, green: 0.30, blue: 0.60, alpha: 1), UIColor(red: 0.65, green: 0.20, blue: 0.85, alpha: 1)),
        (UIColor(red: 1.00, green: 0.90, blue: 0.30, alpha: 1), UIColor(red: 0.95, green: 0.55, blue: 0.15, alpha: 1)),
        (UIColor(red: 0.70, green: 0.55, blue: 1.00, alpha: 1), UIColor(red: 0.95, green: 0.95, blue: 1.00, alpha: 1)),
        (UIColor(red: 1.00, green: 0.35, blue: 0.30, alpha: 1), UIColor(red: 0.20, green: 0.20, blue: 0.25, alpha: 1)),
        (UIColor(red: 0.30, green: 0.95, blue: 0.75, alpha: 1), UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1))
    ]

    static let orbColors: [UIColor] = [
        UIColor(red: 1.0, green: 0.45, blue: 0.15, alpha: 1), UIColor(red: 1.0, green: 0.85, blue: 0.25, alpha: 1),
        UIColor(red: 0.35, green: 0.95, blue: 0.45, alpha: 1), UIColor(red: 0.25, green: 0.80, blue: 1.0, alpha: 1),
        UIColor(red: 0.85, green: 0.40, blue: 1.0, alpha: 1), UIColor(red: 1.0, green: 0.35, blue: 0.55, alpha: 1)
    ]

    /// The visible ball covers this share of the segment texture; the rest is glow.
    static let ballShare: CGFloat = 0.36

    static func shade(_ c: UIColor, _ amount: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return UIColor(hue: h, saturation: max(0, min(1, s - amount * 0.3)), brightness: max(0, min(1, b + amount)), alpha: a)
    }

    static func segment(_ color: UIColor) -> SKTexture {
        let size: CGFloat = 128
        let img = UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { ctx in
            let c = ctx.cgContext
            let space = CGColorSpaceCreateDeviceRGB()
            let center = CGPoint(x: size / 2, y: size / 2)
            // soft outer glow
            if let glow = CGGradient(colorsSpace: space, colors: [color.withAlphaComponent(0.45).cgColor, color.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 1]) {
                c.drawRadialGradient(glow, startCenter: center, startRadius: size * ballShare * 0.9, endCenter: center, endRadius: size / 2, options: [])
            }
            // shaded ball
            let r = size * ballShare
            c.addEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
            c.clip()
            if let ball = CGGradient(colorsSpace: space, colors: [shade(color, 0.35).cgColor, color.cgColor, shade(color, -0.35).cgColor] as CFArray, locations: [0, 0.55, 1]) {
                let light = CGPoint(x: center.x - r * 0.35, y: center.y - r * 0.4)
                c.drawRadialGradient(ball, startCenter: light, startRadius: 0, endCenter: center, endRadius: r, options: [.drawsAfterEndLocation])
            }
        }
        return SKTexture(image: img)
    }

    static func orb(_ color: UIColor) -> SKTexture {
        let size: CGFloat = 64
        let img = UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { ctx in
            let c = ctx.cgContext
            let center = CGPoint(x: size / 2, y: size / 2)
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [UIColor.white.cgColor, color.cgColor, color.withAlphaComponent(0.35).cgColor, color.withAlphaComponent(0).cgColor] as CFArray,
                                  locations: [0, 0.18, 0.45, 1]) {
                c.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: size / 2, options: [])
            }
        }
        return SKTexture(image: img)
    }

    static func floorTile() -> SKTexture {
        let size: CGFloat = 256
        let img = UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { ctx in
            let c = ctx.cgContext
            UIColor(red: 0.075, green: 0.085, blue: 0.12, alpha: 1).setFill()
            c.fill(CGRect(x: 0, y: 0, width: size, height: size))
            // honeycomb of soft scales; 8x8 cells so the tile repeats seamlessly
            let step = size / 8
            for row in 0..<9 {
                for col in -1..<9 {
                    let x = CGFloat(col) * step + (row % 2 == 0 ? 0 : step / 2) + step / 2
                    let y = CGFloat(row) * step
                    let rect = CGRect(x: x - step * 0.42, y: y - step * 0.42, width: step * 0.84, height: step * 0.84)
                    UIColor(white: 1, alpha: 0.035).setFill()
                    c.fillEllipse(in: rect)
                    UIColor(white: 1, alpha: 0.05).setStroke()
                    c.setLineWidth(1)
                    c.strokeEllipse(in: rect)
                }
            }
        }
        return SKTexture(image: img)
    }

    static func spark() -> SKTexture { orb(.white) }
}

// MARK: - Entities

final class Orb: SKSpriteNode {
    var value: CGFloat = 1
    var ownerID = -1
    var born: TimeInterval = 0
    var eaten = false
}

final class Snake {
    let id: Int
    let name: String
    let isPlayer: Bool
    let colorIndex: Int
    let node = SKNode()
    let eyes = SKNode()
    var path: [CGPoint] = []
    var positions: [CGPoint] = []
    var segments: [SKSpriteNode] = []
    var angle: CGFloat
    var targetAngle: CGFloat
    var mass: CGFloat
    var boosting = false
    var alive = true
    var kills = 0
    var dropTimer: TimeInterval = 0
    let texA: SKTexture
    let texB: SKTexture
    // AI
    var thinkTimer: TimeInterval = 0
    var wanderUntil: TimeInterval = 0
    var wanderAngle: CGFloat = 0
    var aggression: CGFloat = .random(in: 0.2...0.8)

    init(id: Int, name: String, isPlayer: Bool, colorIndex: Int, at start: CGPoint, angle: CGFloat, mass: CGFloat) {
        self.id = id
        self.name = name
        self.isPlayer = isPlayer
        self.colorIndex = colorIndex
        self.angle = angle
        self.targetAngle = angle
        self.mass = mass
        let colors = SlitherArt.palette[colorIndex % SlitherArt.palette.count]
        texA = SlitherArt.segment(colors.0)
        texB = SlitherArt.segment(colors.1)
        node.zPosition = isPlayer ? 500 : CGFloat(id)
        // Lay out a straight starting body behind the head.
        let back = CGVector(dx: -cos(angle), dy: -sin(angle))
        let needed = CGFloat(segmentCount) * spacing + 20
        var d: CGFloat = needed
        while d >= 0 {
            path.append(CGPoint(x: start.x + back.dx * d, y: start.y + back.dy * d))
            d -= 3
        }
        buildEyes()
        layout()
    }

    var radius: CGFloat { 10 + min(18, sqrt(max(0, mass - 10)) * 1.6) }
    var spacing: CGFloat { radius * 0.5 }
    var segmentCount: Int { max(8, Int(mass)) }
    var head: CGPoint { path.last ?? .zero }
    var speed: CGFloat { boosting ? 330 : 165 }
    var turnRate: CGFloat { max(2.6, 5.6 - radius * 0.11) }
    var bodyReach: CGFloat { CGFloat(segmentCount) * spacing + radius * 2 }

    private func buildEyes() {
        for side in [-1.0, 1.0] {
            let white = SKShapeNode(circleOfRadius: 1)
            white.fillColor = .white
            white.strokeColor = .clear
            white.name = side < 0 ? "eyeL" : "eyeR"
            let pupil = SKShapeNode(circleOfRadius: 0.55)
            pupil.fillColor = UIColor(white: 0.08, alpha: 1)
            pupil.strokeColor = .clear
            pupil.position = CGPoint(x: 0.3, y: 0)
            white.addChild(pupil)
            eyes.addChild(white)
        }
        eyes.zPosition = 2
        node.addChild(eyes)
    }

    func steer(_ dt: CGFloat) {
        var d = targetAngle - angle
        while d > .pi { d -= 2 * .pi }
        while d < -.pi { d += 2 * .pi }
        let step = turnRate * dt
        angle += max(-step, min(step, d))
    }

    func move(_ dt: CGFloat) {
        let h = head
        path.append(CGPoint(x: h.x + cos(angle) * speed * dt, y: h.y + sin(angle) * speed * dt))
        // Keep only as much trail as the body needs.
        let need = bodyReach + 30
        var acc: CGFloat = 0
        var i = path.count - 1
        while i > 0 && acc < need {
            acc += hypot(path[i].x - path[i - 1].x, path[i].y - path[i - 1].y)
            i -= 1
        }
        if i > 0 { path.removeFirst(i) }
    }

    func layout() {
        let count = segmentCount
        let gap = spacing
        positions.removeAll(keepingCapacity: true)
        guard var i = path.indices.last else { return }
        positions.append(path[i])
        var target = gap
        var acc: CGFloat = 0
        while positions.count < count && i > 0 {
            let a = path[i], b = path[i - 1]
            let d = hypot(a.x - b.x, a.y - b.y)
            if d > 0 {
                while acc + d >= target && positions.count < count {
                    let t = (target - acc) / d
                    positions.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
                    target += gap
                }
            }
            acc += d
            i -= 1
        }
        while positions.count < count { positions.append(positions.last ?? head) }

        // Sync sprites.
        while segments.count < count {
            let s = SKSpriteNode(texture: (segments.count / 3) % 2 == 0 ? texA : texB)
            s.zPosition = -CGFloat(segments.count) * 0.001
            node.addChild(s)
            segments.append(s)
        }
        while segments.count > count { segments.removeLast().removeFromParent() }

        let size = radius * 2 / (SlitherArt.ballShare * 2)
        let spriteSize = CGSize(width: size, height: size)
        for (k, s) in segments.enumerated() {
            s.position = positions[k]
            if s.size != spriteSize { s.size = spriteSize }
        }
        // Brighter head while boosting.
        segments.first?.colorBlendFactor = 0
        segments.first?.alpha = 1

        // Eyes look where the snake is heading.
        eyes.position = head
        eyes.zRotation = angle
        let r = radius
        for child in eyes.children {
            let side: CGFloat = child.name == "eyeL" ? -1 : 1
            child.position = CGPoint(x: r * 0.35, y: side * r * 0.42)
            child.setScale(r * 0.36)
        }
    }
}

// MARK: - Scene

final class SlitherScene: SKScene {
    let hud: SlitherHUD
    let worldRadius: CGFloat = 2300
    let botCount = 9
    let orbTarget = 420

    private var snakes: [Snake] = []
    private var player: Snake?
    private var orbs: [Orb] = []
    private var orbTextures: [SKTexture] = []
    private let world = SKNode()
    private let orbLayer = SKNode()
    private let snakeLayer = SKNode()
    private let fxLayer = SKNode()
    private let cam = SKCameraNode()
    private var built = false
    private var lastTime: TimeInterval = 0
    private var now: TimeInterval = 0
    private var hudTimer: TimeInterval = 0
    private var popTimer: TimeInterval = 0
    private var nextID = 1
    private var steerTouches = Set<UITouch>()
    var boostHeld = false
    var useJoystick = true
    var joystickAngle: CGFloat?
    private var milestone = 0
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private let heavyHaptic = UIImpactFeedbackGenerator(style: .heavy)
    private var sparkTexture = SlitherArt.spark()

    private let botNames = ["Kartal", "Şimşek", "Kobra", "Rüzgar", "Yıldırım", "Pars", "Atmaca", "Tayfun", "Fırtına", "Boğa", "Kasırga", "Çakal", "Volkan", "Toprak"]

    init(hud: SlitherHUD) {
        self.hud = hud
        super.init(size: CGSize(width: 390, height: 844))
        scaleMode = .resizeFill
        backgroundColor = UIColor(red: 0.04, green: 0.045, blue: 0.065, alpha: 1)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not used") }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        guard !built else { return }
        built = true
        addChild(world)
        camera = cam
        addChild(cam)
        buildFloor()
        world.addChild(orbLayer)
        world.addChild(snakeLayer)
        world.addChild(fxLayer)
        orbLayer.zPosition = 1
        snakeLayer.zPosition = 2
        fxLayer.zPosition = 3
        orbTextures = SlitherArt.orbColors.map { SlitherArt.orb($0) }
        for _ in 0..<orbTarget { spawnOrb(at: randomPoint(margin: 60), value: CGFloat.random(in: 1...2.2)) }
        for _ in 0..<botCount { spawnBot(awayFrom: .zero) }
        cam.setScale(1.25)
    }

    // MARK: World

    private func buildFloor() {
        let tile = SlitherArt.floorTile()
        let size: CGFloat = 256
        let n = Int((worldRadius * 2 + 600) / size) + 1
        let origin = -CGFloat(n) * size / 2
        let floor = SKNode()
        floor.zPosition = 0
        for y in 0..<n {
            for x in 0..<n {
                let s = SKSpriteNode(texture: tile)
                s.size = CGSize(width: size + 0.5, height: size + 0.5)
                s.position = CGPoint(x: origin + CGFloat(x) * size + size / 2, y: origin + CGFloat(y) * size + size / 2)
                floor.addChild(s)
            }
        }
        world.addChild(floor)

        // Danger zone outside the arena, and a glowing border.
        let outside = SKShapeNode(circleOfRadius: worldRadius + 900)
        outside.lineWidth = 1800
        outside.strokeColor = UIColor(red: 0.35, green: 0.02, blue: 0.05, alpha: 0.55)
        outside.fillColor = .clear
        outside.zPosition = 0.5
        world.addChild(outside)
        let border = SKShapeNode(circleOfRadius: worldRadius)
        border.lineWidth = 10
        border.strokeColor = UIColor(red: 1, green: 0.25, blue: 0.3, alpha: 0.9)
        border.glowWidth = 14
        border.fillColor = .clear
        border.zPosition = 0.6
        world.addChild(border)
    }

    private func randomPoint(margin: CGFloat) -> CGPoint {
        let a = CGFloat.random(in: 0..<(2 * .pi))
        let r = sqrt(CGFloat.random(in: 0...1)) * (worldRadius - margin)
        return CGPoint(x: cos(a) * r, y: sin(a) * r)
    }

    private func spawnOrb(at p: CGPoint, value: CGFloat, color: Int? = nil, owner: Int = -1) {
        let tex = orbTextures[(color ?? Int.random(in: 0..<orbTextures.count)) % max(1, orbTextures.count)]
        let o = Orb(texture: tex)
        o.value = value
        o.ownerID = owner
        o.born = now
        let d = 14 + value * 7
        o.size = CGSize(width: d, height: d)
        o.position = p
        o.blendMode = .add
        let t = Double.random(in: 0.6...1.1)
        o.run(.repeatForever(.sequence([.scale(to: 1.18, duration: t), .scale(to: 0.85, duration: t)])))
        orbLayer.addChild(o)
        orbs.append(o)
    }

    private func spawnBot(awayFrom avoid: CGPoint) {
        var p = randomPoint(margin: 400)
        var tries = 0
        while hypot(p.x - avoid.x, p.y - avoid.y) < 700 && tries < 20 {
            p = randomPoint(margin: 400)
            tries += 1
        }
        let id = nextID
        nextID += 1
        let s = Snake(id: id, name: botNames[id % botNames.count], isPlayer: false,
                      colorIndex: 1 + (id % (SlitherArt.palette.count - 1)),
                      at: p, angle: .random(in: 0..<(2 * .pi)), mass: .random(in: 12...55))
        snakeLayer.addChild(s.node)
        snakes.append(s)
    }

    func startGame() {
        if let old = player, old.alive {
            old.node.removeFromParent()
            snakes.removeAll { $0 === old }
        }
        var p = randomPoint(margin: 900)
        var tries = 0
        while snakes.contains(where: { hypot($0.head.x - p.x, $0.head.y - p.y) < 500 }) && tries < 30 {
            p = randomPoint(margin: 900)
            tries += 1
        }
        let s = Snake(id: 0, name: "Sen", isPlayer: true, colorIndex: 0, at: p, angle: atan2(-p.y, -p.x), mass: 12)
        snakeLayer.addChild(s.node)
        snakes.append(s)
        player = s
        milestone = 0
        hud.kills = 0
        hud.newBest = false
        hud.phase = .playing
        cam.position = p
        lightHaptic.prepare()
        heavyHaptic.prepare()
    }

    // MARK: Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        steerTouches.formUnion(touches)
        steer(with: touches.first)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        steer(with: touches.first)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        steerTouches.subtract(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        steerTouches.subtract(touches)
    }

    private func steer(with touch: UITouch?) {
        guard !useJoystick, let touch, let view, let player, player.alive else { return }
        let p = touch.location(in: view)
        let dx = p.x - view.bounds.midX
        let dy = view.bounds.midY - p.y
        if hypot(dx, dy) > 8 { player.targetAngle = atan2(dy, dx) }
    }

    // MARK: Loop

    override func update(_ currentTime: TimeInterval) {
        if lastTime == 0 { lastTime = currentTime }
        let dt = CGFloat(min(1.0 / 30.0, max(0, currentTime - lastTime)))
        lastTime = currentTime
        now += Double(dt)

        for s in snakes where s.alive {
            if s.isPlayer {
                s.boosting = (boostHeld || (!useJoystick && steerTouches.count >= 2)) && s.mass > 12
                if useJoystick, let a = joystickAngle { s.targetAngle = a }
            } else {
                think(s, dt: Double(dt))
            }
            if s.boosting {
                s.mass -= 2.6 * dt
                s.dropTimer += Double(dt)
                if s.dropTimer > 0.14, let tail = s.positions.last {
                    s.dropTimer = 0
                    spawnOrb(at: tail, value: 0.8, color: s.colorIndex % SlitherArt.orbColors.count, owner: s.id)
                }
            }
            s.steer(dt)
            s.move(dt)
        }

        eat()
        collide()
        for s in snakes where s.alive { s.layout() }

        // Keep the arena stocked.
        if orbs.count < orbTarget {
            for _ in 0..<min(6, orbTarget - orbs.count) {
                spawnOrb(at: randomPoint(margin: 60), value: CGFloat.random(in: 1...2.2))
            }
        }

        updateCamera(dt)
        hudTimer += Double(dt)
        if hudTimer > 0.12 {
            hudTimer = 0
            publishHUD()
        }
    }

    private func think(_ s: Snake, dt: TimeInterval) {
        s.thinkTimer -= dt
        guard s.thinkTimer <= 0 else { return }
        s.thinkTimer = .random(in: 0.12...0.25)
        let h = s.head
        s.boosting = false

        // 1. Stay inside the arena.
        if hypot(h.x, h.y) > worldRadius - 260 {
            s.targetAngle = atan2(-h.y, -h.x) + .random(in: -0.4...0.4)
            return
        }

        // 2. Avoid bodies ahead.
        let look = s.radius * 2 + 70
        let ahead = CGPoint(x: h.x + cos(s.angle) * look, y: h.y + sin(s.angle) * look)
        for o in snakes where o.alive && o !== s {
            if hypot(o.head.x - h.x, o.head.y - h.y) > o.bodyReach + look + 40 { continue }
            for (k, p) in o.positions.enumerated() where k % 2 == 0 {
                let dx = p.x - ahead.x, dy = p.y - ahead.y
                let lim = o.radius + s.radius + 26
                if abs(dx) < lim && abs(dy) < lim && dx * dx + dy * dy < lim * lim {
                    let away = atan2(h.y - p.y, h.x - p.x)
                    s.targetAngle = away + .random(in: -0.3...0.3)
                    return
                }
            }
        }

        // 3. Hunt the player: cut in front of them.
        if let pl = player, pl.alive, s.mass > pl.mass * 0.7, CGFloat.random(in: 0...1) < s.aggression * 0.5 {
            let d = hypot(pl.head.x - h.x, pl.head.y - h.y)
            if d < 380 {
                let lead = CGPoint(x: pl.head.x + cos(pl.angle) * 140, y: pl.head.y + sin(pl.angle) * 140)
                s.targetAngle = atan2(lead.y - h.y, lead.x - h.x)
                s.boosting = s.mass > 20 && d < 260
                return
            }
        }

        // 4. Go for the best food nearby.
        var bestScore: CGFloat = 0
        var bestPoint: CGPoint?
        for o in orbs where !o.eaten {
            let dx = o.position.x - h.x, dy = o.position.y - h.y
            if abs(dx) > 420 || abs(dy) > 420 { continue }
            let d2 = dx * dx + dy * dy
            let score = o.value * 1000 / (d2 + 900)
            if score > bestScore {
                bestScore = score
                bestPoint = o.position
            }
        }
        if let p = bestPoint {
            s.targetAngle = atan2(p.y - h.y, p.x - h.x)
            return
        }

        // 5. Wander.
        if now > s.wanderUntil {
            s.wanderUntil = now + .random(in: 1.5...3.5)
            s.wanderAngle = s.angle + .random(in: -1.4...1.4)
        }
        s.targetAngle = s.wanderAngle
    }

    private func eat() {
        for s in snakes where s.alive {
            let h = s.head
            let reach = s.radius + (s.isPlayer ? 26 : 14)
            for o in orbs where !o.eaten {
                let dx = o.position.x - h.x, dy = o.position.y - h.y
                if abs(dx) > reach + 20 || abs(dy) > reach + 20 { continue }
                if o.ownerID == s.id && now - o.born < 1.0 { continue }
                let r = reach + o.size.width * 0.3
                if dx * dx + dy * dy < r * r {
                    o.eaten = true
                    s.mass += o.value * 0.55
                    o.removeAllActions()
                    o.run(.sequence([
                        .group([.move(to: h, duration: 0.09), .scale(to: 0.2, duration: 0.09), .fadeOut(withDuration: 0.09)]),
                        .removeFromParent()
                    ]))
                    if s.isPlayer {
                        if now - popTimer > 0.06 {
                            popTimer = now
                            Sfx.play("pop")
                        }
                        lightHaptic.impactOccurred(intensity: 0.5)
                    }
                }
            }
        }
        orbs.removeAll { $0.eaten }
    }

    private func collide() {
        var dead: [(Snake, Snake?)] = []
        for a in snakes where a.alive {
            let h = a.head
            if hypot(h.x, h.y) > worldRadius - a.radius * 0.5 {
                dead.append((a, nil))
                continue
            }
            var killed = false
            for b in snakes where b.alive && b !== a {
                if hypot(b.head.x - h.x, b.head.y - h.y) > b.bodyReach + a.radius + 20 { continue }
                let lim = (a.radius + b.radius) * 0.78
                for p in b.positions {
                    let dx = p.x - h.x, dy = p.y - h.y
                    if abs(dx) < lim && abs(dy) < lim && dx * dx + dy * dy < lim * lim {
                        dead.append((a, b))
                        killed = true
                        break
                    }
                }
                if killed { break }
            }
        }
        for (victim, killer) in dead where victim.alive {
            kill(victim, by: killer)
        }
    }

    private func kill(_ s: Snake, by killer: Snake?) {
        s.alive = false
        // Turn the body into a trail of glowing food.
        let pieces = stride(from: 0, to: s.positions.count, by: 2).map { s.positions[$0] }
        let each = max(1.2, min(6, s.mass * 0.9 / CGFloat(max(1, pieces.count))))
        for p in pieces {
            let j = CGPoint(x: p.x + .random(in: -s.radius...s.radius), y: p.y + .random(in: -s.radius...s.radius))
            spawnOrb(at: j, value: each, color: s.colorIndex % SlitherArt.orbColors.count)
        }
        burst(at: s.head, color: SlitherArt.palette[s.colorIndex % SlitherArt.palette.count].0, big: killer?.isPlayer == true || s.isPlayer)
        s.node.run(.sequence([.fadeOut(withDuration: 0.25), .removeFromParent()]))
        snakes.removeAll { $0 === s }

        if s.isPlayer {
            playerDied()
        } else {
            if let killer {
                killer.kills += 1
                if killer.isPlayer {
                    hud.kills = killer.kills
                    hud.show(killer.kills > 1 ? "\(s.name) düştü! · \(killer.kills) av" : "\(s.name) düştü!")
                    Sfx.play("kill")
                    heavyHaptic.impactOccurred()
                    if killer.kills % 3 == 0 {
                        hud.confetti += 1
                        Sfx.play("combo")
                    }
                }
            }
            let avoid = player?.head ?? .zero
            run(.sequence([.wait(forDuration: 1.8), .run { [weak self] in self?.spawnBot(awayFrom: avoid) }]))
        }
    }

    private func playerDied() {
        guard let p = player else { return }
        let length = Int(p.mass)
        hud.length = length
        hud.kills = p.kills
        if length > hud.best {
            hud.best = length
            hud.newBest = true
            UserDefaults.standard.set(length, forKey: "slitherBest")
            hud.confetti += 1
            Sfx.play("levelup")
        } else {
            Sfx.play("wrong")
        }
        if p.kills > hud.bestKills {
            hud.bestKills = p.kills
            UserDefaults.standard.set(p.kills, forKey: "slitherBestKills")
        }
        heavyHaptic.impactOccurred(intensity: 1)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        var shake: [SKAction] = []
        for i in 0..<8 {
            let strength: CGFloat = CGFloat(8 - i) / 8
            let dx: CGFloat = CGFloat.random(in: -14...14) * strength
            let dy: CGFloat = CGFloat.random(in: -14...14) * strength
            shake.append(SKAction.moveBy(x: dx, y: dy, duration: 0.03))
        }
        cam.run(SKAction.sequence(shake))
        player = nil
        hud.phase = .dead
    }

    private func burst(at p: CGPoint, color: UIColor, big: Bool) {
        let count = big ? 34 : 14
        for _ in 0..<count {
            let s = SKSpriteNode(texture: sparkTexture)
            s.color = color
            s.colorBlendFactor = 0.8
            s.blendMode = .add
            let d = CGFloat.random(in: 8...(big ? 22 : 14))
            s.size = CGSize(width: d, height: d)
            s.position = p
            fxLayer.addChild(s)
            let a = CGFloat.random(in: 0..<(2 * .pi))
            let dist = CGFloat.random(in: 40...(big ? 220 : 110))
            let t = Double.random(in: 0.35...0.7)
            let move = SKAction.moveBy(x: cos(a) * dist, y: sin(a) * dist, duration: t)
            move.timingMode = .easeOut
            s.run(.sequence([.group([move, .fadeOut(withDuration: t), .scale(to: 0.2, duration: t)]), .removeFromParent()]))
        }
    }

    private func updateCamera(_ dt: CGFloat) {
        let target: CGPoint
        let wantedScale: CGFloat
        if let p = player, p.alive {
            target = p.head
            wantedScale = 1.0 + min(0.9, (p.radius - 10) / 18 * 0.9)
        } else if let s = snakes.max(by: { $0.mass < $1.mass }) {
            target = s.head
            wantedScale = 1.35
        } else {
            target = .zero
            wantedScale = 1.35
        }
        let k = min(1, dt * 7)
        if cam.action(forKey: "shake") == nil && !cam.hasActions() {
            cam.position = CGPoint(x: cam.position.x + (target.x - cam.position.x) * k,
                                   y: cam.position.y + (target.y - cam.position.y) * k)
        }
        cam.setScale(cam.xScale + (wantedScale - cam.xScale) * min(1, dt * 2))
    }

    private func publishHUD() {
        let sorted = snakes.filter(\.alive).sorted { $0.mass > $1.mass }
        hud.leaders = sorted.prefix(5).map { Leader(id: $0.id, name: $0.name, length: Int($0.mass), isPlayer: $0.isPlayer) }
        hud.total = sorted.count
        if let p = player, p.alive {
            let length = Int(p.mass)
            hud.length = length
            hud.rank = (sorted.firstIndex { $0 === p } ?? 0) + 1
            hud.canBoost = p.mass > 12
            hud.map = CGPoint(x: 0.5 + p.head.x / (worldRadius * 2), y: 0.5 - p.head.y / (worldRadius * 2))
            if length / 50 > milestone {
                milestone = length / 50
                hud.show("Uzunluk \(milestone * 50)!")
                Sfx.play("combo")
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }
}

// MARK: - SwiftUI screen

struct SlitherView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var hud = SlitherHUD()
    @State private var scene: SlitherScene?
    @AppStorage("slitherControl") private var control = "joystick"

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let scene {
                SpriteView(scene: scene, preferredFramesPerSecond: 120, options: [.ignoresSiblingOrder, .shouldCullNonVisibleNodes])
                    .ignoresSafeArea()
            }
            if hud.phase == .playing { playingHUD }
            if hud.phase == .menu { menu }
            if hud.phase == .dead { gameOver }
            ConfettiView(trigger: hud.confetti).allowsHitTesting(false).ignoresSafeArea()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .statusBarHidden(hud.phase == .playing)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            if scene == nil { scene = SlitherScene(hud: hud) }
            scene?.useJoystick = control == "joystick"
            scene?.isPaused = false
        }
        .onDisappear { scene?.isPaused = true }
    }

    private var playingHUD: some View {
        ZStack {
            // Top bar
            VStack {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(hud.length)")
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .contentTransition(.numericText())
                            .animation(.snappy, value: hud.length)
                        HStack(spacing: 10) {
                            Label("\(hud.rank)/\(hud.total)", systemImage: "trophy.fill")
                            Label("\(hud.kills)", systemImage: "scope")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))
                    }
                    .foregroundStyle(.white)
                    Spacer()
                    leaderboard
                }
                .padding(.horizontal)
                .padding(.top, 8)
                if control == "joystick" {
                    HStack {
                        minimap.scaleEffect(0.8, anchor: .topLeading)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                }
                Spacer()
            }
            .allowsHitTesting(false)

            // Flash message
            VStack {
                if let f = hud.flash {
                    Text(f)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color.loz.opacity(0.9), in: Capsule())
                        .shadow(color: Color.loz.opacity(0.6), radius: 16)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                        .id(hud.flashID)
                        .task(id: hud.flashID) {
                            try? await Task.sleep(nanoseconds: 1_400_000_000)
                            withAnimation(.easeOut) { hud.flash = nil }
                        }
                }
                Spacer()
            }
            .padding(.top, 110)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: hud.flashID)
            .allowsHitTesting(false)

            // Bottom: minimap + boost
            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    if control == "joystick" {
                        JoystickView { angle in scene?.joystickAngle = angle }
                    } else {
                        minimap.allowsHitTesting(false)
                    }
                    Spacer()
                    boostButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }

            // Exit
            VStack {
                Spacer()
                Button {
                    hud.phase = .dead
                    scene?.isPaused = true
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 34, height: 34)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .padding(.bottom, 34)
            }
        }
    }

    private var leaderboard: some View {
        VStack(alignment: .trailing, spacing: 3) {
            ForEach(Array(hud.leaders.enumerated()), id: \.element.id) { i, l in
                HStack(spacing: 6) {
                    Text("\(i + 1).").foregroundStyle(.white.opacity(0.5))
                    Text(l.name).fontWeight(l.isPlayer ? .heavy : .regular)
                    Text("\(l.length)").monospacedDigit().foregroundStyle(.white.opacity(0.7))
                }
                .font(.caption)
                .foregroundStyle(l.isPlayer ? Color.loz : .white)
            }
        }
        .padding(10)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
    }

    private var minimap: some View {
        ZStack {
            Circle().fill(.black.opacity(0.4))
            Circle().strokeBorder(Color.red.opacity(0.7), lineWidth: 1.5)
            GeometryReader { geo in
                Circle()
                    .fill(Color.loz)
                    .frame(width: 8, height: 8)
                    .shadow(color: Color.loz, radius: 4)
                    .position(x: hud.map.x * geo.size.width, y: hud.map.y * geo.size.height)
            }
        }
        .frame(width: 84, height: 84)
    }

    private var boostButton: some View {
        Image(systemName: "bolt.fill")
            .font(.system(size: 30, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 84, height: 84)
            .background(
                Circle().fill(hud.canBoost ? Color.loz.opacity(0.85) : Color.gray.opacity(0.4))
                    .shadow(color: hud.canBoost ? Color.loz.opacity(0.7) : .clear, radius: 14)
            )
            .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 2))
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if scene?.boostHeld == false { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
                        scene?.boostHeld = true
                    }
                    .onEnded { _ in scene?.boostHeld = false }
            )
            .accessibilityLabel("Hızlan")
    }

    private var menu: some View {
        VStack(spacing: 18) {
            Spacer()
            VStack(spacing: 6) {
                Text("YILAN.IO")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [Color.loz, .yellow], startPoint: .leading, endPoint: .trailing))
                    .shadow(color: Color.loz.opacity(0.6), radius: 18)
                Text("Rakipleri kendi gövdene çarptır,\nparçalarını topla, en uzun yılan ol.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.8))
            }
            HStack(spacing: 24) {
                stat("Rekor uzunluk", "\(hud.best)")
                stat("Rekor av", "\(hud.bestKills)")
            }
            Picker("Kontrol", selection: $control) {
                Text("Joystick").tag("joystick")
                Text("Parmakla yönlendir").tag("finger")
            }
            .pickerStyle(.segmented)
            .frame(width: 280)
            .onChange(of: control) { _, v in scene?.useJoystick = v == "joystick" }
            Button {
                scene?.startGame()
            } label: {
                Text("OYNA")
                    .font(.title2.weight(.heavy))
                    .frame(width: 220, height: 58)
                    .background(Color.loz, in: Capsule())
                    .foregroundStyle(.white)
                    .shadow(color: Color.loz.opacity(0.7), radius: 16)
            }
            Button("Çık") { dismiss() }
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(control == "joystick" ? "Sol alttaki çubukla yön ver, ⚡ ile hızlan." : "İpucu: İki parmakla dokunmak da hızlandırır.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
                .padding(.bottom, 30)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.35))
    }

    private var gameOver: some View {
        VStack(spacing: 16) {
            Text(hud.newBest ? "YENİ REKOR!" : "OYUN BİTTİ")
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundStyle(hud.newBest ? Color.yellow : .white)
                .shadow(color: hud.newBest ? Color.yellow.opacity(0.6) : .clear, radius: 16)
            HStack(spacing: 24) {
                stat("Uzunluk", "\(hud.length)")
                stat("Av", "\(hud.kills)")
                stat("Rekor", "\(hud.best)")
            }
            Button {
                scene?.startGame()
            } label: {
                Text("TEKRAR OYNA")
                    .font(.title3.weight(.heavy))
                    .frame(width: 230, height: 56)
                    .background(Color.loz, in: Capsule())
                    .foregroundStyle(.white)
            }
            Button("Çık") { dismiss() }
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(28)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26))
        .environment(\.colorScheme, .dark)
        .transition(.scale.combined(with: .opacity))
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title.weight(.heavy).monospacedDigit()).foregroundStyle(.white)
            Text(title).font(.caption).foregroundStyle(.white.opacity(0.6))
        }
    }
}


/// A thumb stick: drag inside the ring to steer. Reports the angle (radians, maths orientation) or nil when released.
struct JoystickView: View {
    let onChange: (CGFloat?) -> Void
    @State private var knob: CGSize = .zero
    @State private var active = false
    private let radius: CGFloat = 62

    var body: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(active ? 0.14 : 0.08))
                .overlay(Circle().strokeBorder(.white.opacity(0.28), lineWidth: 2))
                .frame(width: radius * 2, height: radius * 2)
            // direction hint
            Circle()
                .trim(from: 0.0, to: 0.12)
                .stroke(Color.loz.opacity(active ? 0.9 : 0), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: radius * 2 - 8, height: radius * 2 - 8)
                .rotationEffect(.radians(Double(atan2(knob.height, knob.width)) - 0.377))
            Circle()
                .fill(
                    RadialGradient(colors: [.white, Color.loz], center: .init(x: 0.35, y: 0.3), startRadius: 2, endRadius: 34)
                )
                .frame(width: 58, height: 58)
                .shadow(color: Color.loz.opacity(0.6), radius: active ? 12 : 6)
                .offset(knob)
        }
        .frame(width: radius * 2 + 20, height: radius * 2 + 20)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    let c = CGPoint(x: radius + 10, y: radius + 10)
                    var dx = v.location.x - c.x
                    var dy = v.location.y - c.y
                    let len = hypot(dx, dy)
                    if len > radius {
                        dx = dx / len * radius
                        dy = dy / len * radius
                    }
                    if !active {
                        active = true
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }
                    knob = CGSize(width: dx, height: dy)
                    if len > 6 { onChange(atan2(-dy, dx)) }
                }
                .onEnded { _ in
                    active = false
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { knob = .zero }
                    onChange(nil)
                }
        )
        .accessibilityLabel("Yön çubuğu")
    }
}
