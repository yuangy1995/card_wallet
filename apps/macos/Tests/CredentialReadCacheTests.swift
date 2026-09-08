import XCTest
@testable import CreditCardMac

final class CredentialReadCacheTests: XCTestCase {
    private enum TestError: Error { case denied }

    func testRepeatedAndConcurrentReadsRequestCredentialOnlyOnce() throws {
        let cache = CredentialReadCache()
        var reads = 0
        DispatchQueue.concurrentPerform(iterations: 30) { _ in
            let result = cache.read(key: "password") {
                reads += 1 // loader 在 cache 锁内执行。
                return .success("test-only")
            }
            XCTAssertEqual(try? result.get(), "test-only")
        }
        XCTAssertEqual(reads, 1)
    }

    func testDeniedReadsWaitForExplicitRetry() throws {
        let cache = CredentialReadCache()
        var reads = 0
        for _ in 0..<10 {
            XCTAssertThrowsError(try cache.read(key: "password") {
                reads += 1
                return .failure(TestError.denied)
            }.get())
        }
        XCTAssertEqual(reads, 1)
        cache.retryFailures(key: "password")
        XCTAssertEqual(try cache.read(key: "password") { .success("allowed") }.get(), "allowed")
    }

    func testRetryDoesNotDiscardSuccessfullyAuthorizedCredentials() throws {
        let cache = CredentialReadCache()
        _ = cache.read(key: "username") { .success("test-only") }
        _ = cache.read(key: "password") { .failure(TestError.denied) }
        cache.retryFailures()
        XCTAssertEqual(try cache.read(key: "username") { XCTFail("重复授权"); return .success(nil) }.get(), "test-only")
        XCTAssertEqual(try cache.read(key: "password") { .success("allowed") }.get(), "allowed")
    }

    func testMissingCredentialIsDistinctFromDeniedAndStorageChangeClearsCache() throws {
        let cache = CredentialReadCache()
        XCTAssertNil(try cache.read(key: "missing") { .success(nil) }.get())
        XCTAssertThrowsError(try cache.read(key: "denied") { .failure(TestError.denied) }.get())
        cache.removeAll()
        XCTAssertEqual(try cache.read(key: "missing") { .success("new-storage") }.get(), "new-storage")
    }
}
