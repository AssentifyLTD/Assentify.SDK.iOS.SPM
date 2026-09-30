//
//  QuestionnaireDelegate.swift
//  AssentifySdk
//
//  Created by TariQ on 30/09/2026.
//


public protocol QuestionnaireDelegate {
    func onQuestionnaireCallbackError(message: String)
    func onQuestionnaireCallbackSuccess(questionnaireModel: QuestionnaireModel)
    
}
