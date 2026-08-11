import Combine
import Foundation
import Synchronization
import Testing

@testable import Fonic_HiFi

@Suite("Playback Health Event Log")
struct PlaybackHealthEventLogTests {
    @Test("Publishes the bounded timeline after each append")
    @MainActor
    func publishesTimelineAfterEachAppend() {
        let log = PlaybackHealthEventLog(capacity: 2)
        var snapshots: [[PlaybackHealthEvent.Kind]] = []
        let cancellable = log.eventsPublisher.sink { events in
            snapshots.append(events.map(\.kind))
        }

        log.record(.mediaServicesResetDetected)
        log.record(.mediaServicesResetRecoverySucceeded)
        log.record(.mediaServicesResetRecoveryFailed)

        #expect(snapshots == [
            [],
            [.mediaServicesResetDetected],
            [.mediaServicesResetDetected, .mediaServicesResetRecoverySucceeded],
            [.mediaServicesResetRecoverySucceeded, .mediaServicesResetRecoveryFailed],
        ])
        withExtendedLifetime(cancellable) {}
    }

    @Test("Records events oldest-to-newest with injected timestamps")
    @MainActor
    func recordsEventsInOrder() {
        let tick = Mutex(0.0)
        let log = PlaybackHealthEventLog(capacity: 10, nowProvider: {
            tick.withLock { value in
                value += 1
                return Date(timeIntervalSince1970: value)
            }
        })

        log.record(.mediaServicesResetDetected)
        log.record(.mediaServicesResetRecoverySucceeded, detail: "position=12.500")

        let events = log.events
        #expect(events.map(\.kind) == [
            .mediaServicesResetDetected,
            .mediaServicesResetRecoverySucceeded,
        ])
        #expect(events[0].timestamp < events[1].timestamp)
        #expect(events[0].detail == nil)
        #expect(events[1].detail == "position=12.500")
    }

    @Test("Trims oldest events beyond capacity")
    @MainActor
    func trimsOldestEventsBeyondCapacity() {
        let log = PlaybackHealthEventLog(capacity: 3)

        for _ in 0 ..< 4 {
            log.record(.mediaServicesResetDetected)
        }
        log.record(.mediaServicesResetRecoveryFailed, detail: "reason=AudioError")

        let events = log.events
        #expect(events.count == 3)
        #expect(events.last?.kind == .mediaServicesResetRecoveryFailed)
        #expect(events.last?.detail == "reason=AudioError")
        #expect(Set(events.map(\.id)).count == events.count)
    }

    @Test("Capacity clamps to a minimum of one event")
    @MainActor
    func capacityClampsToMinimumOne() {
        let log = PlaybackHealthEventLog(capacity: 0)

        log.record(.mediaServicesResetDetected)
        log.record(.mediaServicesResetRecoverySucceeded)

        #expect(log.events.map(\.kind) == [.mediaServicesResetRecoverySucceeded])
    }
}
