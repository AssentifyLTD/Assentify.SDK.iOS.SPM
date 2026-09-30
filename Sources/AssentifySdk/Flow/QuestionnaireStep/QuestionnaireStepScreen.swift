//
//  QuestionnaireStepScreen.swift
//  AssentifySdk
//
//  Questionnaire step: view model (QuestionnaireDelegate + paging + result building)
//  and the step screen. Mirrors the structure of DocumentCaptureStepScreen.swift.
//

import SwiftUI

public enum QuestionnaireStepEventType {
    case onSend
    case onComplete
    case onError
}

// MARK: - Theme (single place to swap names if your BaseTheme differs)

private enum QColors {
    static var text: Color { Color(BaseTheme.baseTextColor) }
    static var error: Color { Color(BaseTheme.baseRedColor) }
    static var field: Color { Color(BaseTheme.fieldColor) }        // Kotlin: BaseTheme.FieldColor
    static var accent: Color { Color(BaseTheme.baseAccentColor) }   // swap for your accent colour if you have one
}

// MARK: - View model (plays the role of the Android Activity)

@MainActor
final class QuestionnaireStepViewModel: ObservableObject, QuestionnaireDelegate {

    @Published private(set) var eventType: QuestionnaireStepEventType = .onSend
    @Published private(set) var model: QuestionnaireModel? = nil
    @Published private(set) var questions: [QuestionModel] = []
    @Published private(set) var currentIndex: Int = 0
    /// Selected answer keys per question index.
    @Published private(set) var selections: [Int: Set<String>] = [:]
    @Published private(set) var showRequiredError = false
    @Published private(set) var errorMessage: String = FlowStrings.qLoadFailed

    private let flowController: FlowController
    private var questionnaire: Questionnaire?
    private let timeStarted: String = getCurrentDateTimeForTracking()
    private var didStart = false
    private var isNavigating = false

    nonisolated init(flowController: FlowController) {
        self.flowController = flowController
    }

    // MARK: Start / lifecycle

    func startIfNeeded() {
        guard !didStart else { return }
        didStart = true

        guard let currentStep = flowController.getCurrentStep() else {
            eventType = .onError
            return
        }

        flowController.trackProgress(
            currentStep: currentStep,
            inputData: flowController.outputPropertiesToMap(currentStep.stepDefinition!.outputProperties),
            response: nil,
            status: "InProgress"
        )

        questionnaire = AssentifySdkObject.shared.get()?.startQuestionnaire(
            questionnaireDelegate: self,
            stepId: currentStep.stepDefinition?.stepId
        )
        if questionnaire == nil {
            eventType = .onError
        }
    }

    /// Called on first show AND when coming back from the next step.
    func onAppear() {
        isNavigating = false
        questionnaire?.delegate = self
    }

    /// Break the strong delegate cycle while off-screen (same as DocumentCapture).
    func onDisappear() {
        questionnaire?.delegate = nil
    }

    // MARK: SDK callbacks

    nonisolated func onQuestionnaireCallbackSuccess(questionnaireModel: QuestionnaireModel) {
        Task { @MainActor in
            self.handleLoaded(questionnaireModel)
        }
    }

    nonisolated func onQuestionnaireCallbackError(message: String) {
        Task { @MainActor in
            self.errorMessage = message.isEmpty ? FlowStrings.qLoadFailed : message
            self.eventType = .onError
        }
    }

    private func handleLoaded(_ questionnaireModel: QuestionnaireModel) {
        let loaded = questionnaireModel.questions ?? []

        // Pre-select answers when the server sends an existing value
        // (comma-separated, matched against answer key or value).
        var initial: [Int: Set<String>] = [:]
        for (index, question) in loaded.enumerated() where !question.value.isEmpty {
            let parts = Set(question.value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
            var picked = question.answers
                .filter { parts.contains($0.key) || parts.contains($0.value) }
                .map(\.key)
            if !question.allowMultipleAnswers { picked = Array(picked.prefix(1)) }
            if !picked.isEmpty { initial[index] = Set(picked) }
        }

        model = questionnaireModel
        questions = loaded
        selections = initial
        currentIndex = 0
        showRequiredError = false
        eventType = .onComplete
    }

    // MARK: State helpers (side-effect free, safe to read from `body`)

    var currentQuestion: QuestionModel? {
        questions.indices.contains(currentIndex) ? questions[currentIndex] : nil
    }

    var isFirst: Bool { currentIndex == 0 }
    var isLast: Bool { questions.isEmpty || currentIndex == questions.count - 1 }

    func isSelected(_ answer: AnswerModel) -> Bool {
        selections[currentIndex]?.contains(answer.key) == true
    }

    func isAnswered(_ index: Int) -> Bool {
        !(selections[index] ?? []).isEmpty
    }

    // MARK: Actions

    func toggle(_ answer: AnswerModel) {
        guard let question = currentQuestion else { return }
        var set = selections[currentIndex] ?? []

        if question.allowMultipleAnswers {
            if set.contains(answer.key) { set.remove(answer.key) } else { set.insert(answer.key) }
        } else {
            set = [answer.key]
        }

        selections[currentIndex] = set
        showRequiredError = false
    }

    func goNext() {
        guard isAnswered(currentIndex) else {
            showRequiredError = true
            return
        }
        showRequiredError = false
        if isLast {
            finish()
        } else {
            currentIndex += 1
        }
    }

    func goPrevious() {
        guard currentIndex > 0 else { return }
        showRequiredError = false
        currentIndex -= 1
    }

    /// Finishing is allowed with no questions at all (the "no questions" message is shown).
    func finish() {
        guard !isNavigating else { return }

        if let firstUnanswered = questions.indices.first(where: { !isAnswered($0) }) {
            currentIndex = firstUnanswered
            showRequiredError = true
            return
        }

        isNavigating = true
        flowController.makeCurrentStepDone(
            extractedInformation: buildResult(),
            timeStarted: timeStarted
        )
        flowController.naveToNextStep()
    }

    func onBack() {
        flowController.backClick()
    }

    /// Output of the step.
    /// keyProperty   -> selected answer key(s), comma-separated
    /// valueProperty -> selected answer value(s), comma-separated
    /// Adjust here if the backend expects a different shape (e.g. the *Identifier fields as keys).
    
    private var totalWeightKey: String?


    
    private func buildResult() -> [String: String] {
        
        let currentStep = flowController.getCurrentStep()
        
        let outputs = flowController.outputPropertiesToMap(currentStep!.stepDefinition!.outputProperties)
        totalWeightKey = outputs.keys.first { $0.hasSuffix("_TotalWeight") }
        
        var result: [String: String] = [:]

        for (index, question) in questions.enumerated() {
            let picked = pickedAnswers(at: index)
            if picked.isEmpty { continue }

            result[question.keyProperty] = picked.map { answerKeyFor(question, $0) }.joined(separator: ";")
            result[question.valueProperty] = picked.map(\.value).joined(separator: ";")
        }

        if let totalWeightKey {
            result[totalWeightKey] = String(totalWeight())
        }
        return result
    }

    /// Selected answers for a question, in the server's answer order.
    private func pickedAnswers(at index: Int) -> [AnswerModel] {
        let selectedKeys = selections[index] ?? []
        return questions[index].answers.filter { selectedKeys.contains($0.key) }
    }

    private func answerKeyFor(_ question: QuestionModel, _ answer: AnswerModel) -> String {
        answer.key
    }

    /// Sum of the weights of every selected answer.
    private func totalWeight() -> Int {
        questions.indices.reduce(0) { sum, index in
            sum + pickedAnswers(at: index).reduce(0) { $0 + $1.weight }
        }
    }
}




// MARK: - Screen

public struct QuestionnaireStepScreen: View {

    @StateObject private var viewModel: QuestionnaireStepViewModel
    private let steps = LocalStepsObject.shared.get()

    public init(flowController: FlowController) {
        _viewModel = StateObject(wrappedValue: QuestionnaireStepViewModel(flowController: flowController))
    }

    public var body: some View {
        BaseBackgroundContainer {
            VStack(spacing: 0) {

                // ── TOP (fixed) ──
                VStack(spacing: 10) {
                    ProgressStepperView(steps: steps ?? [], bundle: .main, onBack: { viewModel.onBack() })
                }
                .padding(.top, 20)

                // ── MIDDLE (scrollable) ──
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer().frame(height: 10)

                        switch viewModel.eventType {
                        case .onSend:
                            loadingView
                        case .onError:
                            messageView(viewModel.errorMessage, color: QColors.error)
                        case .onComplete:
                            if let model = viewModel.model {
                                header(model)
                                Spacer().frame(height: 20)

                                if let question = viewModel.currentQuestion {
                                    questionCard(question)
                                        .id(viewModel.currentIndex)
                                        .transition(.opacity)
                                } else {
                                    messageView(FlowStrings.qNoQuestions, color: QColors.text.opacity(0.6))
                                }
                            }
                        }

                        Spacer().frame(height: 16)
                    }
                    .padding(.horizontal, 10)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.currentIndex)
                }

                // ── BOTTOM (fixed) ──
                if viewModel.eventType == .onComplete, let model = viewModel.model {
                    bottomBar(model)
                }
            }
            .topBarBackLogo { viewModel.onBack() }
        }
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .modifier(InterceptSystemBack(action: { viewModel.onBack() }))
        .task { viewModel.startIfNeeded() }
    }

    // MARK: Header (same rules as DocumentCapture)

    @ViewBuilder
    private func header(_ model: QuestionnaireModel) -> some View {
        let hasLogoHeader = !(model.svgLogoUrl ?? "").isEmpty
            && !(model.header ?? "").isEmpty
            && !(model.subHeader ?? "").isEmpty

        if hasLogoHeader {
            VStack(spacing: 0) {
                LogoSvgUrl(url: model.svgLogoUrl ?? "")
                    .frame(width: 70, height: 70)

                Text(model.header ?? "")
                    .font(.system(size: 23, weight: .bold))
                    .foregroundColor(QColors.text)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .padding(.horizontal, 20)

                Text(model.subHeader ?? "")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(QColors.text.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 3)
                    .padding(.horizontal, 20)
            }
        } else if let header = model.header, !header.isEmpty {
            Text(header)
                .font(.system(size: 23, weight: .bold))
                .foregroundColor(QColors.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
                .padding(.horizontal, 20)
        }
    }

    // MARK: Question card

    @ViewBuilder
    private func questionCard(_ question: QuestionModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {

            // "Question 2 of 5" + dots
            VStack(alignment: .leading, spacing: 8) {
                Text(FlowStrings.qQuestionOf(viewModel.currentIndex + 1, viewModel.questions.count))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(QColors.text.opacity(0.6))

                progressDots
            }

            questionImage(question.image)

            VStack(alignment: .leading, spacing: 4) {
                Text(question.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(QColors.text)
                    .fixedSize(horizontal: false, vertical: true)

                if let subTitle = question.subTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !subTitle.isEmpty {
                    Text(subTitle)
                        .font(.system(size: 13))
                        .foregroundColor(QColors.text.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(question.allowMultipleAnswers ? FlowStrings.qSelectMultiple : FlowStrings.qSelectOne)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(QColors.text.opacity(0.5))

            VStack(spacing: 10) {
                ForEach(Array(question.answers.enumerated()), id: \.offset) { _, answer in
                    answerRow(answer, multiple: question.allowMultipleAnswers)
                }
            }

            if viewModel.showRequiredError {
                Text(FlowStrings.qAnswerRequired)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(QColors.error)
            }
        }
        .padding(.horizontal, 20)
    }

    /// Current question = wide pill, answered = faded accent dot, unanswered = grey dot.
    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(viewModel.questions.indices, id: \.self) { index in
                let isCurrent = index == viewModel.currentIndex
                let answered = viewModel.isAnswered(index)

                Capsule()
                    .fill(isCurrent || answered ? QColors.accent : QColors.text.opacity(0.2))
                    .opacity(answered && !isCurrent ? 0.5 : 1)
                    .frame(width: isCurrent ? 22 : 8, height: 8)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.currentIndex)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func questionImage(_ image: String?) -> some View {
        if let image = image?.trimmingCharacters(in: .whitespacesAndNewlines), !image.isEmpty {
            HStack {
                Spacer()
                if image.lowercased().hasSuffix(".svg") {
                    LogoSvgUrl(url: image)
                        .frame(width: 120, height: 120)
                } else if let url = URL(string: image) {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFit()
                    } placeholder: {
                        ProgressView().tint(QColors.text)
                    }
                    .frame(maxHeight: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                Spacer()
            }
        }
    }

    private func answerRow(_ answer: AnswerModel, multiple: Bool) -> some View {
        let selected = viewModel.isSelected(answer)

        return Button {
            viewModel.toggle(answer)
        } label: {
            HStack(spacing: 12) {
                selectionIndicator(selected: selected, multiple: multiple)

                Text(answer.value)
                    .font(.system(size: 15, weight: selected ? .semibold : .regular))
                    .foregroundColor(QColors.text)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(QColors.field)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selected ? QColors.accent : QColors.text.opacity(0.12), lineWidth: selected ? 2 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// Circle for single choice, rounded square for multiple choice.
    @ViewBuilder
    private func selectionIndicator(selected: Bool, multiple: Bool) -> some View {
        if multiple {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(selected ? QColors.accent : QColors.text.opacity(0.4), lineWidth: 2)
                    .frame(width: 22, height: 22)
                if selected {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(QColors.accent)
                        .frame(width: 22, height: 22)
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        } else {
            ZStack {
                Circle()
                    .stroke(selected ? QColors.accent : QColors.text.opacity(0.4), lineWidth: 2)
                    .frame(width: 22, height: 22)
                if selected {
                    Circle()
                        .fill(QColors.accent)
                        .frame(width: 12, height: 12)
                }
            }
        }
    }

    // MARK: Bottom bar (Previous + Next/Finish in one row)

    @ViewBuilder
    private func bottomBar(_ model: QuestionnaireModel) -> some View {
        let useSlider = viewModel.isLast && model.isNormalClick != true

        HStack(spacing: 12) {
            if !viewModel.isFirst {
                previousButton(compact: useSlider)
            }

            if viewModel.isLast {
                finishButton(model)
            } else {
                BaseClickButton(title: FlowStrings.next, verticalPadding: 18, enabled: true) {
                    viewModel.goNext()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    /// Full-width "Previous" next to a click button; a compact back arrow next to the slider.
    private func previousButton(compact: Bool) -> some View {
        Button {
            viewModel.goPrevious()
        } label: {
            Group {
                if compact {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 56, height: 56)
                } else {
                    Text(FlowStrings.qPrevious)
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }
            }
            .foregroundColor(QColors.text)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(QColors.text.opacity(0.3), lineWidth: 1.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(FlowStrings.qPrevious)
    }

    /// Last question: respects isNormalClick like the other steps.
    @ViewBuilder
    private func finishButton(_ model: QuestionnaireModel) -> some View {
        let title = (model.nextButtonTitle?.isEmpty == false) ? model.nextButtonTitle! : FlowStrings.qFinish

        if model.isNormalClick == true {
            BaseClickButton(title: title, verticalPadding: 18, enabled: true) {
                viewModel.goNext()
            }
        } else {
            BaseSliderClick(
                onNext: { viewModel.goNext() },
                label: title,
                icon: "checkmark",
                isActive: true
            )
        }
    }

    // MARK: Loading / messages

    private var loadingView: some View {
        VStack {
            Spacer().frame(height: UIScreen.main.bounds.height * 0.25)
            ProgressView()
                .progressViewStyle(.circular)
                .tint(QColors.text)
                .scaleEffect(1.2)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func messageView(_ message: String, color: Color) -> some View {
        VStack(spacing: 12) {
            Spacer(minLength: 40)
            Text(message)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(color)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity)
    }
}
