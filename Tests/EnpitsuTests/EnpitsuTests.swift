import XCTest
@testable import Enpitsu

class EnpitsuTests: XCTestCase {
    func testExample() {
        let _ = Enpitsu(graphiteServer: "https://localhost")
    }


    static var allTests = [
        ("testExample", testExample),
    ]
}
