//
//  CryptoUtils.swift
//  BIT101-macOS
//
//  Created by wyr on 2026/8/3.
//

import Foundation
import CryptoKit

extension String {
    /// 将字符串转为 32 位小写 MD5
    var md5: String {
        let digest = Insecure.MD5.hash(data: Data(self.utf8))
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}

/// BIT 学校统一身份认证 EncryptPassword 加密
/// 对应前端 EncryptPassword.ts：AES-ECB + PKCS7 padding，key 为 salt 的 base64 解码
/// 使用 CommonCrypto（通过 Bridging Header 引入）
func encryptPasswordAES(password: String, salt: String) -> String? {
    guard let keyData = Data(base64Encoded: salt) else {
        print("❌ AES: salt base64 解码失败")
        return nil
    }
    guard let passwordData = password.data(using: .utf8) else {
        print("❌ AES: 密码转 data 失败")
        return nil
    }
    
    let keyLength = keyData.count
    let blockSize = kCCBlockSizeAES128
    var bufferSize = passwordData.count + blockSize
    var buffer = Data(count: bufferSize)
    var numBytesEncrypted: Int = 0
    
    let status = keyData.withUnsafeBytes { keyBytes in
        passwordData.withUnsafeBytes { dataBytes in
            buffer.withUnsafeMutableBytes { bufferBytes in
                CCCrypt(
                    CCOperation(kCCEncrypt),
                    CCAlgorithm(kCCAlgorithmAES),
                    CCOptions(kCCOptionECBMode | kCCOptionPKCS7Padding),
                    keyBytes.baseAddress, keyLength,
                    nil,  // ECB 模式不需要 IV
                    dataBytes.baseAddress, passwordData.count,
                    bufferBytes.baseAddress, bufferSize,
                    &numBytesEncrypted
                )
            }
        }
    }
    
    guard status == kCCSuccess else {
        print("❌ AES 加密失败，status: \(status)")
        return nil
    }
    
    buffer.removeSubrange(numBytesEncrypted..<buffer.count)
    return buffer.base64EncodedString()
}
