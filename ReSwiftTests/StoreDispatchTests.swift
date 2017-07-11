//
//  StoreDispatchTests.swift
//  ReSwift
//
//  Created by Karl Bowden on 20/07/2016.
//  Copyright © 2016 Benjamin Encz. All rights reserved.
//

import XCTest
import ReSwift

class StoreDispatchTests: XCTestCase {

    typealias TestSubscriber = TestStoreSubscriber<TestAppState>
    typealias CallbackSubscriber = CallbackStoreSubscriber<TestAppState>

    var store: Store<TestAppState>!
    var reducer: TestReducer!

    override func setUp() {
        super.setUp()
        reducer = TestReducer()
        store = Store(reducer: reducer.handleAction, state: TestAppState())
    }

    /**
     it accepts actions coming from multiple threads and handles them synchronously
     */
    func testDispatchInMultipleThreadsAreSynchronized() {
        store.dispatch(SetValueAction(5))

        let firstAction = DelayedAction(3)
        let secondAction = DelayedAction(10)
        dispatchAsync {
            self.store.dispatch(firstAction)
        }

        dispatchAsync {
            self.store.dispatch(secondAction)
        }

        XCTAssertFalse(secondAction.called)
        waitFor { firstAction.called == true }

        XCTAssertEqual(store.state.testValue, 5)
        firstAction.unblock()

        waitFor { store.state.testValue == 3 }

        waitFor { secondAction.called == true }
        secondAction.unblock()

        waitFor { store.state.testValue == 10 }
    }

    /**
     it accepts action creators
     */
    func testAcceptsActionCreators() {
        store.dispatch(SetValueAction(5))

        let doubleValueActionCreator: Store<TestAppState>.ActionCreator = { state, store in
            return SetValueAction(state.testValue! * 2)
        }

        store.dispatch(doubleValueActionCreator)

        XCTAssertEqual(store.state.testValue, 10)
    }

    /**
     it accepts async action creators
     */
    func testAcceptsAsyncActionCreators() {

        let asyncExpectation = futureExpectation(
            withDescription: "It accepts async action creators")

        let asyncActionCreator: Store<TestAppState>.AsyncActionCreator = { _, _, callback in
            dispatchAsync {
                // Provide the callback with an action creator
                callback { _, _ in
                    return SetValueAction(5)
                }
            }
        }

        let subscriber = CallbackSubscriber { [unowned self] state in
            if self.store.state.testValue != nil {
                XCTAssertEqual(self.store.state.testValue, 5)
                asyncExpectation.fulfill()
            }
        }

        store.subscribe(subscriber)
        store.dispatch(asyncActionCreator)
        waitForFutureExpectations(withTimeout: 1) { error in
            if let error = error {
                XCTFail("waitForExpectationsWithTimeout errored: \(error)")
            }
        }
    }

    /**
     it calls the callback once state update from async action is complete
     */
    func testCallsCalbackOnce() {
        let asyncExpectation = futureExpectation(withDescription:
            "It calls the callback once state update from async action is complete")

        let asyncActionCreator: Store<TestAppState>.AsyncActionCreator = { _, _, callback in
            dispatchAsync {
                // Provide the callback with an action creator
                callback { _, _ in
                    return SetValueAction(5)
                }
            }
        }

        store.dispatch(asyncActionCreator) { newState in
            XCTAssertEqual(self.store.state.testValue, 5)
            if newState.testValue == 5 {
                asyncExpectation.fulfill()
            }
        }

        waitForFutureExpectations(withTimeout: 1) { error in
            if let error = error {
                XCTFail("waitForExpectationsWithTimeout errored: \(error)")
            }
        }
    }

    func waitFor(timeout: TimeInterval = 1,
                 file: StaticString = #file,
                 line: UInt = #line,
                 block: () -> Bool) {
        let maxTime = Date().addingTimeInterval(timeout).timeIntervalSince1970
        while Date().timeIntervalSince1970 < maxTime {
            if block() { return }
        }
        XCTFail("Timed out waiting for condition to be true", file: file, line: line)
    }
}

// Needs to be class so that shared reference can be modified to inject store
class DispatchingReducer: XCTestCase {
    var store: Store<TestAppState>?

    func handleAction(action: Action, state: TestAppState?) -> TestAppState {
        expectFatalError {
            self.store?.dispatch(SetValueAction(20))
        }
        return state ?? TestAppState()
    }
}
