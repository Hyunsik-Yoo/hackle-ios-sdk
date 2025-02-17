import Foundation

@objc public final class Decision: NSObject, ParameterConfig {

    @objc public let variation: String
    @objc public let reason: String
    @objc public let config: ParameterConfig
    @objc public let parameters: [String: Any]

    internal init(variation: String, reason: String, config: ParameterConfig) {
        self.variation = variation
        self.reason = reason
        self.config = config
        self.parameters = config.parameters
    }

    internal static func of(variation: String, reason: String, config: ParameterConfig = EmptyParameterConfig.instance) -> Decision {
        Decision(variation: variation, reason: reason, config: config)
    }

    public func getString(forKey: String, defaultValue: String) -> String {
        config.getString(forKey: forKey, defaultValue: defaultValue)
    }

    public func getInt(forKey: String, defaultValue: Int) -> Int {
        config.getInt(forKey: forKey, defaultValue: defaultValue)
    }

    public func getDouble(forKey: String, defaultValue: Double) -> Double {
        config.getDouble(forKey: forKey, defaultValue: defaultValue)
    }

    public func getBool(forKey: String, defaultValue: Bool) -> Bool {
        config.getBool(forKey: forKey, defaultValue: defaultValue)
    }
}

@objc public final class FeatureFlagDecision: NSObject, ParameterConfig {

    @objc public let isOn: Bool
    @objc public let reason: String
    @objc public let config: ParameterConfig
    @objc public let parameters: [String: Any]

    init(isOn: Bool, reason: String, config: ParameterConfig) {
        self.isOn = isOn
        self.reason = reason
        self.config = config
        self.parameters = config.parameters
    }

    static func on(reason: String, config: ParameterConfig = EmptyParameterConfig.instance) -> FeatureFlagDecision {
        FeatureFlagDecision(isOn: true, reason: reason, config: config)
    }

    static func off(reason: String, config: ParameterConfig = EmptyParameterConfig.instance) -> FeatureFlagDecision {
        FeatureFlagDecision(isOn: false, reason: reason, config: config)
    }

    public func getString(forKey: String, defaultValue: String) -> String {
        config.getString(forKey: forKey, defaultValue: defaultValue)
    }

    public func getInt(forKey: String, defaultValue: Int) -> Int {
        config.getInt(forKey: forKey, defaultValue: defaultValue)
    }

    public func getDouble(forKey: String, defaultValue: Double) -> Double {
        config.getDouble(forKey: forKey, defaultValue: defaultValue)
    }

    public func getBool(forKey: String, defaultValue: Bool) -> Bool {
        config.getBool(forKey: forKey, defaultValue: defaultValue)
    }
}


class DecisionReason {

    static let SDK_NOT_READY = "SDK_NOT_READY"
    static let EXCEPTION = "EXCEPTION"
    static let INVALID_INPUT = "INVALID_INPUT"

    static let EXPERIMENT_NOT_FOUND = "EXPERIMENT_NOT_FOUND"
    static let EXPERIMENT_DRAFT = "EXPERIMENT_DRAFT"
    static let EXPERIMENT_PAUSED = "EXPERIMENT_PAUSED"
    static let EXPERIMENT_COMPLETED = "EXPERIMENT_COMPLETED"
    static let OVERRIDDEN = "OVERRIDDEN"
    static let TRAFFIC_NOT_ALLOCATED = "TRAFFIC_NOT_ALLOCATED"
    static let TRAFFIC_ALLOCATED = "TRAFFIC_ALLOCATED"
    static let NOT_IN_MUTUAL_EXCLUSION_EXPERIMENT = "NOT_IN_MUTUAL_EXCLUSION_EXPERIMENT"
    static let IDENTIFIER_NOT_FOUND = "IDENTIFIER_NOT_FOUND"
    static let VARIATION_DROPPED = "VARIATION_DROPPED"
    static let NOT_IN_EXPERIMENT_TARGET = "NOT_IN_EXPERIMENT_TARGET"

    static let FEATURE_FLAG_NOT_FOUND = "FEATURE_FLAG_NOT_FOUND"
    static let FEATURE_FLAG_INACTIVE = "FEATURE_FLAG_INACTIVE"
    static let INDIVIDUAL_TARGET_MATCH = "INDIVIDUAL_TARGET_MATCH"
    static let TARGET_RULE_MATCH = "TARGET_RULE_MATCH"
    static let DEFAULT_RULE = "DEFAULT_RULE"
}
