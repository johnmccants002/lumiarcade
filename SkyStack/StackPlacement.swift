import CoreGraphics

struct StackSpan: Equatable {
    let center: CGFloat
    let width: CGFloat
    var left: CGFloat { center - width / 2 }
    var right: CGFloat { center + width / 2 }
}

struct StackPlacement {
    let overlap: StackSpan?
    let offcuts: [StackSpan]
    let isPerfect: Bool

    static func resolve(moving: StackSpan, supporting: StackSpan,
                        tolerance: CGFloat = SkyStackConfig.perfectTolerance) -> Self {
        if abs(moving.center - supporting.center) <= tolerance,
           abs(moving.width - supporting.width) < 0.001 {
            return Self(overlap: supporting, offcuts: [], isPerfect: true)
        }
        let left = max(moving.left, supporting.left)
        let right = min(moving.right, supporting.right)
        guard right > left else {
            return Self(overlap: nil, offcuts: [moving], isPerfect: false)
        }
        var offcuts: [StackSpan] = []
        if moving.left < left {
            offcuts.append(StackSpan(center: (moving.left + left) / 2, width: left - moving.left))
        }
        if moving.right > right {
            offcuts.append(StackSpan(center: (moving.right + right) / 2, width: moving.right - right))
        }
        return Self(overlap: StackSpan(center: (left + right) / 2, width: right - left),
                    offcuts: offcuts, isPerfect: false)
    }
}
