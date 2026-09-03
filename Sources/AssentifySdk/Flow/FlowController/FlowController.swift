import UIKit
import SwiftUI

public final class FlowController {
    
    public var wrapUpStepID: Int = -1;

    
    private weak var navigationController: UINavigationController?
    private var flowDelegate:FlowDelegate?
    
    private let timeStarted :String = getCurrentDateTimeForTracking();
    
    public init(navigationController: UINavigationController,flowDelegate:FlowDelegate) {
        self.navigationController = navigationController
        self.flowDelegate = flowDelegate
    }
    
    private var flowLayoutDirection: LayoutDirection {
        BaseTheme.baseUiLanguage == UiLanguage.Arabic ? .rightToLeft : .leftToRight
    }

    private func applySemanticDirection() {
        guard let nav = navigationController else { return }
        let attr: UISemanticContentAttribute = BaseTheme.baseUiLanguage == UiLanguage.Arabic ? .forceRightToLeft : .forceLeftToRight
        nav.view.semanticContentAttribute = attr
        nav.navigationBar.semanticContentAttribute = attr
    }

    public func push<V: View>(_ screen: V, animated: Bool = true) {
        guard let nav = navigationController else { return }
        applySemanticDirection()
        let vc = UIHostingController(rootView: screen.environment(\.layoutDirection, flowLayoutDirection))
        nav.pushViewController(vc, animated: animated)
    }
    
    public func pop(animated: Bool = true) {
        navigationController?.popViewController(animated: animated)
    }
    
    public func dismiss(animated: Bool = true) {
        navigationController?.dismiss(animated: animated)
    }
    
    public func setRoot( animated: Bool = false) {
        applySemanticDirection()
        let vc = UIHostingController(rootView: BlockLoaderScreen(flowController: self).environment(\.layoutDirection, flowLayoutDirection))
        navigationController?.setViewControllers([vc], animated: animated)
    }
    
    public func endFlow(animated: Bool = false,flowData: [FlowCompletedModel]) {
        self.flowDelegate?.onFlowCompleted(flowData:flowData)
        self.dismiss(animated: animated)
    }
    
    public func naveToNextStep() {
        wrapUpStepID = -1;
        checkDataRelayStepAndMoveNext();
    }
    
    
    public func checkDataRelayStepAndMoveNext(){
        
        guard let currentStep = getCurrentStep(),
              currentStep.stepDefinition?.stepDefinition == StepsNames.dataRelay else {
            chekSplitStepAndMoveNext();
            return
        }
        
        let apiKey = ApiKeyObject.shared.get()
        let timeStarted = getCurrentDateTimeForTracking()
        let configModel = ConfigModelObject.shared.get()
        let allDoneSteps = getAllDoneSteps();
        let stepId = currentStep.stepDefinition!.stepId
        var results: [String: String] = [:]
        allDoneSteps.forEach { step in
            results.merge(step.submitRequestModel!.extractedInformation) { _, new in new }
        }
        
        let alert = UIAlertController(
            title: FlowStrings.dataRelayDialogTitle,
            message: FlowStrings.dataRelayDialogMessage,
            preferredStyle: .alert
        )

        if let title = alert.title {
            let attributedTitle = NSAttributedString(
                string: title,
                attributes: [.foregroundColor: BaseTheme.baseTextColor]
            )
            alert.setValue(attributedTitle, forKey: "attributedTitle")
        }

        if let message = alert.message {
            let attributedMessage = NSAttributedString(
                string: message,
                attributes: [.foregroundColor: BaseTheme.baseTextColor]
            )
            alert.setValue(attributedMessage, forKey: "attributedMessage")
        }
        
        if let bgView = alert.view.subviews.first?.subviews.first {
            bgView.backgroundColor = BaseTheme.fieldColor
        }
        
        if let bgView = alert.view.subviews.first?.subviews.first {
                   bgView.backgroundColor = BaseTheme.fieldColor
                   bgView.layer.cornerRadius = 14        // ← corner radius
                   bgView.clipsToBounds = true            // ← makes the radius actually clip content
          }

        DispatchQueue.main.async {
            self.topViewController()?.present(alert, animated: true) {
            }
        }
        

        let components = URLComponents(
               string: BaseUrls.baseURLGateway + "v1/Manager/GetStepCachedContent/\(stepId)"
         )
        
        guard let url = components?.url else {
            DispatchQueue.main.async {
                self.topViewController()?.dismiss(animated: true)
                self.makeCurrentStepDone(extractedInformation: [:], timeStarted: timeStarted)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.chekSplitStepAndMoveNext()
                }
            }
            return
        }
        
        var request = URLRequest(url: url)
            request.httpMethod = "POST"

            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
            request.setValue(configModel!.blockIdentifier, forHTTPHeaderField: "X-Block-Identifier")
            request.setValue(configModel!.flowIdentifier, forHTTPHeaderField: "X-Flow-Identifier")
            request.setValue(configModel!.tenantIdentifier, forHTTPHeaderField: "X-Tenant-Identifier")

            do {
                request.httpBody = try JSONEncoder().encode(results)
            } catch {
                DispatchQueue.main.async {
                    self.topViewController()?.dismiss(animated: true)
                    self.makeCurrentStepDone(extractedInformation: [:], timeStarted: timeStarted)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.chekSplitStepAndMoveNext()
                    }
                }
                return
            }

            let task = URLSession.shared.dataTask(with: request) { data, response, error in

               
                var resultMap: [String: String] = [:]
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200,
                 let responseData = data {

                   
                    if let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] {
                        resultMap = json.mapValues { "\($0)" }
                    }
                    DispatchQueue.main.async {
                        self.topViewController()?.dismiss(animated: true)
                        self.makeCurrentStepDone(extractedInformation: resultMap, timeStarted: timeStarted)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                self.chekSplitStepAndMoveNext()
                            }
                    }

                } else {
                    DispatchQueue.main.async {
                        self.topViewController()?.dismiss(animated: true)
                        self.makeCurrentStepDone(extractedInformation: resultMap, timeStarted: timeStarted)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                self.chekSplitStepAndMoveNext()
                        }
                    }
                }
                
                
            }

            task.resume()
        
        
        
      

    }
    
    func topViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
            let window = windowScene.windows.first(where: { $0.isKeyWindow }),
            var top = window.rootViewController
        else { return nil }

        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
    
    
    
    public  func chekSplitStepAndMoveNext() {
        let timeStarted = getCurrentDateTimeForTracking()
        
        guard let currentStep = getCurrentStep(),
              currentStep.stepDefinition?.stepDefinition == StepsNames.split else {
            moveNext()
            return
        }
        
        let branches = currentStep.stepDefinition?.customization.branches ?? []
        
        let matchedBranch =
            branches
            .filter { !($0.conditions.isEmpty) }
                .first(where: { ConditionEvaluator.evaluateBranch(branch: $0, flowController: self) })
        ?? branches.first(where: { $0.conditions.isEmpty })
        
        
        guard let branch = matchedBranch,
              let configModelObject = ConfigModelObject.shared.get(),
              let splitStep = configModelObject.stepMap.first(where: { $0.id == currentStep.stepDefinition?.stepId }),
              branch.branchIndex < splitStep.branches!.count else {
            moveNext()
            return
        }

        let splitBranches = splitStep.branches
        
        makeCurrentStepDone(extractedInformation: [:], timeStarted: timeStarted)
        
        var steps = LocalStepsObject.shared.get()
        var newItems: [LocalStepModel] = []
        
        let selectedBranchSteps = splitBranches![branch.branchIndex]
        let hasWrapUp = selectedBranchSteps.first(where: { $0.stepDefinition == StepsNames.wrapUp })
        
        if hasWrapUp != nil {
            steps.removeAll(where: { !$0.isDone })
            wrapUpStepID = hasWrapUp?.id ?? -1
        }
        
        let insertIndex = steps.firstIndex(where: { !$0.isDone }) ?? steps.count
        var displayCounter = steps.filter { $0.show && $0.isDone }.count + 1
        
        for splitBranch in selectedBranchSteps {
            guard splitBranch.stepDefinition != StepsNames.wrapUp else { continue }
            let def = splitBranch.stepDefinition

            guard let meta = getStepMeta(def),
                  let matchedStepDefinition = configModelObject.stepDefinitions.first(where: { $0.stepId == splitBranch.id }) else {
                continue
            }
            
            newItems.append(
                LocalStepModel(
                    name: FlowStrings.stepLabel(number: displayCounter, name: meta.name),
                    description: meta.description,
                    iconAssetPath: meta.icon,
                    isDone: false,
                    stepDefinition: matchedStepDefinition,
                    submitRequestModel: SubmitRequestModel(
                        stepId: matchedStepDefinition.stepId,
                        stepDefinition: matchedStepDefinition.stepDefinition,
                        extractedInformation: [:]
                    )
                )
            )
            displayCounter += 1
        }
        
        steps.insert(contentsOf: newItems, at: insertIndex)
        
        var newCounter = 1
        for i in steps.indices {
            if steps[i].show,
               let stepDef = steps[i].stepDefinition?.stepDefinition,
               let meta = getStepMeta(stepDef) {
                steps[i].name = FlowStrings.stepLabel(number: newCounter, name: meta.name)
                newCounter += 1
            }
        }
        
        LocalStepsObject.shared.set(steps)
        moveNext()
    }
    
    public func moveNext(){
        let currentStep = getCurrentStep()
        
        guard let currentStep else {
            push(SubmitStepScreen(flowController: self))
            return
        }
        
        switch currentStep.stepDefinition?.stepDefinition {
            
        case StepsNames.termsConditions:
            push(TermsAndConditionsScreen(flowController: self))
            
        case StepsNames.identificationDocumentCapture:
            push(IDStepScreen(flowController: self))
            
        case StepsNames.faceImageAcquisition:
            push(HowToCaptureFaceScreen(flowController: self))
            
        case StepsNames.assistedDataEntry:
            push(AssistedDataEntryScreen(flowController: self))
            
        case StepsNames.contextAwareSigning:
            push(MultipleFilesContextAwareScreen(flowController: self))
            
        default:
            push(SubmitStepScreen(flowController: self))
        }
    }
    
    
    
    
    public func getCurrentStep() -> LocalStepModel? {
        let steps = LocalStepsObject.shared.get()
        return steps.first { $0.isDone == false }
    }
    
    public func makeCurrentStepDone(extractedInformation: [String: String],  timeStarted :String,) {
        
        var steps = LocalStepsObject.shared.get()
        
        guard let currentIndex = steps.firstIndex(where: { $0.isDone == false }) else { return }
        
        var currentStep = steps[currentIndex]
        
        let nextStep: LocalStepModel? = {
            let nextIndex = currentIndex + 1
            return nextIndex < steps.count ? steps[nextIndex] : nil
        }()
        
        /** Track Progress **/
        trackProgress(
            currentStep : currentStep,
            inputData : extractedInformation,
            response : nil,
            status : "Completed"
        )
        
        /** Track Next **/
        trackNext(currentStep:currentStep , nextStep: nextStep,timeStarted: timeStarted)
        
        var submitRequestModel = currentStep.submitRequestModel
        submitRequestModel?.extractedInformation = extractedInformation
        
        currentStep.isDone = true
        currentStep.submitRequestModel = submitRequestModel
        
        steps[currentIndex] = currentStep
        LocalStepsObject.shared.set(steps)
        
        
        if(currentStep.stepDefinition!.stepDefinition != StepsNames.split){
            if let submitModel = currentStep.submitRequestModel {
                
                var stepData: [String: String] = [:]
                
                for (key, value) in submitModel.extractedInformation {
                    if !key.contains("IsDirty") {
                        
                        if(key.contains("OnBoardMe_Property")){
                            let keys = key.split(separator: "_").map { String($0) }
                            let newKey = key.components(separatedBy: "OnBoardMe_Property_").last?.components(separatedBy: "_").joined(separator: " ") ?? ""
                            
                            stepData[newKey] = value
                        }else{
                            let keys = key.split(separator: "_").map { String($0) }
                            let newKey = key.components(separatedBy: "\(submitModel.stepDefinition)_").last?.components(separatedBy: "_").joined(separator: " ") ?? ""
                            
                            stepData[newKey] = value
                        }
                        
                        
                    }
                }
                
                flowDelegate?.onStepCompleted(stepModel:
                    FlowCompletedModel(
                        stepData: stepData,
                        submitRequestModel: submitModel
                    )
                )
            }
        }
        
    }
    
    public func backClick() {
        setRoot(animated: true)
    }
    
    
    public  func getFaceMatchInputImageKey() -> String {
        
        let key = ConstantsValues.providedFaceImageKey
        let currentStep = getCurrentStep()
        let steps = LocalStepsObject.shared.get()
        
        // Find FaceImageAcquisition step
        guard let faceStep = steps.first(where: {
            $0.stepDefinition?.stepDefinition == StepsNames.faceImageAcquisition
        }),
              let stepDefinition = faceStep.stepDefinition,
              !stepDefinition.inputProperties.isEmpty,
              let currentStepId = currentStep?.stepDefinition?.stepId
        else {
            return key
        }
        
        guard !stepDefinition.inputProperties.isEmpty else {
            return key
        }

        for input in stepDefinition.inputProperties {
            if input.sourceStepId == currentStepId {
                return input.sourceKey
            }
        }

        return ConstantsValues.providedFaceImageKey
    }
    
    public  func  setImage(url: String) {
        IDImageObject.shared.clear();
        IDImageObject.shared.setImage(url)
    }
    
    public  func  getPreviousIDImage() -> String {
        return IDImageObject.shared.getImage() ?? ""
    }
    
    public func faceIDChange() {
        var steps = LocalStepsObject.shared.get()
        
        if let index = steps.firstIndex(where: {
            $0.stepDefinition?.stepDefinition == StepsNames.identificationDocumentCapture
        }) {
            steps[index].isDone = false
        }
        
        LocalStepsObject.shared.set(steps)
    }

    public func getAllDoneSteps() -> [LocalStepModel] {
        let steps = LocalStepsObject.shared.get() ?? []
        return steps.filter { $0.isDone }
    }
    
    
    public func getFlowCompletedList() -> [FlowCompletedModel] {
        
        let steps = LocalStepsObject.shared.get() ?? []
        var flowCompletedList: [FlowCompletedModel] = []
        
        // 1) Collect FlowCompletedModel from local steps
        for step in steps {
            if(step.stepDefinition!.stepDefinition != StepsNames.split){
                if let submitModel = step.submitRequestModel {
                    
                    var stepData: [String: String] = [:]
                    
                    for (key, value) in submitModel.extractedInformation {
                        if !key.contains("IsDirty") {
                            
                            if(key.contains("OnBoardMe_Property")){
                                let keys = key.split(separator: "_").map { String($0) }
                                let newKey = key.components(separatedBy: "OnBoardMe_Property_").last?.components(separatedBy: "_").joined(separator: " ") ?? ""
                                
                                stepData[newKey] = value
                            }else{
                                let keys = key.split(separator: "_").map { String($0) }
                                let newKey = key.components(separatedBy: "\(submitModel.stepDefinition)_").last?.components(separatedBy: "_").joined(separator: " ") ?? ""
                                
                                stepData[newKey] = value
                            }
                            
                            
                        }
                    }
                    
                    flowCompletedList.append(
                        FlowCompletedModel(
                            stepData: stepData,
                            submitRequestModel: submitModel
                        )
                    )
                }
            }
        }
        
        // 2) Build WrapUp SubmitRequestModel (TimeEnded)
        var wrapUp: SubmitRequestModel? = nil
        let initSteps = ConfigModelObject.shared.get()!.stepDefinitions
        let initStepsMap = ConfigModelObject.shared.get()?.stepMap.first {
            $0.stepDefinition == StepsNames.wrapUp
        }
        for item in initSteps {
            if item.stepId == initStepsMap?.id {
                
                var values: [String: String] = [:]
                
                for property in item.outputProperties {
                    if property.key.contains(WrapUpKeys.timeEnded) {
                        values[property.key] = getTimeUTC()
                    }
                }
                
                wrapUp = SubmitRequestModel(
                    stepId: item.stepId,
                    stepDefinition: StepsNames.wrapUp,
                    extractedInformation: values
                )
                
                break
            }
        }
        
        // 3) Convert WrapUp extractedInformation to stepData and append
        if let wrapUp = wrapUp {
            var stepData: [String: String] = [:]
            
            for (key, value) in wrapUp.extractedInformation {
                let keys = key.split(separator: "_").map { String($0) }
                let newKey = key.components(separatedBy: "\(StepsNames.wrapUp)_").last?.components(separatedBy: "_").joined(separator: " ") ?? ""
                
                stepData[newKey] = value
            }
            
            flowCompletedList.append(
                FlowCompletedModel(
                    stepData: stepData,
                    submitRequestModel: wrapUp
                )
            )
        }
        
        return flowCompletedList
    }
    

    public func getSubmitList() -> [SubmitRequestModel] {

        let steps = LocalStepsObject.shared.get()
        var submitList: [SubmitRequestModel] = []

        // 1) Collect submitRequestModel from local steps
        for step in steps {
            if let submitModel = step.submitRequestModel {
                submitList.append(submitModel)
            }
        }

        // 2) Build WrapUp SubmitRequestModel (TimeEnded)
        var wrapUp: SubmitRequestModel? = nil
        let initSteps = ConfigModelObject.shared.get()!.stepDefinitions
        let initStepsMap = ConfigModelObject.shared.get()?.stepMap.first {
            $0.stepDefinition == StepsNames.wrapUp
        }
        for item in initSteps {
            if item.stepId == initStepsMap?.id {

                var values: [String: String] = [:]

                for property in item.outputProperties {
                    if property.key.contains(WrapUpKeys.timeEnded) {
                        values[property.key] = getTimeUTC()
                    }
                }

                wrapUp = SubmitRequestModel(
                    stepId: item.stepId,
                    stepDefinition: StepsNames.wrapUp,
                    extractedInformation: values
                )

                break
            }
        }

        if let wrapUp {
            submitList.append(wrapUp)
        }

        return submitList
    }
    
  
    
    
    public  func trackNext(
          currentStep: LocalStepModel,
          nextStep: LocalStepModel?,
          timeStarted :String,
      ) {
          let configModel = ConfigModelObject.shared.get()!
          let apiKey = ApiKeyObject.shared.get()
          let flowEnvironmentalConditions = FlowEnvironmentalConditionsObject.shared.get()
          
          
          let components = URLComponents(string: BaseUrls.baseURLGateway + "api/FlowTracker/track-next")
         

          guard let url = components?.url else {
              return
          }

          var request = URLRequest(url: url)
          request.httpMethod = "POST"

        
          request.setValue("application/json", forHTTPHeaderField: "Content-Type")
          request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
          request.setValue("iOS SDK", forHTTPHeaderField: "X-Source-Agent")
          request.setValue(configModel.flowInstanceId, forHTTPHeaderField: "X-Flow-Instance-Id")
          request.setValue(configModel.tenantIdentifier, forHTTPHeaderField: "X-Tenant-Identifier")
          request.setValue(configModel.blockIdentifier, forHTTPHeaderField: "X-Block-Identifier")
          request.setValue(configModel.instanceId, forHTTPHeaderField: "X-Instance-Id")
          request.setValue(configModel.flowIdentifier, forHTTPHeaderField: "X-Flow-Identifier")
          request.setValue(configModel.instanceHash, forHTTPHeaderField: "X-Instance-Hash")

        
          
          let wrapUpStep = configModel.stepMap.first {
              $0.stepDefinition == StepsNames.wrapUp
          }
          
          let wrapUpStepType = configModel.stepDefinitions.first {
              $0.stepDefinition == StepsNames.wrapUp
          }


          let currentStepType = configModel.stepDefinitions.first {
              $0.stepId == currentStep.stepDefinition!.stepId
          }?.customization.stepTypeDto.id ?? 0

          let nextStepType: Int
          let nextStepId: Int
          let nextStepDefinition: String

          if let next = nextStep {
              nextStepDefinition = next.stepDefinition!.stepDefinition
              nextStepId = next.stepDefinition!.stepId
              nextStepType = configModel.stepDefinitions.first {
                  $0.stepId == next.stepDefinition!.stepId
              }?.customization.stepTypeDto.id ?? 0
          } else {
              nextStepDefinition = StepsNames.wrapUp
              nextStepId = wrapUpStep?.id ?? 0
              nextStepType = wrapUpStepType?.customization.stepTypeDto.id ?? 0
          }
          
          let userAgent = "iOS \(UIDevice.current.systemVersion); \(UIDevice.current.model)"
          let deviceName = "\(UIDevice.current.model) \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
          
          let body = TrackNextRequest(
              applicationId: configModel.applicationId,
              blockIdentifier: configModel.blockIdentifier,
              blockType: "Engagement",
              deviceName: deviceName,
              flowIdentifier: configModel.flowIdentifier,
              flowInstanceId: configModel.flowInstanceId,
              flowName: configModel.flowName,
              instanceHash: configModel.instanceHash,
              isSuccessful: true,
              language: flowEnvironmentalConditions!.extractedDataLanguage,
              nextStepDefinition: nextStepDefinition,
              nextStepId: nextStepId,
              nextStepTypeId: nextStepType,
              phoneNumber: nil,
              statusCode: 200,
              stepDefinition: currentStep.stepDefinition!.stepDefinition,
              stepId: currentStep.stepDefinition!.stepId,
              stepTypeId: currentStepType,
              tenantIdentifier: configModel.tenantIdentifier,
              timeStarted: timeStarted,
              timeEnded: getCurrentDateTimeForTracking(),
              userAgent: userAgent
          )
          
          do {
              let encoder = JSONEncoder()
              request.httpBody = try encoder.encode(body)
          } catch {
              return
          }

          let task = URLSession.shared.dataTask(with: request) { data, response, error in

             
              guard let httpResponse = response as? HTTPURLResponse else {
                  return
              }
              if(httpResponse.statusCode == 200){
                  guard let responseData = data else {
                      return
                  }
                  if let responseString = String(data: responseData, encoding: .utf8) {}
             }

            
          }

          task.resume()
      }
    
    
    public  func trackProgress(
          currentStep: LocalStepModel,
          inputData: Any?,
          response: Any?,
          status:String,
      ) {
          let configModel = ConfigModelObject.shared.get()!
          let apiKey = ApiKeyObject.shared.get()
          let flowEnvironmentalConditions = FlowEnvironmentalConditionsObject.shared.get()
          
          
          let components = URLComponents(string: BaseUrls.baseURLGateway + "api/FlowTracker/track-progress")
         

          guard let url = components?.url else {
              return
          }

          var request = URLRequest(url: url)
          request.httpMethod = "POST"

        
          request.setValue("application/json", forHTTPHeaderField: "Content-Type")
          request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
          request.setValue("iOS SDK", forHTTPHeaderField: "X-Source-Agent")
          request.setValue(configModel.flowInstanceId, forHTTPHeaderField: "X-Flow-Instance-Id")
          request.setValue(configModel.tenantIdentifier, forHTTPHeaderField: "X-Tenant-Identifier")
          request.setValue(configModel.blockIdentifier, forHTTPHeaderField: "X-Block-Identifier")
          request.setValue(configModel.instanceId, forHTTPHeaderField: "X-Instance-Id")
          request.setValue(configModel.flowIdentifier, forHTTPHeaderField: "X-Flow-Identifier")
          request.setValue(configModel.instanceHash, forHTTPHeaderField: "X-Instance-Hash")

        
          
       
          let currentStepType = configModel.stepDefinitions.first {
              $0.stepId == currentStep.stepDefinition!.stepId
          }?.customization.stepTypeDto.id ?? 0

        
          
          let userAgent = "iOS \(UIDevice.current.systemVersion); \(UIDevice.current.model)"
          let deviceName = "\(UIDevice.current.model) \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
          
          let body = TrackProgressRequest(
              tenantIdentifier: configModel.tenantIdentifier,
              flowIdentifier: configModel.flowIdentifier,
              flowInstanceId: configModel.flowInstanceId,
              applicationId: configModel.applicationId,
              blockIdentifier: configModel.blockIdentifier,
              instanceHash: configModel.instanceHash,
              flowName: configModel.flowName,
              stepDefinition: currentStep.stepDefinition!.stepDefinition,
              stepId: currentStep.stepDefinition!.stepId,
              stepTypeId: currentStepType,
              status: status,
              deviceName: deviceName,
              userAgent: userAgent,
              timestamp: getCurrentDateTimeForTracking(),
              language: flowEnvironmentalConditions!.extractedDataLanguage,
              inputData: prepareTrackProgressInputData(currentStep:currentStep, inputData:inputData),
              response: response,
              customProperties: []
          )
          
    

          do {
              let encoder = JSONEncoder()
              request.httpBody = try encoder.encode(body)
              
              

//            
//              let data = try encoder.encode(body)
//              if let jsonString = String(data: data, encoding: .utf8) {
//                  print("📦 TrackProgressRequest:\n\(configModel.instanceId)")
//                  print("📦 TrackProgressRequest:\n\(jsonString)")
//              }
//              
//              
//              ////
              
          } catch {
              return
          }

          let task = URLSession.shared.dataTask(with: request) { data, response, error in

              
              
              guard let httpResponse = response as? HTTPURLResponse else {
                  return
              }
            
          }

          task.resume()
      }
    

    func outputPropertiesToMap(_ outputProperties: [OutputProperties]) -> [String: String] {
        var data: [String: String] = [:]

        for property in outputProperties {
            data[property.key] = ""
        }

        return data
    }
    
   private  func prepareTrackProgressInputData(
        currentStep: LocalStepModel,
        inputData: Any?
    ) -> [String: Any] {

        var stepsData: [String: Any] = [:]
        let steps = LocalStepsObject.shared.get()

        // ✅ Add all done steps
        for step in steps where step.isDone {

            guard
                let stepDef = step.stepDefinition,
                let submitModel = step.submitRequestModel
            else { continue }

            var extractedInformation: [String: Any] = [:]
            extractedInformation["stepId"] = stepDef.stepId

            for (k, v) in submitModel.extractedInformation {
                extractedInformation[k] = v
            }

            let key = prepareStepName(stepDefinition:stepDef.stepDefinition,stepId: stepDef.stepId)
            stepsData[key] = extractedInformation
        }

        guard let currentDef = currentStep.stepDefinition else { return stepsData }

        var currentExtracted: [String: Any] = [:]
        currentExtracted["stepId"] = currentDef.stepId

        if let rawInput = inputData,
           let map = toMap(rawInput) {
            for (k, v) in map {
                if let v { currentExtracted[k] = v }
            }
        }

        let currentKey = prepareStepName(stepDefinition:currentDef.stepDefinition, stepId:currentDef.stepId)
        stepsData[currentKey] = currentExtracted

        return stepsData
    }
    
  private   func prepareStepName(
        stepDefinition: String,
        stepId: Int
    ) -> String {

        let steps = LocalStepsObject.shared.get()

        let duplicatesCount = steps.filter {
            $0.stepDefinition?.stepDefinition == stepDefinition
        }.count

        if duplicatesCount > 1 {
            return "\(stepDefinition)_\(stepId)"
        } else {
            return stepDefinition
        }
    }
    
    private  func toMap(_ input: Any?) -> [String: Any?]? {
        guard let input else { return nil }

        // Case 1: Already [String: Any]
        if let dict = input as? [String: Any] {
            return dict.mapValues { Optional($0) }
        }

        // Case 2: Dictionary with mixed keys → keep only String keys
        if let dict = input as? [AnyHashable: Any] {
            var result: [String: Any?] = [:]
            for (key, value) in dict {
                if let keyString = key as? String {
                    result[keyString] = value
                }
            }
            return result
        }

        // Case 3: JSON Data
        if let data = input as? Data {
            return parseJSONData(data)
        }

        // Case 4: JSON String
        if let jsonString = input as? String,
           let data = jsonString.data(using: .utf8) {
            return parseJSONData(data)
        }

        return nil
    }

    private  func parseJSONData(_ data: Data) -> [String: Any?]? {
        do {
            let object = try JSONSerialization.jsonObject(with: data)
            if let dict = object as? [String: Any] {
                return dict.mapValues { Optional($0) }
            }
        } catch {
            print("JSON parse error:", error)
        }
        return nil
    }
    
    
    
   public func extractAfterDash(_ error: String?) -> String {
        guard let error, !error.isEmpty else {
            return ""
        }

        if let range = error.range(of: "-") {
            let substring = error[range.upperBound...]
            return substring.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            return ""
        }
    }
    
    public  func decodeToJsonObject(_ originalString: String?) -> [String: Any]? {
        guard let originalString,
              !originalString.isEmpty,
              let data = originalString.data(using: .utf8) else {
            return nil
        }

        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            return json as? [String: Any]
        } catch {
            return nil
        }
    }
    
    public  func identificationDocumentStepHasPassport(stepID: Int) -> Bool {
        guard let configModel = ConfigModelObject.shared.get() else { return false }

        return configModel.stepDefinitions.contains { step in
            step.stepId == stepID &&
                step.customization.identificationDocuments?.contains { doc in
                    doc.documentType == IdentificationDocumentsDocumentType.Passport && doc.enabled == true
                } == true
        }
    }

    public  func identificationDocumentStepHasIDCard(stepID: Int) -> Bool {
        guard let configModel = ConfigModelObject.shared.get() else { return false }

        return configModel.stepDefinitions.contains { step in
            step.stepId == stepID &&
                step.customization.identificationDocuments?.contains { doc in
                    doc.documentType == IdentificationDocumentsDocumentType.ID && doc.enabled == true
                } == true
        }
    }

}
