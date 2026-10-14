// swiftc -swift-version 6 -parse-as-library Crisp/Services/CGHelpers.swift \
//   scripts/check-cg-completion.swift -o /tmp/crisp-cg-checks && /tmp/crisp-cg-checks
import Foundation

@MainActor
@main
struct CGCompletionChecks {
    static func main() async {
        for _ in 0..<3 {
            let release = DispatchSemaphore(value: 0)
            let result = await CGHelpers.runWithTimeout(seconds: 0.02, fallback: false) {
                release.wait()
                return true
            }
            precondition(!result, "Expected the response timeout")
            var completed = false
            let waiter = Task { @MainActor in
                completed = await CGHelpers.waitForPendingOperations()
            }
            try? await Task.sleep(for: .milliseconds(20))
            precondition(!completed, "A timed-out transaction was mistaken for a completed transaction")
            let timedOut = await CGHelpers.waitForPendingOperations(seconds: 0.01)
            precondition(!timedOut, "A busy barrier must reject replacement work")
            release.signal()
            await waiter.value
            precondition(completed)
            let drained = await CGHelpers.waitForPendingOperations()
            precondition(drained)
        }
        print("PASS: timeout returns promptly; transaction barrier waits for real completion (3 runs)")
    }
}
