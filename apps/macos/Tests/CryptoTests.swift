import XCTest
import CreditCardMac

final class CryptoTests: XCTestCase {
    
    // 默认测试卡片数据（模拟 Web 端导出的加密数据）
    // 密密文是使用 CryptoJS 加密 "hello world!"，密码为 "defAult.@.Password." (默认前缀)
    let defaultEncryptedText = "default:U2FsdGVkX19P9aG96c4H5hDggJ/oU63Yq5yB0bA=" // 模拟测试值，如果是动态的，我们可以在测试里自己加密再解密
    
    func testDefaultEncryptionDecryption() {
        let originalText = "{\"cards\":[],\"version\":\"1.2.0\"}"
        
        do {
            // 1. 进行默认加密
            let encrypted = try CryptoManager.encrypt(plainText: originalText)
            XCTAssertTrue(encrypted.hasPrefix("default:"))
            
            // 2. 进行默认解密
            let decrypted = try CryptoManager.decrypt(cipherText: encrypted)
            XCTAssertEqual(decrypted, originalText)
            
        } catch {
            XCTFail("默认加密/解密失败，错误信息: \(error.localizedDescription)")
        }
    }
    
    func testCustomPasswordEncryptionDecryption() {
        let originalText = "{\"bank\":\"招商银行\",\"limit\":50000.0}"
        let customPassword = "MySecurePassword123!"
        
        do {
            // 1. 使用自定义密码加密
            let encrypted = try CryptoManager.encrypt(plainText: originalText, password: customPassword)
            XCTAssertTrue(encrypted.hasPrefix("encrypted:"))
            
            // 2. 尝试用错误密码解密 (应当报错)
            XCTAssertThrowsError(try CryptoManager.decrypt(cipherText: encrypted, password: "WrongPassword"))
            
            // 3. 用正确密码解密
            let decrypted = try CryptoManager.decrypt(cipherText: encrypted, password: customPassword)
            XCTAssertEqual(decrypted, originalText)
            
        } catch {
            XCTFail("自定义密码加密/解密失败，错误信息: \(error.localizedDescription)")
        }
    }
    
    func testCryptoJSCompatibility() {
        // 这是使用 CryptoJS 加密 "CryptoJS-Swift-Bridge-Test"，密码为默认密码产生的真实密文
        // JS加密代码：CryptoJS.AES.encrypt("CryptoJS-Swift-Bridge-Test", "defAult.@.Password.").toString()
        // 加上 default: 前缀后得到以下密文
        let jsGeneratedCipherText = "default:U2FsdGVkX18+HMrF7/PsZ32FcaRC6bSaCleU1CkNyVPip6CYBxDB6MAZ1VobKsIr"
        
        do {
            let decrypted = try CryptoManager.decrypt(cipherText: jsGeneratedCipherText)
            XCTAssertEqual(decrypted, "CryptoJS-Swift-Bridge-Test")
        } catch {
            XCTFail("CryptoJS 互通兼容性测试失败，无法解密 Web 端生成的数据: \(error.localizedDescription)")
        }
    }
}
