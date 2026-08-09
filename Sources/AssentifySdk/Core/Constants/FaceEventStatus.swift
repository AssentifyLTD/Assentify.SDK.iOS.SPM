class FaceEventStatus {
    var event: FaceEvents
    var isCompleted: Bool

    init(event: FaceEvents, isCompleted: Bool) {
        self.event = event
        self.isCompleted = isCompleted
    }
}
