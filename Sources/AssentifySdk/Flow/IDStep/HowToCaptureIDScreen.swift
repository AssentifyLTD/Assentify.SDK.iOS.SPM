import SwiftUI
import AVKit

public struct HowToCaptureScreen: View {

    @Environment(\.dismiss) private var dismiss

    private func onBack () {
        self.flowController.pop();
    }
    public func onNext() {
        if(isPassport){
            if(BaseTheme.localMrzScan){
                self.flowController.push(LocalPassportScanStep(flowController: self.flowController))
            }else{
                self.flowController.push(PassportScanStep(flowController: self.flowController))
            }
        }else{
            self.flowController.push(IDCardScanStep(flowController: self.flowController))
        }
    }

    private let selectedTemplateId = SelectedTemplatesObject.shared.get()!.id;

    
    private let flowController: FlowController


    private var iDCustomization:Customization
    public init(flowController: FlowController) {
        self.flowController = flowController
        
        self.iDCustomization =  getIDStepFromConfigFile(
            configModel: ConfigModelObject.shared.get()!  ,
            id:flowController.getCurrentStep()?.stepDefinition?.stepId ?? 0
        )!
    }

    private var isPassport: Bool { selectedTemplateId == -1 }

    private var titleText: String {
        isPassport ? FlowStrings.presentPassport : FlowStrings.presentId
    }

    private var subTitleText: String {
        isPassport ? FlowStrings.watchCapturePassport : FlowStrings.watchCaptureId
    }

    private var assetVideoFileName: String {
        isPassport ? "passport-video" : "id-video"
    }

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
                        AssetVideoPlayer(assetName: assetVideoFileName)
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

                        Text(FlowStrings.idLightingHint)
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
                        ) .padding(.horizontal, 25)
                         .padding(.vertical, 25)
                    }
                   
                    
                
                    
                    
                }.topBarBackLogo(logoUrl :BaseTheme.baseLogo,noStepper: true,) {
                    onBack()
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }.modifier(InterceptSystemBack(action: onBack))
        }
    }
public struct AssetVideoPlayer: View {

    let assetName: String
    @State public var player: AVPlayer?

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                if let player {
                    VideoPlayer(player: player)
                        .frame(width: geo.size.width, height: geo.size.width)
                        .clipped()
                        // Overlay blocks the tap gesture that reveals controls
                        .overlay(Color.clear.contentShape(Rectangle()))
                        .allowsHitTesting(false)
                        .onAppear {
                            player.play()
                            NotificationCenter.default.addObserver(
                                forName: .AVPlayerItemDidPlayToEndTime,
                                object: player.currentItem,
                                queue: .main
                            ) { _ in
                                player.seek(to: .zero)
                                player.play()
                            }
                        }
                        .onDisappear {
                            player.pause()
                        }
                } else {
                    ProgressView()
                }
            }
        }
        .aspectRatio(1/1, contentMode: .fit)
        .onAppear {
            guard let url = Bundle.module.url(forResource: assetName, withExtension: "mp4") else {
                return
            }
            let newPlayer = AVPlayer(url: url)
            newPlayer.isMuted = true   // mute audio
            player = newPlayer
        }
    }
}
