import SwiftUI


struct OnFaceSendScreen: View {
    
    let progress: Int
    let steps: [LocalStepModel] = LocalStepsObject.shared.get();
    let onBack: () -> Void

    
    var body: some View {
        
        BaseBackgroundContainer {
            
            VStack(spacing: 0) {
                    ProgressStepperView(
                        steps: steps,
                        bundle: .main,
                        onBack: {onBack()}                    )
                    .padding(.top,
                             BaseTheme.stepperType == .normal ?
                             120 : 80)
                
                                
                content .padding(.top, 80)
                
                Spacer()
            }
        }
        .ignoresSafeArea()
    }
    
    private var content: some View {
        
        let accent = Color(BaseTheme.baseAccentColor)
        let text   = Color(BaseTheme.baseTextColor)
        let track  = Color(BaseTheme.fieldColor)
        
        return VStack {
            
            if progress == 100 {
                FaceScanAnimation(
                   iconName: "ic_face_id"
                ).frame(width: 170, height: 180)
            } else {
                SVGAssetIcon(
                    name: "ic_uploading_face",
                    size: CGSize(width: 140, height: 155),
                    tintColor: BaseTheme.baseAccentColor
            
                ).frame(width: 150, height: 160)
                Spacer().frame(height: 10)
            }
            
            Spacer().frame(height: 10)
            
            if progress != 100 {
                
                Text("\(progress)%")
                    .foregroundColor(text.opacity(0.9))
                    .font(.system(size: 14, weight: .medium))
                
                Spacer().frame(height: 8)
                
                ProgressView(value: Double(progress), total: 100)
                    .progressViewStyle(.linear)
                    .tint(accent)
                    .frame(maxWidth: 250)
                    .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(track)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                
                Spacer().frame(height: 12)
            }
            
            Text(progress == 100
                 ? FlowStrings.processingFaceWait
                 : FlowStrings.uploadingFaceWait)
            .foregroundColor(text)
            .font(.system(size: 18, weight: .bold))
            .multilineTextAlignment(.center)
        }
    }
}
