import Foundation

nonisolated final class ProcessRunState: @unchecked Sendable {
    private let lock = NSLock()
    private var finished = false
    private var timedOut = false

    var didTimeOut: Bool {
        lock.lock()
        defer { lock.unlock() }
        return timedOut
    }

    func markTimedOut() {
        lock.lock()
        timedOut = true
        lock.unlock()
    }

    func finish(_ action: () -> Void) {
        lock.lock()
        if finished {
            lock.unlock()
            return
        }
        finished = true
        lock.unlock()
        action()
    }
}

nonisolated final class PipeOutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private let handle: FileHandle
    private var data = Data()
    private var isFinished = false

    init(pipe: Pipe) {
        handle = pipe.fileHandleForReading
        handle.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            self?.append(chunk)
        }
    }

    func finish() -> Data {
        lock.lock()
        guard !isFinished else {
            let result = data
            lock.unlock()
            return result
        }
        isFinished = true
        lock.unlock()

        handle.readabilityHandler = nil
        append(handle.readDataToEndOfFile())

        lock.lock()
        defer { lock.unlock() }
        return data
    }

    private func append(_ chunk: Data) {
        lock.lock()
        data.append(chunk)
        lock.unlock()
    }
}
