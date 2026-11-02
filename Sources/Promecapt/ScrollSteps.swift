import AppKit

/// Discrete wheel detents ignore OS acceleration; trackpads accumulate distance.
/// Momentum never edits a value after the user has lifted their fingers.
struct ScrollSteps {
    private var remainder: CGFloat = 0
    mutating func reset() { remainder = 0 }
    mutating func consume(delta: CGFloat, precise: Bool, phase: NSEvent.Phase = [], momentum: NSEvent.Phase = []) -> Int {
        guard delta.isFinite else { reset(); return 0 }
        if !momentum.isEmpty || phase.contains(.ended) || phase.contains(.cancelled) { reset(); return 0 }
        if phase.contains(.began) { reset() }
        guard delta != 0 else { return 0 }
        guard precise else { reset(); return delta > 0 ? 1 : -1 }
        if remainder * delta < 0 { reset() }
        remainder += delta
        let threshold: CGFloat = 24
        guard abs(remainder) >= threshold else { return 0 }
        let direction = remainder > 0 ? 1 : -1
        remainder = remainder.truncatingRemainder(dividingBy: threshold)
        return direction
    }
    mutating func consume(_ event: NSEvent) -> Int {
        consume(delta: event.scrollingDeltaY, precise: event.hasPreciseScrollingDeltas, phase: event.phase, momentum: event.momentumPhase)
    }
}
