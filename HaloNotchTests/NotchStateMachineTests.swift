import XCTest
@testable import HaloNotch

/// The notch state machine is pure value logic, so it is tested without any UI.
final class NotchStateMachineTests: XCTestCase {
    func testHoverOpensFromClosed() {
        XCTAssertEqual(NotchState.closed.reduce(.mouseEntered), .hovered)
    }

    func testClickFromHoverOpens() {
        XCTAssertEqual(NotchState.hovered.reduce(.clicked), .open)
    }

    func testExitFromHoverCloses() {
        XCTAssertEqual(NotchState.hovered.reduce(.mouseExited), .closed)
    }

    func testOpenStaysOpenOnMouseExit() {
        XCTAssertEqual(NotchState.open.reduce(.mouseExited), .open)
    }

    func testOpenClosesOnDismiss() {
        XCTAssertEqual(NotchState.open.reduce(.dismissed), .closed)
    }

    func testUnhandledEventIsNoOp() {
        XCTAssertEqual(NotchState.closed.reduce(.dismissed), .closed)
    }

    func testViewModelDrivesState() {
        let vm = NotchViewModel()
        XCTAssertEqual(vm.state, .closed)
        vm.send(.mouseEntered); XCTAssertEqual(vm.state, .hovered)
        vm.send(.clicked);      XCTAssertEqual(vm.state, .open)
        vm.send(.dismissed);    XCTAssertEqual(vm.state, .closed)
        XCTAssertEqual(vm.parallax, .zero)
    }
}
