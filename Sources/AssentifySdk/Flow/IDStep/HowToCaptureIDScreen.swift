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
    
    private var themeVideoOverride: String {
        isPassport
            ? BaseTheme.BaseHowToCapturePassportVideo
            : BaseTheme.BaseHowToCaptureIDVideo
    }
    
    private var isCustomVideoUrl: Bool {
        !themeVideoOverride.isEmpty
    }

    private var assetVideoFileName: String {
        let langSuffix = BaseTheme.baseUiLanguage == UiLanguage.Arabic ? "ar" : "en"
        let base = isPassport ? "passport-video" : "id-video"
        return "\(base)-\(langSuffix)"
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

                        if(isCustomVideoUrl){
                            if let url = URL(string: themeVideoOverride) {
                                UrlVideoPlayer(videoURL: url)
                                    .frame(maxWidth: .infinity)
                                    .frame(maxHeight: .infinity)
                                    .padding(.horizontal, 10)
                            }
                           
                        }else{
                            AssetVideoPlayer(assetName: assetVideoFileName)
                                .frame(maxWidth: .infinity)
                                .frame(maxHeight: .infinity)
                                .padding(.horizontal, 10)
                        }
                    

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


// MARK: - UIKit view backed by AVPlayerLayer

final class PlayerLayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

struct VideoLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.backgroundColor = .clear
        view.playerLayer.backgroundColor = UIColor.clear.cgColor
        view.playerLayer.player = player
        // Show the whole video (no zoom). Because the container uses the video's
        // own aspect ratio, there is no empty space, so no black bars either.
        view.playerLayer.videoGravity = .resizeAspect
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {
        uiView.playerLayer.player = player
    }
}

// MARK: - Public view

public struct AssetVideoPlayer: View {

    let assetName: String
    var cornerRadius: CGFloat

    @State private var player: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?
    @State private var videoAspectRatio: CGFloat = 1   // width / height, updated from the file

    public init(assetName: String, cornerRadius: CGFloat = 16) {
        self.assetName = assetName
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        ZStack {
            if let player {
                VideoLayerView(player: player)
            } else {
                ProgressView()
            }
        }
        .aspectRatio(videoAspectRatio, contentMode: .fit)   // matches the real video shape
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task { await setUpPlayer() }
        .onDisappear { player?.pause() }
    }

    @MainActor
    private func setUpPlayer() async {
        if let player {                 // coming back to the screen
            player.play()
            return
        }
        guard let url = Bundle.module.url(forResource: assetName, withExtension: "mp4") else { return }

        let asset = AVURLAsset(url: url)
        if let ratio = await Self.loadAspectRatio(of: asset) {
            videoAspectRatio = ratio
        }

        let item = AVPlayerItem(asset: asset)
        let queuePlayer = AVQueuePlayer()
        queuePlayer.isMuted = true
        looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        player = queuePlayer
        queuePlayer.play()
    }

    /// Real display ratio of the video (handles rotated/portrait recordings).
    private static func loadAspectRatio(of asset: AVURLAsset) async -> CGFloat? {
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let (size, transform) = try? await track.load(.naturalSize, .preferredTransform)
        else { return nil }

        let rect = CGRect(origin: .zero, size: size).applying(transform)
        let width = abs(rect.width), height = abs(rect.height)
        guard width > 0, height > 0 else { return nil }
        return width / height
    }
}

public struct UrlVideoPlayer: View {

    let videoURL: URL
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
            let newPlayer = AVPlayer(url: videoURL)
            newPlayer.isMuted = true   // mute audio
            player = newPlayer
        }
    }
}
