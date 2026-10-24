import Shared

struct PointEntry: Entity, Identifiable {
    let point: Point
    let checkpoint: Checkpoint?
    let performance: Performance?

    var anchor: Anchor? { point.anchor }
    var id: Point.ID { point.id }
    var coordinate: Coordinate { point.coordinate }
    var time: SimpleTime? { point.time }
    var title: String? { checkpoint?.name ?? performance?.name ?? anchor?.text }

    // FIXME: 永続化レイヤー再構築後に関連する交差点・余興を渡す。
    init(_ point: Point, checkpoint: Checkpoint? = nil, performance: Performance? = nil) {
        self.point = point
        self.checkpoint = checkpoint
        self.performance = performance
    }
}
