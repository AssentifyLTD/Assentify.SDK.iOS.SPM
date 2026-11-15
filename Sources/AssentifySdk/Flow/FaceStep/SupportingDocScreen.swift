import SwiftUI

/// Pick the supporting document after a low face match.
/// Kotlin: SupportingDocComposeActivity + SupportingDocScreen.
struct SupportingDocScreen: View {

    private let flowController: FlowController
    private let flowName: String
    private let templatesByCountry: TemplatesByCountry
    private let steps: [LocalStepModel] = LocalStepsObject.shared.get()

    @State private var selectedTemplate: Templates?
    @State private var showIdsSheet = false

    init(flowController: FlowController) {
        self.flowController = flowController
        self.flowName = ConfigModelObject.shared.get()?.flowName ?? ""

        let accepted = flowController.getCurrentStep()?.stepDefinition?
            .customization.supportingDocumentAcceptedDocuments ?? []

        self.templatesByCountry = AssentifySdkObject.shared.get()?
            .getTemplatesForSupportingDoc(supportingDocumentAcceptedDocuments: accepted)
            ?? TemplatesByCountry(id: -1, name: "", sourceCountryCode: "", flag: "", templates: [])
    }

    private var hasID: Bool { !templatesByCountry.templates.isEmpty }

    /// The "Supported IDs" card's template (any id other than -1 means an ID card).
    private var idTemplate: Templates {
        Templates(
            id: 1,
            sourceCountryFlag: "",
            sourceCountryCode: templatesByCountry.sourceCountryCode,
            kycDocumentType: FlowStrings.allIds,
            sourceCountry: "",
            kycDocumentDetails: []
        )
    }

    private func onBack() {
        flowController.pop(animated: true)
    }

    /// Passport (id -1) -> the passport scan, anything else -> the ID card scan.
    private func openScan(for template: Templates) {
        if template.id == -1 {
            flowController.push(SupportingPassportScanStep(flowController: flowController))
        } else {
            flowController.push(SupportingIDCardScanStep(flowController: flowController))
        }
    }

    var body: some View {
        BaseBackgroundContainer {
            VStack(spacing: 0) {

                ProgressStepperView(steps: steps, bundle: .main, onBack: { onBack() })
                    .padding(.top, 20)

                // TOP + MIDDLE
                ScrollView {
                    VStack(spacing: 0) {

                        Text(FlowStrings.supportingDocumentTitle)
                            .font(.system(size: 23, weight: .bold))
                            .foregroundColor(Color(BaseTheme.baseTextColor))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 18)
                            .padding(.horizontal, 20)

                        Text(FlowStrings.supportingDocumentTMsg)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(BaseTheme.baseTextColor).opacity(0.5))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 6)
                            .padding(.horizontal, 20)

                        VStack(alignment: .leading, spacing: 16) {
                            Text(FlowStrings.selectDocumentType)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color(BaseTheme.baseTextColor))

                            DocumentPickerCards(
                                minVerticalPadding: false,
                                country: templatesByCountry,
                                selectedTemplate: selectedTemplate,
                                onSelect: { template in
                                    selectedTemplate = template
                                },
                                onViewMore: {
                                    showIdsSheet = true
                                },
                                hasPassport: true,
                                hasID: hasID
                            )
                        }
                        .padding(16)
                    }
                }
                .padding(.horizontal, 5)

                // BOTTOM
                VStack(spacing: 10) {
                    Text(FlowStrings.onlySupportedIds(flowName: flowName))
                        .font(.system(size: 12, weight: .thin))
                        .foregroundStyle(Color(BaseTheme.baseTextColor))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)

                    BaseClickButton(title: FlowStrings.next, enabled: selectedTemplate != nil) {
                        guard let template = selectedTemplate else { return }
                        openScan(for: template)
                    }
                    .padding(.top, 5)
                }
                .padding(.horizontal, 20)
            }
            .topBarBackLogo {
                onBack()
            }
        }
        .modifier(InterceptSystemBack(action: onBack))
        .bottomSheet(
            isPresented: $showIdsSheet,
            height: sheetHeight(for: templatesByCountry.templates.count)
        ) {
            TemplatesBottomSheet(
                title: FlowStrings.supportedIds,
                templates: templatesByCountry.templates,
                onClose: { showIdsSheet = false },
                onTap: {
                    let template = idTemplate
                    selectedTemplate = template
                    openScan(for: template)
                }
            )
        }
    }

    private func sheetHeight(for count: Int) -> CGFloat {
        let header: CGFloat = 56
        let padding: CGFloat = 32
        let row: CGFloat = 88
        let calculated = header + padding + (row * CGFloat(max(count, 1)))
        let cap = UIScreen.main.bounds.height * 0.75
        return min(calculated, cap)
    }
}
