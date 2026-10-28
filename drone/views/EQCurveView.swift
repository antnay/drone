//
//  EQCurveView.swift
//  drone
//
//  Interactive frequency-response plot for the EQ: log frequency axis
//  (20 Hz–20 kHz), dB grid, a live summed magnitude curve, and draggable band
//  nodes (X = frequency, Y = gain). Double-click adds a band; ⌫ removes the
//  selected one.
//

import SwiftUI

struct EQCurveView: View {
    @Binding var settings: EQSettings
    @Binding var selectedBandID: UUID?
    let controller: EqualizerController

    // Plot bounds
    private let minFreq = EQBand.minFrequency
    private let maxFreq = EQBand.maxFrequency
    private let dbRange: Double = 24   // ±24 dB vertical

    /// The band currently being dragged. Set on the first drag change by
    /// hit-testing the start location, cleared on drag end.
    @State private var draggingBandID: UUID?
    /// Tracks whether the current gesture moved far enough to count as a drag
    /// (vs a click, which only selects).
    @State private var didDrag = false

    /// Time + location of the last completed click, used to detect a
    /// double-click entirely within the unified gesture (a separate
    /// onTapGesture never fires, because the minimumDistance:0 drag consumes
    /// the mouse-down before a tap can resolve).
    @State private var lastClickTime: Date = .distantPast
    @State private var lastClickLocation: CGPoint = .zero

    /// Pointer radius (points) within which a drag start grabs a node.
    private let hitRadius: CGFloat = 20
    /// Movement past this distance (points) counts as a drag, not a click.
    private let dragThreshold: CGFloat = 3
    /// Max interval (s) and distance (pt) between two clicks to count as a
    /// double-click.
    private let doubleClickInterval: TimeInterval = 0.4
    private let doubleClickDistance: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                grid(size: size)
                responseCurve(size: size)
                bandNodes(size: size)
            }
            // A single rectangle-wide drag gesture owns all node interaction so
            // it can hit-test the start location against node positions. Per-node
            // gestures previously conflicted with the container tap gestures,
            // which is why nodes couldn't be moved.
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 0.5)
            )
            // One gesture owns everything: drag moves the nearest node, a
            // single click selects, and a double-click (detected by click
            // timing in onEnded) adds a band. Keeping it all in one gesture
            // avoids the arbitration conflict that stopped double-click from
            // firing after the previous rework.
            .gesture(nodeDragGesture(size: size))
            .onScrollWheel { delta in
                adjustSelectedBandQ(delta: delta)
            }
            // Right-click on (or near) a node removes it; ⌫ / ⌦ removes the
            // selected node. Handled via AppKit local-event monitors (see
            // EQInteractionModifier) because SwiftUI focus/key handling proved
            // unreliable in this Window scene.
            .eqInteractions(
                onRightClick: { location in
                    if let id = nearestBandID(to: location, size: size) {
                        controller.removeBand(id: id)
                        if selectedBandID == id { selectedBandID = nil }
                    }
                },
                onDelete: { _ = removeSelectedBand() }
            )
        }
    }

    // MARK: - Unified drag gesture

    private func nodeDragGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if draggingBandID == nil && !didDrag {
                    // First event: grab the nearest node to the start point.
                    draggingBandID = nearestBandID(to: value.startLocation, size: size)
                }
                // Promote to a drag once the pointer has moved enough.
                let moved = hypot(
                    value.location.x - value.startLocation.x,
                    value.location.y - value.startLocation.y
                )
                if moved > dragThreshold { didDrag = true }

                guard didDrag, let id = draggingBandID else { return }
                controller.updateBand(id: id) { b in
                    b.frequency = clampFreq(
                        frequencyFor(x: value.location.x, width: size.width)
                    )
                    if b.filterType.usesGain {
                        b.gain = clampGain(
                            dbFor(y: value.location.y, height: size.height)
                        )
                    }
                }
                if selectedBandID != id { selectedBandID = id }
            }
            .onEnded { value in
                defer {
                    draggingBandID = nil
                    didDrag = false
                }
                guard !didDrag else { return }

                // No movement → this was a click. Decide click vs double-click
                // from the time + distance to the previous click.
                let now = Date()
                let loc = value.startLocation
                let isDoubleClick =
                    now.timeIntervalSince(lastClickTime) <= doubleClickInterval
                    && hypot(loc.x - lastClickLocation.x, loc.y - lastClickLocation.y)
                        <= doubleClickDistance

                if isDoubleClick {
                    addBand(at: loc, size: size)
                    // Reset so a third quick click doesn't add again.
                    lastClickTime = .distantPast
                } else {
                    // Single click: select nearest node (or clear).
                    selectedBandID = nearestBandID(to: loc, size: size)
                    lastClickTime = now
                    lastClickLocation = loc
                }
            }
    }

    /// Nearest band to `point` within `hitRadius`, or nil if none close enough.
    /// Must mirror the node's drawn position (on the curve) so clicks land on
    /// the visible dot.
    private func nearestBandID(to point: CGPoint, size: CGSize) -> UUID? {
        var best: (id: UUID, dist: CGFloat)?
        for band in settings.bands {
            let x = xFor(frequency: band.frequency, width: size.width)
            let nodeDB = EQResponse.magnitude(of: settings, atFrequency: band.frequency)
            let y = yFor(db: nodeDB, height: size.height)
            let d = hypot(point.x - x, point.y - y)
            if d <= hitRadius, best == nil || d < best!.dist {
                best = (band.id, d)
            }
        }
        return best?.id
    }

    private func adjustSelectedBandQ(delta: Double) {
        guard let id = selectedBandID else { return }
        controller.updateBand(id: id) { b in
            let next = b.bandwidth + delta * 0.05
            b.bandwidth = min(EQBand.maxBandwidth, max(EQBand.minBandwidth, next))
        }
    }

    private func removeSelectedBand() -> KeyPress.Result {
        guard let id = selectedBandID else { return .ignored }
        controller.removeBand(id: id)
        selectedBandID = nil
        return .handled
    }

    // MARK: - Grid

    private func grid(size: CGSize) -> some View {
        Canvas { ctx, _ in
            let gridColor = Color.secondary.opacity(0.18)
            let labelColor = Color.secondary.opacity(0.7)

            // Vertical frequency lines at decade + common marks.
            let freqMarks: [Double] = [20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000]
            for f in freqMarks {
                let x = xFor(frequency: f, width: size.width)
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                ctx.stroke(path, with: .color(gridColor), lineWidth: 0.5)

                let label = f >= 1000 ? "\(Int(f / 1000))k" : "\(Int(f))"
                ctx.draw(
                    Text(label).font(.system(size: 9)).foregroundStyle(labelColor),
                    at: CGPoint(x: x + 2, y: size.height - 8),
                    anchor: .leading
                )
            }

            // Horizontal dB lines every 6 dB.
            for db in stride(from: -dbRange, through: dbRange, by: 6) {
                let y = yFor(db: db, height: size.height)
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                let isZero = abs(db) < 0.001
                ctx.stroke(
                    path,
                    with: .color(isZero ? Color.secondary.opacity(0.4) : gridColor),
                    lineWidth: isZero ? 1 : 0.5
                )
                if !isZero {
                    ctx.draw(
                        Text("\(Int(db))").font(.system(size: 9)).foregroundStyle(labelColor),
                        at: CGPoint(x: 4, y: y - 7),
                        anchor: .leading
                    )
                }
            }
        }
    }

    // MARK: - Response curve

    private func responseCurve(size: CGSize) -> some View {
        Canvas { ctx, _ in
            guard size.width > 1 else { return }
            var path = Path()
            let steps = Int(size.width)
            for px in 0...steps {
                let x = Double(px)
                let freq = frequencyFor(x: x, width: size.width)
                let db = EQResponse.magnitude(
                    of: settings, atFrequency: freq
                )
                let y = yFor(db: db, height: size.height)
                let pt = CGPoint(x: x, y: y)
                if px == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }

            let curveColor = settings.enabled ? Color.accentColor : Color.secondary
            ctx.stroke(
                path,
                with: .color(curveColor),
                style: StrokeStyle(lineWidth: 2, lineJoin: .round)
            )

            // Soft fill under the curve.
            var fill = path
            fill.addLine(to: CGPoint(x: size.width, y: yFor(db: 0, height: size.height)))
            fill.addLine(to: CGPoint(x: 0, y: yFor(db: 0, height: size.height)))
            fill.closeSubpath()
            ctx.fill(fill, with: .color(curveColor.opacity(0.1)))
        }
        .allowsHitTesting(false)
    }

    // MARK: - Band nodes

    private func bandNodes(size: CGSize) -> some View {
        // Purely visual — all interaction is handled by the container drag
        // gesture in `body`, which hit-tests node positions. Nodes must not
        // intercept hits, or they'd swallow the drag's start location.
        ForEach(settings.bands) { band in
            let x = xFor(frequency: band.frequency, width: size.width)
            // Place the node ON the response curve (the summed magnitude at this
            // band's frequency), not at the band's raw gain. A biquad's true
            // peak magnitude differs from the nominal gain — more so at high
            // frequencies and with neighbouring bands — so pinning to raw gain
            // made the dot drift off the line. This keeps it glued to the curve.
            let nodeDB = EQResponse.magnitude(of: settings, atFrequency: band.frequency)
            let y = yFor(db: nodeDB, height: size.height)
            let isSelected = band.id == selectedBandID

            Circle()
                .fill(isSelected ? Color.accentColor : Color.accentColor.opacity(0.65))
                .frame(width: isSelected ? 16 : 12, height: isSelected ? 16 : 12)
                .overlay(
                    Circle().strokeBorder(Color.white.opacity(0.9), lineWidth: 1.5)
                )
                .position(x: x, y: y)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Actions

    private func addBand(at location: CGPoint, size: CGSize) {
        let freq = clampFreq(frequencyFor(x: location.x, width: size.width))
        let gain = clampGain(dbFor(y: location.y, height: size.height))
        if let band = controller.addBand(frequency: freq, gain: gain) {
            selectedBandID = band.id
        }
    }

    // MARK: - Coordinate transforms

    private func xFor(frequency: Double, width: CGFloat) -> CGFloat {
        let logMin = log10(minFreq)
        let logMax = log10(maxFreq)
        let f = min(max(frequency, minFreq), maxFreq)
        let frac = (log10(f) - logMin) / (logMax - logMin)
        return CGFloat(frac) * width
    }

    private func frequencyFor(x: CGFloat, width: CGFloat) -> Double {
        let logMin = log10(minFreq)
        let logMax = log10(maxFreq)
        let frac = max(0, min(1, Double(x / max(1, width))))
        return pow(10, logMin + frac * (logMax - logMin))
    }

    private func yFor(db: Double, height: CGFloat) -> CGFloat {
        let frac = (db + dbRange) / (2 * dbRange)   // 0...1 bottom→top
        return height * (1 - CGFloat(frac))
    }

    private func dbFor(y: CGFloat, height: CGFloat) -> Double {
        let frac = 1 - Double(y / max(1, height))
        return frac * (2 * dbRange) - dbRange
    }

    private func clampFreq(_ f: Double) -> Double {
        min(EQBand.maxFrequency, max(EQBand.minFrequency, f))
    }

    private func clampGain(_ g: Double) -> Double {
        min(EQBand.maxGain, max(EQBand.minGain, g))
    }
}

// MARK: - Scroll-wheel helper (AppKit bridge)

private struct ScrollWheelModifier: ViewModifier {
    let onScroll: (Double) -> Void

    func body(content: Content) -> some View {
        content.background(ScrollWheelCatcher(onScroll: onScroll))
    }
}

private struct ScrollWheelCatcher: NSViewRepresentable {
    let onScroll: (Double) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = ScrollReceivingView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? ScrollReceivingView)?.onScroll = onScroll
    }

    final class ScrollReceivingView: NSView {
        var onScroll: ((Double) -> Void)?
        override func scrollWheel(with event: NSEvent) {
            onScroll?(Double(event.scrollingDeltaY))
        }
    }
}

extension View {
    func onScrollWheel(_ action: @escaping (Double) -> Void) -> some View {
        modifier(ScrollWheelModifier(onScroll: action))
    }
}

// MARK: - Right-click + key helper (AppKit local-event monitor bridge)
//
// SwiftUI's .focusable()/.onKeyPress and background NSViews proved unreliable
// for right-click + Delete in this plain Window scene. Instead we install local
// NSEvent monitors scoped to this view's lifetime, and only act when the event
// falls inside the plot's bounds — robust regardless of SwiftUI focus/layering.

private struct EQInteractionModifier: ViewModifier {
    let onRightClick: (CGPoint) -> Void
    let onDelete: () -> Void

    func body(content: Content) -> some View {
        content.background(
            EQEventMonitorView(onRightClick: onRightClick, onDelete: onDelete)
                .allowsHitTesting(false)
        )
    }
}

private struct EQEventMonitorView: NSViewRepresentable {
    let onRightClick: (CGPoint) -> Void
    let onDelete: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = MonitorView()
        view.onRightClick = onRightClick
        view.onDelete = onDelete
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let v = nsView as? MonitorView else { return }
        v.onRightClick = onRightClick
        v.onDelete = onDelete
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: ()) {
        (nsView as? MonitorView)?.teardown()
    }

    final class MonitorView: NSView {
        var onRightClick: ((CGPoint) -> Void)?
        var onDelete: (() -> Void)?
        private var rightMonitor: Any?
        private var keyMonitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil { install() } else { teardown() }
        }

        private func install() {
            guard rightMonitor == nil else { return }
            rightMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
                guard let self, let point = self.localPointIfInside(event) else { return event }
                self.onRightClick?(point)
                return nil  // consume so no context menu appears
            }
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.window?.isKeyWindow == true else { return event }
                // 51 = Delete/Backspace, 117 = Forward Delete.
                guard event.keyCode == 51 || event.keyCode == 117 else { return event }
                // Don't steal Delete from a focused text field (e.g. preamp).
                if self.window?.firstResponder is NSText { return event }
                self.onDelete?()
                return nil
            }
        }

        /// Returns the event location in this view's top-left SwiftUI coords if
        /// it lands within the view, else nil.
        private func localPointIfInside(_ event: NSEvent) -> CGPoint? {
            guard event.window == window else { return nil }
            let inView = convert(event.locationInWindow, from: nil)
            guard bounds.contains(inView) else { return nil }
            // AppKit bottom-left → SwiftUI top-left.
            return CGPoint(x: inView.x, y: bounds.height - inView.y)
        }

        func teardown() {
            if let m = rightMonitor { NSEvent.removeMonitor(m); rightMonitor = nil }
            if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
        }

        deinit { teardown() }
    }
}

extension View {
    func eqInteractions(
        onRightClick: @escaping (CGPoint) -> Void,
        onDelete: @escaping () -> Void
    ) -> some View {
        modifier(EQInteractionModifier(onRightClick: onRightClick, onDelete: onDelete))
    }
}
