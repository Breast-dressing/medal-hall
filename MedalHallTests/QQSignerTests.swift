import XCTest
@testable import MedalHall

/// 签名算法必须与原 Node 实现逐字节一致（期望值由原实现生成）。
final class QQSignerTests: XCTestCase {
    func testEmptyPayload() {
        XCTAssertEqual(QQSigner.sign(""), "zzcf0e03e5gx4qeiq5cfgdyqwu7sdqfsb5fro3aa45053")
    }

    func testRankModulePayload() {
        let payload = """
        {"comm":{},"req_0":{"module":"music.medalHall.MedalRankListSrv","method":"GetRankModule","param":{"MedalID":"3069960","FirstPageSize":20,"From":1,"Target":""}}}
        """
        XCTAssertEqual(
            QQSigner.sign(payload),
            "zzc3933244zx5kovp4z2aa8aeolc6kia0qt8m2c254e27"
        )
    }

    func testSkinShowListPayload() {
        let payload = """
        {"comm":{},"req_0":{"module":"music.medalSkin.MedalSkinHomepageSrv","method":"GetSkinShowList","param":{"MedalID":"3069960","ShowPos":1,"PageSize":4,"Cursor":"","EncUin":"o1234567890"}}}
        """
        XCTAssertEqual(
            QQSigner.sign(payload),
            "zzcecb383erdq6jwtdhtww2klv1ndv0xzdrs485f2e7b9"
        )
    }

    func testUTF8Payload() {
        XCTAssertEqual(QQSigner.sign("中文测试"), "zzca68a9fdlq09gblm2jsjoqbxj3dfnyng1mo9f0ed06e")
    }

    func testDataAndStringOverloadsAgree() {
        let payload = "{\"a\":1}"
        XCTAssertEqual(QQSigner.sign(payload), QQSigner.sign(Data(payload.utf8)))
    }
}
