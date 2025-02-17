//
//  ContainerResolver.swift
//  Hackle
//
//  Created by yong on 2022/07/21.
//

import Foundation

protocol ContainerResolver {
    func isUserInContainerGroup(container: Container, bucket: Bucket, experiment: Experiment, user: HackleUser) throws -> Bool
}

class DefaultContainerResolver: ContainerResolver {
    private let bucketer: Bucketer

    init(bucketer: Bucketer) {
        self.bucketer = bucketer
    }

    func isUserInContainerGroup(container: Container, bucket: Bucket, experiment: Experiment, user: HackleUser) throws -> Bool {
        guard let identifier = user.identifiers[experiment.identifierType] else {
            return false
        }
        guard let slot = bucketer.bucketing(bucket: bucket, identifier: identifier) else {
            return false
        }
        guard let containerGroup = container.getGroupOrNil(containerGroupId: slot.variationId) else {
            throw HackleError.error("ContainerGroup[\(slot.variationId)]")
        }
        return containerGroup.experiments.contains(experiment.id)
    }
}
