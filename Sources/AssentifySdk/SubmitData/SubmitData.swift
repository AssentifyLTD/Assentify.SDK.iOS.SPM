
import Foundation


public class SubmitData{
    private var apiKey: String;
    private var submitDataDelegate: SubmitDataDelegate;
    private var submitRequestModel: [SubmitRequestModel];
    private var configModel: ConfigModel;
    
    init(
        apiKey: String,
        submitDataDelegate: SubmitDataDelegate,
        submitRequestModel:  [SubmitRequestModel],
        configModel: ConfigModel
    ){
        self.apiKey = apiKey;
        self.submitDataDelegate = submitDataDelegate;
        self.submitRequestModel = submitRequestModel;
        self.configModel = configModel;
        submitData();
    }
    
    private func submitData() {
     
        
        remoteSubmitData(
            apiKey: apiKey,
            configModel: self.configModel,
            submitRequestModel: submitRequestModel
        ) { result in
            switch result {
            case .success(_):
                self.submitDataDelegate.onSubmitSuccess()
            case .failure(let error):
                self.submitDataDelegate.onSubmitError(message: error.localizedDescription)
            }
        }
    }
    
    
}
