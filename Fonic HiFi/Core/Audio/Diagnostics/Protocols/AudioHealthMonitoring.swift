//
//  AudioHealthMonitoring.swift
//  Fonic HiFi
//
//  Focused interface for playback health, alerts, and thresholds.
//

import Combine
import Foundation

@MainActor
public protocol AudioHealthMonitoring: AnyObject, Sendable {
    var healthStatusPublisher: AnyPublisher<PlaybackHealthStatus, Never> { get }
    var alertsPublisher: AnyPublisher<PlaybackAlert, Never> { get }

    func checkPlaybackHealth() async -> PlaybackHealthStatus

    func configureAlerts(_ configuration: AlertConfiguration) async
    func getAlertConfiguration() async -> AlertConfiguration
    func evaluateAlerts() async

    func getThermalState() async -> ThermalMonitoringInfo
    func getInterruptionStatistics() async -> InterruptionStatistics
}
