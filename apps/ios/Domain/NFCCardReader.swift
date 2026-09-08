import Foundation
#if ENABLE_NFC_CARD_READER && canImport(CoreNFC)
import CoreNFC

@available(iOS 13.0, *)
class NFCCardReader: NSObject, NFCTagReaderSessionDelegate {
    private var session: NFCTagReaderSession?
    private var completion: ((Result<(String, String?), Error>) -> Void)?
    
    func startReading(completion: @escaping (Result<(String, String?), Error>) -> Void) {
        self.completion = completion
        guard NFCTagReaderSession.readingAvailable else {
            completion(.failure(NSError(domain: "NFCReader", code: -1, userInfo: [NSLocalizedDescriptionKey: "当前设备不支持 NFC"])))
            return
        }
        session = NFCTagReaderSession(pollingOption: .iso14443, delegate: self, queue: nil)
        session?.alertMessage = "请将银行卡贴在手机背面顶部的 NFC 感应区。"
        session?.begin()
    }
    
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        completion?(.failure(error))
        self.session = nil
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard tags.count == 1, let tag = tags.first else {
            session.alertMessage = "检测到多张卡片，请一次只贴一张卡。"
            session.restartPolling()
            return
        }
        
        session.connect(to: tag) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                session.invalidate(errorMessage: "连接卡片失败: \(error.localizedDescription)")
                self.completion?(.failure(error))
                return
            }
            
            guard case let .iso7816(iso7816Tag) = tag else {
                session.invalidate(errorMessage: "不支持的卡片类型。")
                self.completion?(.failure(NSError(domain: "NFCReader", code: -2, userInfo: [NSLocalizedDescriptionKey: "不支持的卡片类型"])))
                return
            }
            
            self.readEMVCard(iso7816Tag: iso7816Tag, session: session)
        }
    }
    
    private func readEMVCard(iso7816Tag: NFCISO7816Tag, session: NFCTagReaderSession) {
        let aids = [
            "A000000333010101", // 银联借记
            "A000000333010102", // 银联贷记
            "A000000333010103", // 银联准贷记
            "A0000000031010",   // Visa
            "A0000000041010"    // MasterCard
        ]
        
        self.trySelectAID(index: 0, aids: aids, tag: iso7816Tag, session: session)
    }
    
    private func trySelectAID(index: Int, aids: [String], tag: NFCISO7816Tag, session: NFCTagReaderSession) {
        guard index < aids.count else {
            session.invalidate(errorMessage: "未找到有效的银行卡应用，请确认这是否是支持的银行卡。")
            self.completion?(.failure(NSError(domain: "NFCReader", code: -3, userInfo: [NSLocalizedDescriptionKey: "未找到可识别的银行卡应用"])))
            return
        }
        
        let aidStr = aids[index]
        guard let aidData = aidStr.hexStringToData() else {
            trySelectAID(index: index + 1, aids: aids, tag: tag, session: session)
            return
        }
        
        // SELECT APDU: 00 A4 04 00 [Lc] [AID] 00
        var apduCommand = Data([0x00, 0xA4, 0x04, 0x00, UInt8(aidData.count)])
        apduCommand.append(aidData)
        apduCommand.append(0x00)
        
        let apdu = NFCISO7816APDU(data: apduCommand)!
        tag.sendCommand(apdu: apdu) { [weak self] responseData, sw1, sw2, error in
            guard let self = self else { return }
            if error != nil || (sw1 != 0x90 && sw1 != 0x61) {
                self.trySelectAID(index: index + 1, aids: aids, tag: tag, session: session)
                return
            }
            
            self.readRecords(tag: tag, session: session)
        }
    }
    
    private func readRecords(tag: NFCISO7816Tag, session: NFCTagReaderSession) {
        let sfiList: [UInt8] = [1, 2, 3, 4]
        let recordList: [UInt8] = [1, 2, 3, 4, 5]
        
        var queries: [(sfi: UInt8, rec: UInt8)] = []
        for sfi in sfiList {
            for rec in recordList {
                queries.append((sfi, rec))
            }
        }
        
        self.tryReadRecord(index: 0, queries: queries, tag: tag, session: session, cardNum: nil, expiration: nil)
    }
    
    private func tryReadRecord(index: Int, queries: [(sfi: UInt8, rec: UInt8)], tag: NFCISO7816Tag, session: NFCTagReaderSession, cardNum: String?, expiration: String?) {
        if let cardNum = cardNum {
            session.invalidate()
            self.completion?(.success((cardNum, expiration)))
            return
        }
        
        guard index < queries.count else {
            session.invalidate(errorMessage: "未读取到银行卡号。")
            self.completion?(.failure(NSError(domain: "NFCReader", code: -4, userInfo: [NSLocalizedDescriptionKey: "无法解析银行卡号"])))
            return
        }
        
        let q = queries[index]
        let sfi = q.sfi
        let rec = q.rec
        
        let p2 = (sfi << 3) | 4
        let command = Data([0x00, 0xB2, rec, p2, 0x00])
        let apdu = NFCISO7816APDU(data: command)!
        
        tag.sendCommand(apdu: apdu) { [weak self] responseData, sw1, sw2, error in
            guard let self = self else { return }
            
            var currentCardNum = cardNum
            var currentExpiration = expiration
            
            if error == nil && sw1 == 0x90 {
                if let parsed = self.parseEMVRecord(responseData) {
                    if let pan = parsed.pan {
                        currentCardNum = pan
                    }
                    if let exp = parsed.exp {
                        currentExpiration = exp
                    }
                }
            }
            
            self.tryReadRecord(index: index + 1, queries: queries, tag: tag, session: session, cardNum: currentCardNum, expiration: currentExpiration)
        }
    }
    
    private func parseEMVRecord(_ data: Data) -> (pan: String?, exp: String?)? {
        var i = 0
        var pan: String?
        var exp: String?
        
        while i < data.count - 2 {
            let tag = data[i]
            i += 1
            
            var fullTag: UInt16 = UInt16(tag)
            if (tag & 0x1F) == 0x1F {
                let nextTag = data[i]
                fullTag = (fullTag << 8) | UInt16(nextTag)
                i += 1
            }
            
            let len = Int(data[i])
            i += 1
            
            if i + len > data.count {
                break
            }
            
            let value = data.subdata(in: i..<(i + len))
            i += len
            
            if fullTag == 0x5A {
                pan = value.hexString().replacingOccurrences(of: "F", with: "").replacingOccurrences(of: "f", with: "")
            } else if fullTag == 0x57 {
                let track2Hex = value.hexString()
                if let separatorRange = track2Hex.range(of: "D") ?? track2Hex.range(of: "d") {
                    let panPart = String(track2Hex[..<separatorRange.lowerBound])
                    let remPart = String(track2Hex[separatorRange.upperBound...])
                    pan = panPart.replacingOccurrences(of: "F", with: "").replacingOccurrences(of: "f", with: "")
                    if remPart.count >= 4 {
                        exp = String(remPart.prefix(4))
                    }
                }
            } else if fullTag == 0x5F24 {
                let expHex = value.hexString()
                if expHex.count >= 4 {
                    exp = String(expHex.prefix(4))
                }
            }
        }
        
        if pan != nil || exp != nil {
            return (pan, exp)
        }
        return nil
    }
}

extension Data {
    fileprivate func hexString() -> String {
        return map { String(format: "%02hhX", $0) }.joined()
    }
}

extension String {
    fileprivate func hexStringToData() -> Data? {
        var data = Data()
        var hex = self.replacingOccurrences(of: " ", with: "")
        while hex.count > 0 {
            let subIndex = hex.index(hex.startIndex, offsetBy: 2)
            let c = String(hex[..<subIndex])
            hex = String(hex[subIndex...])
            if let ch = UInt8(c, radix: 16) {
                data.append(ch)
            } else {
                return nil
            }
        }
        return data
    }
}
#endif
