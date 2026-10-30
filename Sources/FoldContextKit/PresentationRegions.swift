/// Pure geometry in window points; never creates or positions application views.
enum FoldRegionResolver {
    static func resolve(
        mode: FoldPresentationMode, geometry: FoldLayoutGeometry, window: FoldPresentationRegion
    ) -> (regions: [FoldPresentationRegion], source: FoldRegionSource) {
        guard let safe = intersection(geometry.safeArea, window) else { return ([], .unavailable) }
        switch mode {
        case .unknown, .interiorUnspecified:
            return ([], .unavailable)
        case .exterior, .interiorExtended:
            return ([safe], .safeArea)
        case let .interiorDivided(axis):
            // Only an unambiguous full-span divider determines the two regions.
            let candidates = geometry.divisions.compactMap { split(safe, around: $0.frame, axis: axis) }
            if candidates.count == 1 { return (candidates[0], .systemDivision) }
            switch axis {
            case .horizontal:
                return ([
                    rect(safe.x, safe.y, safe.width / 2, safe.height),
                    rect(safe.x + safe.width / 2, safe.y, safe.width / 2, safe.height)
                ], .appEqualSplit)
            case .vertical:
                return ([
                    rect(safe.x, safe.y, safe.width, safe.height / 2),
                    rect(safe.x, safe.y + safe.height / 2, safe.width, safe.height / 2)
                ], .appEqualSplit)
            }
        }
    }

    static func subtractOcclusions(
        _ occlusions: [FoldReservedRegion], from regions: [FoldPresentationRegion]
    ) -> (regions: [FoldPresentationRegion], truncated: Bool) {
        var output = regions
        var truncated = false
        for occlusion in occlusions {
            guard valid(occlusion.frame) else { return ([], true) }
            var next: [FoldPresentationRegion] = []
            for region in output {
                guard let cut = intersection(region, occlusion.frame) else {
                    next.append(region)
                    continue
                }
                let pieces = [
                    rect(region.x, region.y, region.width, cut.y - region.y),
                    rect(region.x, cut.y + cut.height, region.width,
                         region.y + region.height - cut.y - cut.height),
                    rect(region.x, cut.y, cut.x - region.x, cut.height),
                    rect(cut.x + cut.width, cut.y,
                         region.x + region.width - cut.x - cut.width, cut.height)
                ]
                next.append(contentsOf: pieces.filter { valid($0) && $0.width > 0 && $0.height > 0 })
            }
            if next.count > 32 {
                // Dropping coverage never reintroduces an occluded area.
                truncated = true
                next = Array(next.prefix(32))
            }
            output = next
        }
        return (output, truncated)
    }

    private static func split(
        _ area: FoldPresentationRegion, around divider: FoldPresentationRegion, axis: FoldRegionAxis
    ) -> [FoldPresentationRegion]? {
        guard valid(divider) else { return nil }
        switch axis {
        case .horizontal:
            guard divider.y <= area.y, divider.y + divider.height >= area.y + area.height,
                  divider.x > area.x, divider.x + divider.width < area.x + area.width else { return nil }
            return [
                rect(area.x, area.y, divider.x - area.x, area.height),
                rect(divider.x + divider.width, area.y,
                     area.x + area.width - divider.x - divider.width, area.height)
            ]
        case .vertical:
            guard divider.x <= area.x, divider.x + divider.width >= area.x + area.width,
                  divider.y > area.y, divider.y + divider.height < area.y + area.height else { return nil }
            return [
                rect(area.x, area.y, area.width, divider.y - area.y),
                rect(area.x, divider.y + divider.height, area.width,
                     area.y + area.height - divider.y - divider.height)
            ]
        }
    }

    private static func intersection(
        _ a: FoldPresentationRegion, _ b: FoldPresentationRegion
    ) -> FoldPresentationRegion? {
        guard valid(a), valid(b) else { return nil }
        let x = max(a.x, b.x)
        let y = max(a.y, b.y)
        let width = min(a.x + a.width, b.x + b.width) - x
        let height = min(a.y + a.height, b.y + b.height) - y
        guard width > 0, height > 0 else { return nil }
        return rect(x, y, width, height)
    }

    private static func valid(_ r: FoldPresentationRegion) -> Bool {
        r.x.isFinite && r.y.isFinite && r.width.isFinite && r.height.isFinite
            && r.width >= 0 && r.height >= 0
            && (r.x + r.width).isFinite && (r.y + r.height).isFinite
    }

    private static func rect(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> FoldPresentationRegion {
        FoldPresentationRegion(x: x, y: y, width: width, height: height)
    }
}
