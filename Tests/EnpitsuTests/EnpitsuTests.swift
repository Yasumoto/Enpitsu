import XCTest
@testable import Enpitsu

class EnpitsuTests: XCTestCase {
    func testExample() {
        let grafana = Enpitsu(graphiteServer: "https://localhost")
        try? grafana.client.syncShutdown()
    }


    static var allTests = [
        ("testExample", testExample),
    ]
}
