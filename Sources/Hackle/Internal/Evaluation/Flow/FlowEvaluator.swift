import Foundation

protocol FlowEvaluator {
    func evaluate(
        workspace: Workspace,
        experiment: Experiment,
        user: HackleUser,
        defaultVariationKey: Variation.Key,
        nextFlow: EvaluationFlow
    ) throws -> Evaluation
}

class OverrideEvaluator: FlowEvaluator {

    private let overrideResolver: OverrideResolver

    init(overrideResolver: OverrideResolver) {
        self.overrideResolver = overrideResolver
    }

    func evaluate(
        workspace: Workspace,
        experiment: Experiment,
        user: HackleUser,
        defaultVariationKey: Variation.Key,
        nextFlow: EvaluationFlow
    ) throws -> Evaluation {
        if let overriddenVariation = try overrideResolver.resolveOrNil(workspace: workspace, experiment: experiment, user: user) {
            switch experiment.type {
            case .abTest:
                return try Evaluation.of(workspace: workspace, variation: overriddenVariation, reason: DecisionReason.OVERRIDDEN)
            case .featureFlag:
                return try Evaluation.of(workspace: workspace, variation: overriddenVariation, reason: DecisionReason.INDIVIDUAL_TARGET_MATCH)
            }
        } else {
            return try nextFlow.evaluate(workspace: workspace, experiment: experiment, user: user, defaultVariationKey: defaultVariationKey)
        }
    }
}

class DraftExperimentEvaluator: FlowEvaluator {
    func evaluate(
        workspace: Workspace,
        experiment: Experiment,
        user: HackleUser,
        defaultVariationKey: Variation.Key,
        nextFlow: EvaluationFlow
    ) throws -> Evaluation {
        if experiment.status == .draft {
            return try Evaluation.of(workspace: workspace, experiment: experiment, variationKey: defaultVariationKey, reason: DecisionReason.EXPERIMENT_DRAFT)
        } else {
            return try nextFlow.evaluate(workspace: workspace, experiment: experiment, user: user, defaultVariationKey: defaultVariationKey)
        }
    }
}

class PausedExperimentEvaluator: FlowEvaluator {
    func evaluate(
        workspace: Workspace,
        experiment: Experiment,
        user: HackleUser,
        defaultVariationKey: Variation.Key,
        nextFlow: EvaluationFlow
    ) throws -> Evaluation {
        if experiment.status == .paused {
            switch experiment.type {
            case .abTest:
                return try Evaluation.of(workspace: workspace, experiment: experiment, variationKey: defaultVariationKey, reason: DecisionReason.EXPERIMENT_PAUSED)
            case .featureFlag:
                return try Evaluation.of(workspace: workspace, experiment: experiment, variationKey: defaultVariationKey, reason: DecisionReason.FEATURE_FLAG_INACTIVE)
            }
        } else {
            return try nextFlow.evaluate(workspace: workspace, experiment: experiment, user: user, defaultVariationKey: defaultVariationKey)
        }
    }
}

class CompletedExperimentEvaluator: FlowEvaluator {
    func evaluate(
        workspace: Workspace,
        experiment: Experiment,
        user: HackleUser,
        defaultVariationKey: Variation.Key,
        nextFlow: EvaluationFlow
    ) throws -> Evaluation {
        if experiment.status == .completed {
            guard let winnerVariation = experiment.winnerVariation else {
                throw HackleError.error("winner variation [\(experiment.id)]")
            }
            return try Evaluation.of(workspace: workspace, variation: winnerVariation, reason: DecisionReason.EXPERIMENT_COMPLETED)
        } else {
            return try nextFlow.evaluate(workspace: workspace, experiment: experiment, user: user, defaultVariationKey: defaultVariationKey)
        }
    }
}

class ExperimentTargetEvaluator: FlowEvaluator {
    private let experimentTargetDeterminer: ExperimentTargetDeterminer

    init(experimentTargetDeterminer: ExperimentTargetDeterminer) {
        self.experimentTargetDeterminer = experimentTargetDeterminer
    }

    func evaluate(
        workspace: Workspace,
        experiment: Experiment,
        user: HackleUser,
        defaultVariationKey: Variation.Key,
        nextFlow: EvaluationFlow
    ) throws -> Evaluation {
        guard experiment.type == .abTest else {
            throw HackleError.error("Experiment type must be abTest [\(experiment.id)]")
        }

        let isUserInExperimentTarget = try experimentTargetDeterminer.isUserInExperimentTarget(workspace: workspace, experiment: experiment, user: user)
        if isUserInExperimentTarget {
            return try nextFlow.evaluate(workspace: workspace, experiment: experiment, user: user, defaultVariationKey: defaultVariationKey)
        } else {
            return try Evaluation.of(workspace: workspace, experiment: experiment, variationKey: defaultVariationKey, reason: DecisionReason.NOT_IN_EXPERIMENT_TARGET)
        }
    }
}

class TrafficAllocateEvaluator: FlowEvaluator {

    private let actionResolver: ActionResolver

    init(actionResolver: ActionResolver) {
        self.actionResolver = actionResolver
    }

    func evaluate(
        workspace: Workspace,
        experiment: Experiment,
        user: HackleUser,
        defaultVariationKey: Variation.Key,
        nextFlow: EvaluationFlow
    ) throws -> Evaluation {
        guard experiment.status == .running else {
            throw HackleError.error("Experiment status must be running [\(experiment.id)]")
        }

        guard experiment.type == .abTest else {
            throw HackleError.error("Experiment type must be abTest [\(experiment.id)]")
        }

        guard let variation = try actionResolver.resolveOrNil(action: experiment.defaultRule, workspace: workspace, experiment: experiment, user: user) else {
            return try Evaluation.of(workspace: workspace, experiment: experiment, variationKey: defaultVariationKey, reason: DecisionReason.TRAFFIC_NOT_ALLOCATED)
        }

        if variation.isDropped {
            return try Evaluation.of(workspace: workspace, experiment: experiment, variationKey: defaultVariationKey, reason: DecisionReason.VARIATION_DROPPED)
        }

        return try Evaluation.of(workspace: workspace, variation: variation, reason: DecisionReason.TRAFFIC_ALLOCATED)
    }
}

class TargetRuleEvaluator: FlowEvaluator {
    private let targetRuleDeterminer: TargetRuleDeterminer
    private let actionResolver: ActionResolver

    init(targetRuleDeterminer: TargetRuleDeterminer, actionResolver: ActionResolver) {
        self.targetRuleDeterminer = targetRuleDeterminer
        self.actionResolver = actionResolver
    }

    func evaluate(
        workspace: Workspace,
        experiment: Experiment,
        user: HackleUser,
        defaultVariationKey: Variation.Key,
        nextFlow: EvaluationFlow
    ) throws -> Evaluation {
        guard experiment.status == .running else {
            throw HackleError.error("Experiment status must be running [\(experiment.id)]")
        }

        guard experiment.type == .featureFlag else {
            throw HackleError.error("Experiment type must be featureFlag [\(experiment.id)]")
        }

        if user.identifiers[experiment.identifierType] == nil {
            return try nextFlow.evaluate(workspace: workspace, experiment: experiment, user: user, defaultVariationKey: defaultVariationKey)
        }

        guard let targetRule = try targetRuleDeterminer.determineTargetRuleOrNil(workspace: workspace, experiment: experiment, user: user) else {
            return try nextFlow.evaluate(workspace: workspace, experiment: experiment, user: user, defaultVariationKey: defaultVariationKey)
        }

        guard let variation = try actionResolver.resolveOrNil(action: targetRule.action, workspace: workspace, experiment: experiment, user: user) else {
            throw HackleError.error("FeatureFlag must decide the Variation [\(experiment.id)]")
        }

        return try Evaluation.of(workspace: workspace, variation: variation, reason: DecisionReason.TARGET_RULE_MATCH)
    }
}

class DefaultRuleEvaluator: FlowEvaluator {
    private let actionResolver: ActionResolver

    init(actionResolver: ActionResolver) {
        self.actionResolver = actionResolver
    }

    func evaluate(
        workspace: Workspace,
        experiment: Experiment,
        user: HackleUser,
        defaultVariationKey: Variation.Key,
        nextFlow: EvaluationFlow
    ) throws -> Evaluation {
        guard experiment.status == .running else {
            throw HackleError.error("Experiment status must be running [\(experiment.id)]")
        }

        guard experiment.type == .featureFlag else {
            throw HackleError.error("Experiment type must be featureFlag [\(experiment.id)]")
        }

        if user.identifiers[experiment.identifierType] == nil {
            return try Evaluation.of(workspace: workspace, experiment: experiment, variationKey: defaultVariationKey, reason: DecisionReason.DEFAULT_RULE)
        }

        guard let variation = try actionResolver.resolveOrNil(action: experiment.defaultRule, workspace: workspace, experiment: experiment, user: user) else {
            throw HackleError.error("FeatureFlag must decide the Variation [\(experiment.id)]")
        }

        return try Evaluation.of(workspace: workspace, variation: variation, reason: DecisionReason.DEFAULT_RULE)
    }
}

class ContainerEvaluator: FlowEvaluator {

    private let containerResolver: ContainerResolver

    init(containerResolver: ContainerResolver) {
        self.containerResolver = containerResolver
    }

    func evaluate(
        workspace: Workspace,
        experiment: Experiment,
        user: HackleUser,
        defaultVariationKey: Variation.Key,
        nextFlow: EvaluationFlow
    ) throws -> Evaluation {
        guard let containerId = experiment.containerId else {
            return try nextFlow.evaluate(workspace: workspace, experiment: experiment, user: user, defaultVariationKey: defaultVariationKey)
        }

        guard let container = workspace.getContainerOrNil(containerId: containerId) else {
            throw HackleError.error("container[\(containerId)]")
        }

        guard let bucket = workspace.getBucketOrNil(bucketId: container.bucketId) else {
            throw HackleError.error("bucket[\(container.bucketId)]")
        }

        let isUserInContainerGroup = try containerResolver.isUserInContainerGroup(container: container, bucket: bucket, experiment: experiment, user: user)
        if isUserInContainerGroup {
            return try nextFlow.evaluate(workspace: workspace, experiment: experiment, user: user, defaultVariationKey: defaultVariationKey)
        } else {
            return try Evaluation.of(workspace: workspace, experiment: experiment, variationKey: defaultVariationKey, reason: DecisionReason.NOT_IN_MUTUAL_EXCLUSION_EXPERIMENT)
        }
    }
}

class IdentifierEvaluator: FlowEvaluator {
    func evaluate(
        workspace: Workspace,
        experiment: Experiment,
        user: HackleUser,
        defaultVariationKey: Variation.Key,
        nextFlow: EvaluationFlow
    ) throws -> Evaluation {
        if user.identifiers[experiment.identifierType] != nil {
            return try nextFlow.evaluate(workspace: workspace, experiment: experiment, user: user, defaultVariationKey: defaultVariationKey)
        } else {
            return try Evaluation.of(workspace: workspace, experiment: experiment, variationKey: defaultVariationKey, reason: DecisionReason.IDENTIFIER_NOT_FOUND)
        }
    }
}
