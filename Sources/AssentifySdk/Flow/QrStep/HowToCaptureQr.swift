import SwiftUI
import AVKit
import WebKit

public struct HowToCaptureQrScreen: View {
    
    @Environment(\.dismiss) private var dismiss
    
    private func onBack () {
        self.flowController.backClick()
    }
    
    private func onNext() {
        flowController.push(QrScanStep(flowController: self.flowController))
    }
    
    private let flowController: FlowController
    private var iDCustomization:Customization

    public init(flowController: FlowController) {
        self.flowController = flowController
        self.iDCustomization =  getIDStepFromConfigFile(
            configModel: ConfigModelObject.shared.get()!  ,
            id:flowController.getCurrentStep()?.stepDefinition?.stepId ?? 0
        )!
    }
    
  
    
    
    
    
    private var titleText = FlowStrings.captureQrCode
    private var subTitleText = FlowStrings.watchCaptureQr
    private var assetGifFileName = "qr_gif"
    
    
    public var body: some View {
        BaseBackgroundContainer {
            
            VStack(spacing: 0) {
                
                // MARK: TOP SECTION
                VStack(spacing: 0) {
                    
                    Spacer().frame(height: 10)
                    
                    Text(titleText)
                        .foregroundColor(Color(BaseTheme.baseTextColor))
                        .font(.system(size: 25, weight: .bold))
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity)
                    
                    Spacer().frame(height: 20)
                    
                    // MARK: VIDEO (Flexible like weight(1f))
                    AssetVideoPlayer(assetName: "qr-video")
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: .infinity)
                        .padding(.horizontal, 10)
                    
                    Spacer().frame(height: 20)
                    
                    Text(subTitleText)
                        .foregroundColor(Color(BaseTheme.baseTextColor))
                        .font(.system(size: 25, weight: .bold))
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal, 12)
                    
                    Spacer().frame(height: 20)
                    
                    Text(FlowStrings.qrLightingHint)
                        .foregroundColor(Color(BaseTheme.baseTextColor))
                        .font(.system(size: 12, weight: .thin))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 12)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .frame(maxHeight: .infinity)
                
               
                
                if(iDCustomization.isNormalClick!){
                    BaseClickButton(
                        title: FlowStrings.letsStart,
                        cornerRadius: 28,
                        verticalPadding: 15,
                        enabled: true
                    ) {
                        onNext()
                    }
                    .padding(.horizontal, 25)
                    .padding(.vertical, 25)
                }else{
                    BaseSliderClick(
                        onNext: { onNext()},
                        label:  FlowStrings.letsStart,
                        icon: "camera",
                        isActive: true
                    ).padding(.horizontal, 25)
                     .padding(.vertical, 25)
                }
                
                
            }
            .topBarBackLogo(logoUrl :BaseTheme.baseLogo,noStepper: true,) {
                onBack()
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .modifier(InterceptSystemBack(action: onBack))
        .task {
            // ✅ runs once per appearance
        }
    }
}

