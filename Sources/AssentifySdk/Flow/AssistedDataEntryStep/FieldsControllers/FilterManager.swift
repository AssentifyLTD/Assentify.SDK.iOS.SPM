import Combine

public class FilterManager {
    static let shared = FilterManager()
    let trigger = PassthroughSubject<Void, Never>()

    func updateFilter() {
        trigger.send()
    }
}
