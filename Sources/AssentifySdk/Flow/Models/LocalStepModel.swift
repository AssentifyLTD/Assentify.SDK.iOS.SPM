//
//  LocalStepModel.swift
//  Pods
//
//  Created by TariQ on 11/02/2026.
//

import Foundation


public struct LocalStepModel: Codable {

    public var name: String
    public let show: Bool
    public let description: String
    public let iconAssetPath: String
    public var isDone: Bool
    public let stepDefinition: StepDefinitions?
    public var submitRequestModel: SubmitRequestModel?

    public init(
        name: String,
        show: Bool = true,
        description: String,
        iconAssetPath: String,
        isDone: Bool = false,
        stepDefinition: StepDefinitions? = nil,
        submitRequestModel: SubmitRequestModel? = nil
    ) {
        self.name = name
        self.show = show
        self.description = description
        self.iconAssetPath = iconAssetPath
        self.isDone = isDone
        self.stepDefinition = stepDefinition
        self.submitRequestModel = submitRequestModel
    }
}
