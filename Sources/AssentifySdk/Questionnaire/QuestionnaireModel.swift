//
//  QuestionnaireModel.swift
//  AssentifySdk
//
//  Created by TariQ on 30/09/2026.
//

public struct QuestionnaireModel: Codable {
    public let header: String?
    public let subHeader: String?
    public let svgLogoUrl: String?
    public let questions: [QuestionModel]?
    public let nextButtonTitle: String?
    public let isNormalClick: Bool?
}

public struct QuestionModel: Codable {
    public let title: String
    public let subTitle: String?
    public let weight: Int
    public let image: String?
    public let keyProperty: String
    public let keyPropertyIdentifier: String
    public let valueProperty: String
    public let valuePropertyIdentifier: String
    public let value: String
    public let allowMultipleAnswers: Bool
    public let answers: [AnswerModel]
}

public struct AnswerModel: Codable {
    public let key: String
    public let value: String
    public let weight: Int
}
