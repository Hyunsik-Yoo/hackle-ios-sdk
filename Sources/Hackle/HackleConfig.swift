//
//  HackleConfig.swift
//  Hackle
//
//  Created by yong on 2022/08/12.
//

import Foundation

public class HackleConfig: NSObject {

    var sdkUrl: URL
    var eventUrl: URL
    var eventFlushInterval: TimeInterval
    var eventFlushThreshold: Int
    var exposureEventDedupInterval: TimeInterval

    public init(
        sdkUrl: URL,
        eventUrl: URL,
        eventFlushInterval: TimeInterval,
        eventFlushThreshold: Int,
        exposureEventDedupInterval: TimeInterval
    ) {
        self.sdkUrl = sdkUrl
        self.eventUrl = eventUrl
        self.eventFlushInterval = eventFlushInterval
        self.eventFlushThreshold = eventFlushThreshold
        self.exposureEventDedupInterval = exposureEventDedupInterval
        super.init()
    }

    static let NO_DEDUP: TimeInterval = -1

    static let DEFAULT_EVENT_FLUSH_INTERVAL: TimeInterval = 10
    static let DEFAULT_EVENT_FLUSH_THRESHOLD = 10
    static let DEFAULT_EVENT_REPOSITORY_MAX_SIZE = 1000
    static let DEFAULT_EXPOSURE_EVENT_DEDUP_INTERVAL: TimeInterval = 60

    @objc public static let DEFAULT: HackleConfig = builder().build()

    @objc public static func builder() -> HackleConfigBuilder {
        HackleConfigBuilder()
    }
}

public class HackleConfigBuilder: NSObject {

    var sdkUrl: URL = URL(string: "https://sdk.hackle.io")!
    var eventUrl: URL = URL(string: "https://event.hackle.io")!

    var eventFlushInterval: TimeInterval = HackleConfig.DEFAULT_EVENT_FLUSH_INTERVAL
    var eventFlushThreshold: Int = HackleConfig.DEFAULT_EVENT_FLUSH_THRESHOLD

    var exposureEventDedupInterval: TimeInterval = HackleConfig.DEFAULT_EXPOSURE_EVENT_DEDUP_INTERVAL

    @objc public func sdkUrl(_ sdkUrl: URL) -> HackleConfigBuilder {
        self.sdkUrl = sdkUrl
        return self
    }

    @objc public func eventUrl(_ eventUrl: URL) -> HackleConfigBuilder {
        self.eventUrl = eventUrl
        return self
    }

    @objc public func eventFlushIntervalSeconds(_ eventFlushInterval: TimeInterval) -> HackleConfigBuilder {
        self.eventFlushInterval = eventFlushInterval
        return self
    }

    @objc public func eventFlushThreshold(_ eventFlushThreshold: Int) -> HackleConfigBuilder {
        self.eventFlushThreshold = eventFlushThreshold
        return self
    }

    @objc public func exposureEventDedupIntervalSeconds(_ exposureEventDedupInterval: TimeInterval) -> HackleConfigBuilder {
        self.exposureEventDedupInterval = exposureEventDedupInterval
        return self
    }

    @objc public func build() -> HackleConfig {

        if !(1...60).contains(eventFlushInterval) {
            Log.info("Event flush interval is outside allowed range[1s..60s]. Setting to default value[10s]")
            self.eventFlushInterval = HackleConfig.DEFAULT_EVENT_FLUSH_INTERVAL
        }

        if !(5...30).contains(eventFlushThreshold) {
            Log.info("Event flush threshold is outside allowed range[5..30]. Setting to default value[10]")
            self.eventFlushThreshold = HackleConfig.DEFAULT_EVENT_FLUSH_THRESHOLD
        }

        if exposureEventDedupInterval != HackleConfig.NO_DEDUP && !(1...3600).contains(exposureEventDedupInterval) {
            Log.info("Exposure event dedup interval is outside allowed range[1s..3600s]. Setting to default value[60s].")
            self.exposureEventDedupInterval = HackleConfig.DEFAULT_EXPOSURE_EVENT_DEDUP_INTERVAL
        }

        return HackleConfig(
            sdkUrl: sdkUrl,
            eventUrl: eventUrl,
            eventFlushInterval: eventFlushInterval,
            eventFlushThreshold: eventFlushThreshold,
            exposureEventDedupInterval: exposureEventDedupInterval
        )
    }
}
