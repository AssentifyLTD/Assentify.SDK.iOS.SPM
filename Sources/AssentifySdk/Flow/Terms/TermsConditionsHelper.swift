

func  getTermsConditionsStepFromConfigFile(
               configModel: ConfigModel,
               ID: Int,
               completion: @escaping (BaseResult<TermsConditionsModel, Error>) -> Void) {
                   let stepDefinitions = configModel.stepDefinitions
                   stepDefinitions.forEach { step in
                       if step.stepId == ID {
                           let termsConditionsModel = step.customization.toTermsConditionsModel()
                           completion(BaseResult.success(termsConditionsModel))
                       }
                   }
    
 }


extension Customization {
    func toTermsConditionsModel() -> TermsConditionsModel {
        return TermsConditionsModel(
            statusCode: 200,
            data: TermsConditionsDataModel(
                header: self.header,
                subHeader: self.subHeader,
                file: self.file,
                svgLogoUrl: self.svgLogoUrl,
                nextButtonTitle: self.nextButtonTitle,
                confirmationRequired: self.confirmationRequired,
                isNormalClick: self.isNormalClick ?? true,
            )
        )
    }
}
