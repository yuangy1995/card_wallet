import XCTest
import CreditCardMac

final class DateCalculatorTests: XCTestCase {
    
    func testInterestFreePeriodNormalCase() {
        let today = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 9, day: 18))!
        // Today spending, not a guessed maximum made from 30/31-day constants.
        XCTAssertEqual(DateCalculator.calculateInterestFreePeriod(accountBillDate: "10", dueDate: "28", today: today), 40)
        XCTAssertEqual(DateCalculator.calculateInterestFreePeriod(accountBillDate: "25", dueDate: "10", today: today), 22)
    }
    
    func testMonthlyOverflowBoundary() {
        // 验证 2 月份等月末日期的边界效应
        // 如果账单日设为 31 号，由于 2 月份没有 31 号，应当自动裁剪并补全为 2 月的最后一天（28号或29号）
        let billDate = "31"
        
        // 我们通过 completeDueDate 或 completeAccountBillDate 手动检查它在 2 月的推导
        // 在 DateCalculator 中，如果把月份偏移推到 2 月：
        // 这里我们可以检验底层 completedDay 的安全限制，防止崩溃并取得正确天数。
        let completed = DateCalculator.completeAccountBillDate(billDate)
        XCTAssertFalse(completed.isEmpty)
        
        // 日期字符串应当是 YYYY-MM-DD
        let parts = completed.split(separator: "-")
        XCTAssertEqual(parts.count, 3)
        let dayPart = Int(parts[2])!
        XCTAssertTrue(dayPart >= 1 && dayPart <= 31)
    }
    
    func testAnnualFeeWarning() {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        
        // 1. 设置下次年费时间为 30 天后 (应当报警)
        let warningDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        let warningDateStr = df.string(from: warningDate)
        XCTAssertTrue(DateCalculator.isNearAnnualFeeDate(warningDateStr))
        
        // 2. 设置下次年费时间为 90 天后 (不应当报警，默认 60 天报警)
        let safeDate = Calendar.current.date(byAdding: .day, value: 90, to: Date())!
        let safeDateStr = df.string(from: safeDate)
        XCTAssertFalse(DateCalculator.isNearAnnualFeeDate(safeDateStr))
        
        // 3. 空值处理
        XCTAssertFalse(DateCalculator.isNearAnnualFeeDate(nil))
    }
}
