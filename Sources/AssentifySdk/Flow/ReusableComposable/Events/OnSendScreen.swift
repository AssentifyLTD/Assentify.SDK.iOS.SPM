import SwiftUI


struct OnSendScreen: View {
    
    let progress: Int
    let steps: [LocalStepModel] = LocalStepsObject.shared.get();
    let onBack: () -> Void
    
    var body: some View {
        
        BaseBackgroundContainer {
            
            VStack(spacing: 0) {
                    ProgressStepperView(
                        steps: steps,
                        bundle: .main,
                        onBack: {onBack()}
                    )
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
                ScanAnimation(
                   iconName: "ic_scan_id"
                ).frame(width: 250, height: 250)
            } else {
                SVGAssetIcon(
                    name: "ic_uploading",
                    size: CGSize(width: 200, height: 140),
                    tintColor: BaseTheme.baseAccentColor
            
                ).frame(width: 200, height: 160)
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
                 ? FlowStrings.processingIdWait
                 : FlowStrings.uploadingIdWait)
            .foregroundColor(text)
            .font(.system(size: 18, weight: .bold))
            .multilineTextAlignment(.center)
        }
    }
}
