import SwiftUI
import AVKit

public struct HowToCaptureFaceScreen: View {

    @Environment(\.dismiss) private var dismiss

    private func onBack () {
        self.flowController.backClick()
    }

    private func onNext() {
        flowController.push(FaceMatchStep(flowController: self.flowController, secondImage: cachedBase64!))
    }

    private let flowController: FlowController
    private var docUrl = ""

    private var faceCustomization:Customization

    
    public init(flowController: FlowController) {
        self.flowController = flowController
        self.faceCustomization =  getFaceStepFromConfigFile(
            configModel: ConfigModelObject.shared.get()!  ,
            id:flowController.getCurrentStep()?.stepDefinition?.stepId ?? 0
        )!
        self.docUrl = normalizeUrlString(self.flowController.getPreviousIDImage())
        
      
    }

    private func normalizeUrlString(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Handle: Optional("https://...")
        if s.hasPrefix("Optional(\"") && s.hasSuffix("\")") {
            s = String(s.dropFirst("Optional(\"".count).dropLast(2))
        }

        // Handle: "https://..." (extra quotes)
        if s.hasPrefix("\"") && s.hasSuffix("\"") && s.count >= 2 {
            s = String(s.dropFirst().dropLast())
        }

        return s
    }

    
    
    private var titleText = FlowStrings.faceMatch
    private var subTitleText = FlowStrings.watchCaptureSelfieMultiline
    private var subTitleTextOnLine = FlowStrings.watchCaptureSelfieSingleLine
    private var assetVideoFileName = "face-video"

    // ✅ New states (logic only)
    @State private var cachedBase64: String? = nil
    @State private var isLoadingBase64: Bool = true

    // ✅ Async-safe base64 loader
    private func loadImageBase64(from urlString: String) async -> String? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // If it's a local file path, support it too
        if trimmed.hasPrefix("/") {
            let fileURL = URL(fileURLWithPath: trimmed)
            return await base64FromFile(fileURL)
        }

        guard let url = URL(string: trimmed) else { return nil }

        // local file:// url
        if url.isFileURL {
            return await base64FromFile(url)
        }

        // remote http/https
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            return data.base64EncodedString()
        } catch {
            return nil
        }
    }

    private func base64FromFile(_ url: URL) async -> String? {
        // file reads are fast, but still keep it off the main thread
        return await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let data = try Data(contentsOf: url)
                    cont.resume(returning: data.base64EncodedString())
                } catch {
                    cont.resume(returning: nil)
                }
            }
        }
    }

    public var body: some View {
        BaseBackgroundContainer {

            VStack(spacing: 0) {

                // MARK: TOP SECTION
                VStack(spacing: 0) {

                    Spacer().frame(height: 10)

                    if self.faceCustomization.header != nil &&
                       self.faceCustomization.subHeader != nil &&
                       self.faceCustomization.svgLogoUrl != nil {
                        
                        VStack(spacing: 5) {
                            HStack {
                                Spacer()
                                LogoSvgUrl(url: self.faceCustomization.svgLogoUrl ?? "")
                                    .frame(width: 80, height: 80)
                                Spacer()
                            }

                            Text(self.faceCustomization.header ?? "")
                                .font(.system(size: 25, weight: .bold))
                                .foregroundColor(Color(BaseTheme.baseTextColor))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.horizontal, 20)

                            Text(self.faceCustomization.subHeader ?? "")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(Color(BaseTheme.baseTextColor).opacity(0.5))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.horizontal, 20)
                        }
                        Spacer().frame(height: 10)
                    }
                    else{
                        Text(titleText)
                            .foregroundColor(Color(BaseTheme.baseTextColor))
                            .font(.system(size: 25, weight: .bold))
                            .multilineTextAlignment(.center)
                            .lineSpacing(6)
                            .frame(maxWidth: .infinity)
                        Spacer().frame(height: 20)
                    }
                

                

                    // MARK: VIDEO (Flexible like weight(1f))
                    AssetVideoPlayer(assetName: assetVideoFileName)
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: .infinity)
                        .padding(.horizontal, 10)

                    Spacer().frame(height: 20)

                 if self.faceCustomization.header != nil &&
                        self.faceCustomization.subHeader != nil &&
                        self.faceCustomization.svgLogoUrl != nil {
                     Text(subTitleTextOnLine)
                         .foregroundColor(Color(BaseTheme.baseTextColor))
                         .font(.system(size: 20, weight: .bold))
                         .multilineTextAlignment(.center)
                         .lineSpacing(4)
                         .padding(.horizontal, 8)
                 }else{
                     Text(subTitleText)
                         .foregroundColor(Color(BaseTheme.baseTextColor))
                         .font(.system(size: 25, weight: .bold))
                         .multilineTextAlignment(.center)
                         .lineSpacing(6)
                         .padding(.horizontal, 12)
                 }

                    

                    Spacer().frame(height: 20)

                    Text(FlowStrings.faceLivenessHint)
                        .foregroundColor(Color(BaseTheme.baseTextColor))
                        .font(.system(size: 12, weight: .thin))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 12)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .frame(maxHeight: .infinity)

                // ✅ UI stays the same: button if base64 exists, else progress
                if let _ = cachedBase64 {
                    
                    if(faceCustomization.isNormalClick!){
                        BaseClickButton(
                            title: FlowStrings.letsStart,
                            cornerRadius: 28,
                            verticalPadding: 15,
                            enabled: true
                        ) {
                            onNext()
                        }
                        .padding(.horizontal, 25)
                        .padding(.vertical,
                            self.faceCustomization.header != nil &&
                            self.faceCustomization.subHeader != nil &&
                            self.faceCustomization.svgLogoUrl != nil ? 10 : 25
                        )
                    }else{
                        BaseSliderClick(
                            onNext: { onNext()},
                            label:  FlowStrings.letsStart,
                            icon: "camera",
                            isActive: true
                        ).padding(.horizontal, 25)
                         .padding(.vertical,
                                self.faceCustomization.header != nil &&
                                self.faceCustomization.subHeader != nil &&
                                self.faceCustomization.svgLogoUrl != nil ? 10 : 25
                            )
                    }
                    
                    
                  

                } else {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Color(BaseTheme.baseTextColor))
                        .scaleEffect(1.2).padding(.vertical, 25)
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
            isLoadingBase64 = true
            cachedBase64 = await loadImageBase64(from: docUrl)
            isLoadingBase64 = false
        }
    }
}

func getFaceStepFromConfigFile(
    configModel: ConfigModel,
    id: Int
) -> Customization? {
    let step = configModel.stepDefinitions.first { $0.stepId == id }
    return step?.customization
}

