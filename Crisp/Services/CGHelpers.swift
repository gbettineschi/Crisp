import Foundation

/// Shared utilities for wrapping blocking CoreGraphics calls.
enum CGHelpers {
    private static let pending = PendingCGOperations()

    /// A response timeout cannot cancel WindowServer IPC. Wait for actual completion
    /// before allowing a replacement configuration to race with an older operation.
    static func waitForPendingOperations(seconds: Double = 10) async -> Bool {
        await pending.waitForCompletion(seconds: seconds)
    }

    /// Runs a blocking operation with a timeout, returning `fallback` if it doesn't finish
    /// in time. For CoreGraphics / WindowServer IPC calls that can hang indefinitely.
    static func runWithTimeout<T: Sendable>(
        seconds: Double,
        fallback: T,
        operation: @escaping @Sendable () -> T
    ) async -> T {
        await withCheckedContinuation { cont in
            let once = ResumeOnce()
            pending.begin()

            DispatchQueue.global(qos: .userInitiated).async {
                let result = operation()
                pending.end()
                if once.claim() { cont.resume(returning: result) }
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + seconds) {
                if once.claim() { cont.resume(returning: fallback) }
            }
        }
    }
}

private final class PendingCGOperations: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    private var waiters: [UUID: CheckedContinuation<Bool, Never>] = [:]

    func begin() {
        lock.lock()
        count += 1
        lock.unlock()
    }

    func end() {
        lock.lock()
        count -= 1
        let ready = count == 0 ? Array(waiters.values) : []
        if count == 0 { waiters.removeAll() }
        lock.unlock()
        for waiter in ready { waiter.resume(returning: true) }
    }

    func waitForCompletion(seconds: Double) async -> Bool {
        await withCheckedContinuation { continuation in
            let token = UUID()
            lock.lock()
            if count == 0 {
                lock.unlock()
                continuation.resume(returning: true)
            } else {
                waiters[token] = continuation
                lock.unlock()
                DispatchQueue.global().asyncAfter(deadline: .now() + seconds) { [self] in
                    lock.lock()
                    let expired = waiters.removeValue(forKey: token)
                    lock.unlock()
                    expired?.resume(returning: false)
                }
            }
        }
    }
}

/// Hands the continuation to whichever of the two closures gets there first. A captured
/// `var` reads as a race to the compiler even when a lock guards it, so it lives in here.
private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var resumed = false

    /// True for the first caller only. The loser leaves the continuation alone.
    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !resumed else { return false }
        resumed = true
        return true
    }
}
