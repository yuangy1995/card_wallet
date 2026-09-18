import XCTest
XCTMain([testCase([
    ("testBatchOperations", PlatformContractTests.testBatchOperations),
    ("testImageRoundtrip", PlatformContractTests.testImageRoundtrip),
    ("testLocalFavorites", PlatformContractTests.testLocalFavorites),
    ("testSearch", PlatformContractTests.testSearch),
    ("testSorting", PlatformContractTests.testSorting),
    ("testCreditLimits", PlatformContractTests.testCreditLimits),
    ("testBillingDates", PlatformContractTests.testBillingDates),
    ("testExpiryMonth", PlatformContractTests.testExpiryMonth),
    ("testAnnualFees", PlatformContractTests.testAnnualFees),
    ("testReminders", PlatformContractTests.testReminders),
    ("testSyncConvergence", PlatformContractTests.testSyncConvergence),
    ("testMonotonicLocalEdits", PlatformContractTests.testMonotonicLocalEdits)
])])
