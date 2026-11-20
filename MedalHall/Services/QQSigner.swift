import CryptoKit
import Foundation

/// QQ 音乐 CGI 接口的签名算法（逐字节移植自原 Node 项目）。
/// 对 payload 的 UTF-8 字节做 SHA1，取固定下标拼前后缀，中间 20 字节与固定表异或后 Base64 并去掉 + / =。
enum QQSigner {
    static let part1Indexes = [23, 14, 6, 36, 16, 7, 19]
    static let part2Indexes = [16, 1, 32, 12, 19, 27, 8, 5]
    static let scrambleValues: [UInt8] = [
        89, 39, 179, 150, 218, 82, 58, 252, 177, 52,
        186, 123, 120, 64, 242, 133, 143, 161, 121, 179
    ]

    static func sign(_ payload: String) -> String {
        sign(Data(payload.utf8))
    }

    static func sign(_ payload: Data) -> String {
        let digest = Insecure.SHA1.hash(data: payload)
        let hex = digest.map { String(format: "%02X", $0) }.joined()
        let characters = Array(hex)

        var first = ""
        for index in part1Indexes where index < characters.count {
            first.append(characters[index])
        }

        var second = ""
        for index in part2Indexes where index < characters.count {
            second.append(characters[index])
        }

        var scrambled = [UInt8](repeating: 0, count: 20)
        for index in 0..<20 {
            let start = index * 2
            let end = start + 2
            guard end <= characters.count,
                  let byte = UInt8(String(characters[start..<end]), radix: 16) else {
                scrambled[index] = scrambleValues[index]
                continue
            }
            scrambled[index] = scrambleValues[index] ^ byte
        }

        let base64 = Data(scrambled).base64EncodedString()
        let forbidden: Set<Character> = ["\\", "/", "+", "="]
        let cleaned = String(base64.filter { !forbidden.contains($0) })

        return ("zzc" + first + cleaned + second).lowercased()
    }
}
