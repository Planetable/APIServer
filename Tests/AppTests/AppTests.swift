@testable import App
import XCTVapor

final class AppTests: XCTestCase {
    func testENSResolve() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        try app.test(.GET, "ens/resolve/vitalik.eth", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertContains(res.body.string, "6045")
        })

        try app.test(.GET, "ens/resolve/jango.eth", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertContains(res.body.string, "juiceboxProjectID")
            XCTAssertContains(res.body.string, "55")
        })
    }
}
