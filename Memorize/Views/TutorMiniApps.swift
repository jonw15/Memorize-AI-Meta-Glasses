import SwiftUI

// MARK: - Theme

struct TutorMiniAppTheme {
    let background: Color
    let surface: Color
    let primary: Color
    let primaryText: Color
    let progressActive: Color
    let progressInactive: Color
    let eyebrow: Color
    let title: Color
    let body: Color
    let muted: Color

    static let feynman = TutorMiniAppTheme(
        background: Color(hex: "FEF1F1"),
        surface: Color.white,
        primary: Color(hex: "1F4A2A"),
        primaryText: Color.white,
        progressActive: Color(hex: "1F4A2A"),
        progressInactive: Color(hex: "1F4A2A").opacity(0.18),
        eyebrow: Color(hex: "8D958E"),
        title: Color(hex: "1F2420"),
        body: Color(hex: "3F4642"),
        muted: Color(hex: "8D958E")
    )

    static let leitner = TutorMiniAppTheme(
        background: Color(hex: "FCEFC6"),
        surface: Color.white,
        primary: Color(hex: "8C6A1A"),
        primaryText: Color.white,
        progressActive: Color(hex: "8C6A1A"),
        progressInactive: Color(hex: "8C6A1A").opacity(0.18),
        eyebrow: Color(hex: "8D958E"),
        title: Color(hex: "1F2420"),
        body: Color(hex: "3F4642"),
        muted: Color(hex: "8D958E")
    )

    static let mnemonics = TutorMiniAppTheme(
        background: Color(hex: "FCE9E5"),
        surface: Color.white,
        primary: Color(hex: "7E2A35"),
        primaryText: Color.white,
        progressActive: Color(hex: "7E2A35"),
        progressInactive: Color(hex: "7E2A35").opacity(0.2),
        eyebrow: Color(hex: "8D958E"),
        title: Color(hex: "1F2420"),
        body: Color(hex: "3F4642"),
        muted: Color(hex: "8D958E")
    )

    static let activeRecall = TutorMiniAppTheme(
        background: Color(hex: "E6EEF8"),
        surface: Color.white,
        primary: Color(hex: "1F3F5A"),
        primaryText: Color.white,
        progressActive: Color(hex: "1F3F5A"),
        progressInactive: Color(hex: "1F3F5A").opacity(0.2),
        eyebrow: Color(hex: "8D958E"),
        title: Color(hex: "1F2420"),
        body: Color(hex: "3F4642"),
        muted: Color(hex: "8D958E")
    )

    static let cornell = TutorMiniAppTheme(
        background: Color(hex: "FCE9E5"),
        surface: Color.white,
        primary: Color(hex: "7E2A35"),
        primaryText: Color.white,
        progressActive: Color(hex: "7E2A35"),
        progressInactive: Color(hex: "7E2A35").opacity(0.2),
        eyebrow: Color(hex: "8D958E"),
        title: Color(hex: "1F2420"),
        body: Color(hex: "3F4642"),
        muted: Color(hex: "8D958E")
    )

    static let spaced = TutorMiniAppTheme(
        background: Color(hex: "DDEBD2"),
        surface: Color.white,
        primary: Color(hex: "1F4A2A"),
        primaryText: Color.white,
        progressActive: Color(hex: "1F4A2A"),
        progressInactive: Color(hex: "1F4A2A").opacity(0.18),
        eyebrow: Color(hex: "8D958E"),
        title: Color(hex: "1F2420"),
        body: Color(hex: "3F4642"),
        muted: Color(hex: "8D958E")
    )
}

// MARK: - Mini App Kinds

enum TutorMiniAppKind: String, Identifiable {
    case feynman, leitner, mnemonics, activeRecall, cornell, spaced

    var id: String { rawValue }

    var eyebrow: String {
        switch self {
        case .feynman: return "TUTOR · FEYNMAN TECHNIQUE"
        case .leitner: return "TUTOR · LEITNER SYSTEM"
        case .mnemonics: return "TUTOR · MNEMONICS"
        case .activeRecall: return "TUTOR · ACTIVE RECALL"
        case .cornell: return "TUTOR · CORNELL METHOD"
        case .spaced: return "TUTOR · SPACED REPETITION"
        }
    }

    var theme: TutorMiniAppTheme {
        switch self {
        case .feynman: return .feynman
        case .leitner: return .leitner
        case .mnemonics: return .mnemonics
        case .activeRecall: return .activeRecall
        case .cornell: return .cornell
        case .spaced: return .spaced
        }
    }

    static func fromCardId(_ id: String) -> TutorMiniAppKind? {
        switch id {
        case "feynman": return .feynman
        case "leitner": return .leitner
        case "mnemonics": return .mnemonics
        case "active_recall": return .activeRecall
        case "cornell": return .cornell
        case "spaced": return .spaced
        default: return nil
        }
    }
}

// MARK: - Shared Shell

struct TutorMiniAppShell<Content: View>: View {
    let kind: TutorMiniAppKind
    let stepTitle: String
    let stepIndex: Int
    let stepCount: Int
    let onClose: () -> Void
    let content: () -> Content

    var body: some View {
        let theme = kind.theme
        return VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(theme.title)
                            .frame(width: 30, height: 30)
                            .background(Circle().stroke(Color(hex: "EAE4DC"), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("\(stepIndex + 1) / \(stepCount)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(theme.muted)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(kind.eyebrow)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(0.6)
                        .foregroundColor(theme.eyebrow)

                    Text(stepTitle)
                        .font(.system(size: 24, weight: .regular, design: .serif))
                        .foregroundColor(theme.title)
                }

                HStack(spacing: 6) {
                    ForEach(0..<stepCount, id: \.self) { i in
                        Capsule()
                            .fill(i <= stepIndex ? theme.progressActive : theme.progressInactive)
                            .frame(height: 4)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 14)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface)
            .clipShape(
                UnevenRoundedRectangle(
                    cornerRadii: RectangleCornerRadii(
                        topLeading: 0,
                        bottomLeading: 22,
                        bottomTrailing: 22,
                        topTrailing: 0
                    )
                )
            )

            ScrollView(showsIndicators: false) {
                content()
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                    .padding(.bottom, 24)
            }
        }
        .background(theme.background.ignoresSafeArea())
    }
}

// MARK: - Shared Footer

struct TutorMiniAppFooter: View {
    let theme: TutorMiniAppTheme
    let showBack: Bool
    let primaryTitle: String
    let primaryIcon: String?
    var primaryDisabled: Bool = false
    let onBack: () -> Void
    let onPrimary: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if showBack {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .bold))
                        Text("Back")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(theme.title)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(Color(hex: "EAE4DC"), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            Button(action: onPrimary) {
                HStack(spacing: 6) {
                    Text(primaryTitle)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    if let icon = primaryIcon {
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .bold))
                    }
                }
                .foregroundColor(theme.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(theme.primary)
                .clipShape(Capsule())
                .opacity(primaryDisabled ? 0.45 : 1.0)
            }
            .buttonStyle(.plain)
            .disabled(primaryDisabled)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 18)
        .background(theme.background.ignoresSafeArea(edges: .bottom))
    }
}

// MARK: - Shared Card Helpers

struct TutorSectionLabel: View {
    let text: String
    let theme: TutorMiniAppTheme

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .tracking(0.6)
            .foregroundColor(theme.muted)
    }
}

struct TutorBodyText: View {
    let text: String
    let theme: TutorMiniAppTheme

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .regular, design: .rounded))
            .foregroundColor(theme.body)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct TutorSuccessCard: View {
    let title: String
    let subtitle: String
    let theme: TutorMiniAppTheme

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(theme.primary)
                    .frame(width: 54, height: 54)
                Image(systemName: "checkmark")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            }
            Text(title)
                .font(.system(size: 22, weight: .regular, design: .serif))
                .foregroundColor(theme.title)
            Text(subtitle)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(theme.body)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
        .padding(.vertical, 28)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(hex: "EAE4DC"), lineWidth: 1)
        )
    }
}

func tutorLoadingCard(theme: TutorMiniAppTheme, text: String = "Reading your sources…") -> some View {
    HStack(spacing: 10) {
        ProgressView()
            .tint(theme.primary)
            .scaleEffect(0.85)
        Text(text)
            .font(.system(size: 13, weight: .regular, design: .rounded))
            .foregroundColor(theme.body)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(theme.surface)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))
}

struct TutorThinkingCard: View {
    let theme: TutorMiniAppTheme
    let title: String
    let subtitle: String

    @State private var dotPhase = 0

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(theme.primary)
                        .frame(width: 7, height: 7)
                        .scaleEffect(dotPhase == i ? 1.3 : 0.7)
                        .opacity(dotPhase == i ? 1.0 : 0.4)
                        .animation(.easeInOut(duration: 0.45), value: dotPhase)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(theme.title)
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(theme.body)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(theme.primary.opacity(0.22), lineWidth: 1))
        .onAppear { animate() }
    }

    private func animate() {
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 380_000_000)
                dotPhase = (dotPhase + 1) % 3
            }
        }
    }
}

func tutorErrorCard(theme: TutorMiniAppTheme, message: String) -> some View {
    HStack(spacing: 8) {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 12, weight: .bold))
        Text(message)
            .font(.system(size: 12, weight: .regular, design: .rounded))
    }
    .foregroundColor(Color(hex: "B0444C"))
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(hex: "FCE3E3"))
    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
}

func emptySourcesPlaceholder(theme: TutorMiniAppTheme) -> some View {
    HStack(spacing: 10) {
        Image(systemName: "tray")
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(theme.muted)
        Text("Add a source to see real cards here.")
            .font(.system(size: 13, weight: .regular, design: .rounded))
            .foregroundColor(theme.body)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(theme.surface)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))
}

struct TutorMetric: View {
    let value: String
    let label: String
    let theme: TutorMiniAppTheme

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 26, weight: .regular, design: .serif))
                .foregroundColor(theme.title)
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.6)
                .foregroundColor(theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(hex: "EAE4DC"), lineWidth: 1)
        )
    }
}

// MARK: - Entry View

struct TutorMiniAppView: View {
    let kind: TutorMiniAppKind
    let book: Book
    let onClose: () -> Void

    var body: some View {
        switch kind {
        case .feynman: FeynmanMiniApp(book: book, onClose: onClose)
        case .leitner: LeitnerMiniApp(book: book, onClose: onClose)
        case .mnemonics: MnemonicsMiniApp(book: book, onClose: onClose)
        case .activeRecall: ActiveRecallMiniApp(book: book, onClose: onClose)
        case .cornell: CornellMiniApp(book: book, onClose: onClose)
        case .spaced: SpacedRepetitionMiniApp(book: book, onClose: onClose)
        }
    }
}

// MARK: - Source-derived helpers

struct TutorSourceItem {
    let title: String
    let excerpt: String
}

func tutorSourceItems(from book: Book, limit: Int) -> [TutorSourceItem] {
    var items: [TutorSourceItem] = []
    var seen = Set<String>()

    for source in book.sources {
        let name = source.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, seen.insert(name).inserted else { continue }
        let firstText = source.pages
            .first(where: { $0.status == .completed })?
            .extractedText
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let excerpt = String(firstText.prefix(120))
            .replacingOccurrences(of: "\n", with: " ")
        items.append(TutorSourceItem(title: name, excerpt: excerpt))
        if items.count >= limit { break }
    }

    if items.isEmpty {
        for page in book.pages where page.status == .completed {
            let text = page.extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let title = String(text.split(separator: "\n").first ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let display = title.isEmpty ? String(text.prefix(40)) : title
            guard seen.insert(display).inserted else { continue }
            items.append(TutorSourceItem(title: display, excerpt: String(text.prefix(120))))
            if items.count >= limit { break }
        }
    }

    return items
}

// MARK: - Feynman (4 steps)

private struct FeynmanMiniApp: View {
    let book: Book
    let onClose: () -> Void
    private let kind: TutorMiniAppKind = .feynman
    private let memorizeService = MemorizeService()
    @State private var step = 0
    @State private var teachText = ""
    @State private var refinedText = ""
    @State private var conceptText = ""
    @State private var isLoadingConcept = false
    @State private var conceptError: String?
    @State private var feedback: MemorizeService.FeynmanFeedback?
    @State private var verdict: MemorizeService.FeynmanRefinementVerdict?
    @State private var feedbackError: String?
    @State private var verdictError: String?
    @State private var isLoadingFeedback = false
    @State private var isLoadingVerdict = false

    private var sourceItem: TutorSourceItem? {
        tutorSourceItems(from: book, limit: 1).first
    }

    private var topic: String {
        sourceItem?.title ?? "Your topic"
    }

    private var sourceContext: String {
        let items = tutorSourceItems(from: book, limit: 6)
        return items.map { item in
            "Title: \(item.title)\nExcerpt: \(item.excerpt)"
        }.joined(separator: "\n\n")
    }

    private let stepTitles = [
        "Read the concept",
        "Teach it in simple words",
        "Quick feedback",
        "Improve & simplify",
        "Lesson complete"
    ]

    var body: some View {
        let theme = kind.theme
        VStack(spacing: 0) {
            TutorMiniAppShell(
                kind: kind,
                stepTitle: stepTitles[step],
                stepIndex: step,
                stepCount: stepTitles.count,
                onClose: onClose
            ) {
                Group {
                    switch step {
                    case 0: readConcept(theme: theme)
                    case 1: teachIt(theme: theme)
                    case 2: whereItLanded(theme: theme)
                    case 3: refine(theme: theme)
                    default: wrapUp(theme: theme)
                    }
                }
            }

            TutorMiniAppFooter(
                theme: theme,
                showBack: step > 0,
                primaryTitle: primaryTitle,
                primaryIcon: step == stepTitles.count - 1 ? "checkmark" : "chevron.right",
                primaryDisabled: isPrimaryDisabled,
                onBack: { if step > 0 { step -= 1 } },
                onPrimary: handlePrimary
            )
        }
        .onAppear { requestConceptIfNeeded() }
    }

    private var primaryTitle: String {
        switch step {
        case 0: return "Got it — my turn"
        case 1: return isLoadingFeedback ? "Reading…" : "Get feedback"
        case 2: return "Improve it"
        case 3: return isLoadingVerdict ? "Reading…" : "Lock it in"
        default: return "Finish"
        }
    }

    private var isPrimaryDisabled: Bool {
        switch step {
        case 0:
            return isLoadingConcept || conceptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 1:
            return isLoadingFeedback || teachText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 3:
            return isLoadingVerdict || refinedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return false
        }
    }

    private func handlePrimary() {
        switch step {
        case 0:
            step = 1
        case 1:
            requestFeedback()
        case 2:
            if refinedText.isEmpty {
                refinedText = teachText
            }
            step = 3
        case 3:
            requestVerdict()
        default:
            onClose()
        }
    }

    private func requestConceptIfNeeded() {
        guard conceptText.isEmpty, !isLoadingConcept, !sourceContext.isEmpty else { return }
        isLoadingConcept = true
        conceptError = nil
        Task {
            do {
                let result = try await memorizeService.generateFeynmanConcept(topic: topic, sourceContext: sourceContext)
                await MainActor.run {
                    conceptText = result
                    isLoadingConcept = false
                }
            } catch {
                await MainActor.run {
                    conceptError = error.localizedDescription
                    isLoadingConcept = false
                }
            }
        }
    }

    private func readConcept(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                TutorSectionLabel(text: "TODAY'S CONCEPT", theme: theme)
                Text(topic)
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .foregroundColor(theme.title)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))

            if isLoadingConcept {
                TutorThinkingCard(
                    theme: theme,
                    title: "Pulling a short explanation",
                    subtitle: "Mastery is reading your sources for \(topic)…"
                )
            } else if !conceptText.isEmpty {
                Text(conceptText)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(theme.body)
                    .lineSpacing(4)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))
            }

            if tutorSourceItems(from: book, limit: 1).isEmpty {
                emptySourcesPlaceholder(theme: theme)
            }
            if let conceptError {
                tutorErrorCard(theme: theme, message: conceptError)
            }
        }
    }

    private func requestFeedback() {
        let trimmed = teachText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLoadingFeedback else { return }

        isLoadingFeedback = true
        feedbackError = nil

        Task {
            do {
                let result = try await memorizeService.generateFeynmanFeedback(
                    topic: topic,
                    sourceContext: sourceContext,
                    userExplanation: trimmed
                )
                await MainActor.run {
                    feedback = result
                    isLoadingFeedback = false
                    step = 2
                }
            } catch {
                await MainActor.run {
                    feedbackError = error.localizedDescription
                    isLoadingFeedback = false
                }
            }
        }
    }

    private func requestVerdict() {
        let trimmedRefined = refinedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRefined.isEmpty, !isLoadingVerdict else { return }

        isLoadingVerdict = true
        verdictError = nil

        Task {
            do {
                let result = try await memorizeService.evaluateFeynmanRefinement(
                    topic: topic,
                    sourceContext: sourceContext,
                    initialExplanation: teachText,
                    refinedExplanation: trimmedRefined
                )
                await MainActor.run {
                    verdict = result
                    isLoadingVerdict = false
                    step = 4
                }
            } catch {
                await MainActor.run {
                    verdictError = error.localizedDescription
                    isLoadingVerdict = false
                }
            }
        }
    }

    private func teachIt(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                TutorSectionLabel(text: "TEACHING", theme: theme)
                Text(topic)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(theme.title)
                Text("Pretend a curious 12-year-old is sitting across from you.")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(theme.body)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))

            VStack(alignment: .leading, spacing: 8) {
                TutorSectionLabel(text: "IN YOUR OWN WORDS", theme: theme)
                ZStack(alignment: .topLeading) {
                    if teachText.isEmpty {
                        Text("Start typing your explanation…")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(theme.muted)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                    }
                    TextEditor(text: $teachText)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(Color(hex: "1F2420"))
                        .tint(theme.primary)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(minHeight: 160)
                }
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))
            }

            if isLoadingFeedback {
                TutorThinkingCard(
                    theme: theme,
                    title: "Reading your explanation",
                    subtitle: "Comparing it against the source for \(topic)…"
                )
            }

            if let feedbackError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text(feedbackError)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                }
                .foregroundColor(Color(hex: "B0444C"))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "FCE3E3"))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private func whereItLanded(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            TutorBodyText(
                text: "Mastery read your explanation back against the source. Here's what landed and what to revisit:",
                theme: theme
            )
            if let items = feedback?.landingItems, !items.isEmpty {
                ForEach(items, id: \.title) { item in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle().fill(theme.primary)
                                .frame(width: 28, height: 28)
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(theme.title)
                            Text(item.detail)
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(theme.body)
                                .lineSpacing(2)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))
                }
            } else {
                emptySourcesPlaceholder(theme: theme)
            }
        }
    }

    private func refine(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                TutorSectionLabel(text: "TRY AGAIN — FOCUS ON:", theme: theme)
                FlowChips(
                    items: feedback?.focusChips ?? [],
                    theme: theme
                )
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))

            VStack(alignment: .leading, spacing: 8) {
                TutorSectionLabel(text: "REWRITE IT", theme: theme)
                ZStack(alignment: .topLeading) {
                    if refinedText.isEmpty {
                        Text("Refine your explanation here…")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(theme.muted)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                    }
                    TextEditor(text: $refinedText)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(Color(hex: "1F2420"))
                        .tint(theme.primary)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(minHeight: 160)
                }
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))
            }

            if isLoadingVerdict {
                TutorThinkingCard(
                    theme: theme,
                    title: "Comparing your two attempts",
                    subtitle: "Mastery is reading what changed between drafts…"
                )
            }

            if let verdictError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text(verdictError)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                }
                .foregroundColor(Color(hex: "B0444C"))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "FCE3E3"))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private func wrapUp(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            TutorSuccessCard(
                title: verdict?.headline ?? "You taught it.",
                subtitle: "\(topic) is now in your active recall set. We'll surface it again in 2 days.",
                theme: theme
            )

            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lesson complete")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(theme.title)
                    Text("All 5 steps done. Progress saved.")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(theme.body)
                }
                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.primary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(theme.primary.opacity(0.22), lineWidth: 1))

            HStack(spacing: 10) {
                TutorMetric(
                    value: "\(verdict?.clarityScore ?? 0)/10",
                    label: "CLARITY",
                    theme: theme
                )
                TutorMetric(
                    value: "\(verdict?.improvements.count ?? 0)",
                    label: "IMPROVED",
                    theme: theme
                )
                TutorMetric(
                    value: "\(verdict?.remainingGaps.count ?? 0)",
                    label: "GAPS LEFT",
                    theme: theme
                )
            }

            if let improvements = verdict?.improvements, !improvements.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    TutorSectionLabel(text: "WHAT IMPROVED", theme: theme)
                    ForEach(improvements, id: \.title) { item in
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                Circle().fill(theme.primary)
                                    .frame(width: 24, height: 24)
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(theme.title)
                                Text(item.detail)
                                    .font(.system(size: 13, weight: .regular, design: .rounded))
                                    .foregroundColor(theme.body)
                                    .lineSpacing(2)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))
                    }
                }
            }

            if let gaps = verdict?.remainingGaps, !gaps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    TutorSectionLabel(text: "STILL WORTH REVISITING", theme: theme)
                    FlowChips(items: gaps, theme: theme)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))
            }
        }
    }
}

// MARK: - Leitner (3 steps)

private struct LeitnerMiniApp: View {
    let book: Book
    let onClose: () -> Void
    private let kind: TutorMiniAppKind = .leitner
    private let memorizeService = MemorizeService()
    @State private var step = 0
    @State private var deck: MemorizeService.LeitnerDeck?
    @State private var revealed: Set<Int> = []
    @State private var grades: [Int: Bool] = [:]
    @State private var isLoading = false
    @State private var loadError: String?

    private let stepTitles = ["Today's boxes", "Review queue", "Box movement"]

    private var topic: String {
        tutorSourceItems(from: book, limit: 1).first?.title ?? "Your topic"
    }

    private var sourceContext: String {
        tutorSourceItems(from: book, limit: 6)
            .map { "Title: \($0.title)\nExcerpt: \($0.excerpt)" }
            .joined(separator: "\n\n")
    }

    private var cards: [MemorizeService.LeitnerCard] { deck?.cards ?? [] }

    private var boxCounts: [Int] {
        var counts = [0, 0, 0, 0, 0]
        for card in cards {
            let b = max(1, min(5, card.suggestedBox))
            counts[b - 1] += 1
        }
        return counts
    }

    private struct Movement {
        let card: String
        let from: Int
        let to: Int
        let backwards: Bool
    }

    private var movements: [Movement] {
        cards.enumerated().compactMap { idx, card in
            guard let grade = grades[idx] else { return nil }
            let from = max(1, min(5, card.suggestedBox))
            let to = grade ? min(5, from + 1) : 1
            return Movement(card: card.front, from: from, to: to, backwards: !grade && from > 1)
        }
    }

    private var movedUpCount: Int { movements.filter { !$0.backwards && $0.to > $0.from }.count }
    private var movedBackCount: Int { movements.filter { $0.backwards }.count }

    var body: some View {
        let theme = kind.theme
        VStack(spacing: 0) {
            TutorMiniAppShell(
                kind: kind,
                stepTitle: stepTitles[step],
                stepIndex: step,
                stepCount: stepTitles.count,
                onClose: onClose
            ) {
                Group {
                    switch step {
                    case 0: todaysBoxes(theme: theme)
                    case 1: reviewQueue(theme: theme)
                    default: boxMovement(theme: theme)
                    }
                }
            }

            TutorMiniAppFooter(
                theme: theme,
                showBack: step > 0,
                primaryTitle: footerTitle,
                primaryIcon: step == stepTitles.count - 1 ? "checkmark" : "chevron.right",
                primaryDisabled: footerDisabled,
                onBack: { if step > 0 { step -= 1 } },
                onPrimary: handlePrimary
            )
        }
        .onAppear { loadIfNeeded() }
    }

    private var footerTitle: String {
        switch step {
        case 0: return isLoading ? "Reading…" : "Start review"
        case 1: return "See movement"
        case 2: return "Finish"
        default: return "Next"
        }
    }

    private var footerDisabled: Bool {
        switch step {
        case 0: return isLoading || cards.isEmpty
        case 1: return grades.count < cards.count && !cards.isEmpty
        default: return false
        }
    }

    private func handlePrimary() {
        if step < stepTitles.count - 1 {
            step += 1
        } else {
            onClose()
        }
    }

    private func loadIfNeeded() {
        guard deck == nil, !isLoading, !sourceContext.isEmpty else { return }
        isLoading = true
        loadError = nil
        Task {
            do {
                let result = try await memorizeService.generateLeitnerDeck(topic: topic, sourceContext: sourceContext)
                await MainActor.run {
                    deck = result
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    loadError = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func todaysBoxes(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            TutorBodyText(
                text: deck?.intro ?? "Cards live in five boxes. Get one right and it moves up a box. Miss it and it falls back to box 1.",
                theme: theme
            )

            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(theme.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("DUE TODAY")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(0.5)
                        .foregroundColor(theme.muted)
                    Text("\(cards.count) cards")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundColor(theme.title)
                }
                Spacer()
            }
            .padding(16)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))

            if cards.isEmpty {
                if isLoading {
                    tutorLoadingCard(theme: theme)
                } else {
                    emptySourcesPlaceholder(theme: theme)
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    TutorSectionLabel(text: "YOUR BOXES", theme: theme)
                    ForEach(0..<5, id: \.self) { i in
                        let labels = ["Daily", "Every 2d", "Every 4d", "Weekly", "Monthly"]
                        let details = ["New & shaky", "Getting there", "Steady", "Solid", "Mastered"]
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(theme.primary.opacity(0.12)).frame(width: 28, height: 28)
                                Text("\(i + 1)").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(theme.primary)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(labels[i])
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(theme.title)
                                    Text(details[i])
                                        .font(.system(size: 12, weight: .regular, design: .rounded))
                                        .foregroundColor(theme.muted)
                                }
                            }
                            Spacer()
                            Text("\(boxCounts[i])")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(theme.title)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }

            if let loadError {
                tutorErrorCard(theme: theme, message: loadError)
            }
        }
    }

    private func reviewQueue(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            TutorBodyText(
                text: "Quick rep: see the front, flip to the back, mark how it went. Wrong answers slide back to box 1.",
                theme: theme
            )
            ForEach(Array(cards.enumerated()), id: \.offset) { idx, card in
                cardRow(index: idx, card: card, theme: theme)
            }
        }
    }

    private func cardRow(index: Int, card: MemorizeService.LeitnerCard, theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(card.front)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(theme.title)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Text("Box \(card.suggestedBox)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(theme.muted)
                if !revealed.contains(index) {
                    Button { revealed.insert(index) } label: {
                        Text("Flip")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(theme.primary)
                    }
                }
            }
            if revealed.contains(index) {
                Text(card.back)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(theme.body)
                    .lineSpacing(2)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                HStack(spacing: 8) {
                    Button { grades[index] = true } label: {
                        leitnerChip(text: "Got it", isOn: grades[index] == true, color: theme.primary)
                    }
                    Button { grades[index] = false } label: {
                        leitnerChip(text: "Missed", isOn: grades[index] == false, color: Color(hex: "B0444C"))
                    }
                    Spacer()
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))
    }

    private func leitnerChip(text: String, isOn: Bool, color: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundColor(isOn ? .white : color)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(isOn ? color : color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func boxMovement(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            TutorSuccessCard(
                title: "Boxes updated.",
                subtitle: "\(movedUpCount) moved up, \(movedBackCount) fell back to daily. Tomorrow's queue is set.",
                theme: theme
            )
            HStack(spacing: 10) {
                TutorMetric(value: "\(movements.count)", label: "REVIEWED", theme: theme)
                TutorMetric(value: "\(movedUpCount)", label: "UP", theme: theme)
                TutorMetric(value: "\(movedBackCount)", label: "BACK", theme: theme)
            }
            if !movements.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    TutorSectionLabel(text: "MOVEMENT", theme: theme)
                    ForEach(Array(movements.enumerated()), id: \.offset) { _, mv in
                        HStack {
                            Text(mv.card)
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                                .foregroundColor(theme.title)
                            Spacer()
                            Text("Box \(mv.from)")
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundColor(theme.muted)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(theme.muted)
                            Text("Box \(mv.to)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(mv.backwards ? Color(hex: "B0444C") : theme.primary)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
    }
}

// MARK: - Mnemonics (3 steps)

private struct MnemonicsMiniApp: View {
    let book: Book
    let onClose: () -> Void
    private let kind: TutorMiniAppKind = .mnemonics
    private let memorizeService = MemorizeService()
    @State private var step = 0
    @State private var angles: MemorizeService.MnemonicAngles?
    @State private var isLoading = false
    @State private var loadError: String?

    private let stepTitles = ["Why mnemonics", "Three angles", "Practice it"]

    private var primarySource: TutorSourceItem? {
        tutorSourceItems(from: book, limit: 1).first
    }

    private var topicTitle: String {
        primarySource?.title ?? "your topic"
    }

    private var sourceContext: String {
        tutorSourceItems(from: book, limit: 6)
            .map { "Title: \($0.title)\nExcerpt: \($0.excerpt)" }
            .joined(separator: "\n\n")
    }

    var body: some View {
        let theme = kind.theme
        VStack(spacing: 0) {
            TutorMiniAppShell(
                kind: kind,
                stepTitle: stepTitles[step],
                stepIndex: step,
                stepCount: stepTitles.count,
                onClose: onClose
            ) {
                Group {
                    switch step {
                    case 0: whyMnemonics(theme: theme)
                    case 1: threeAngles(theme: theme)
                    default: practiceIt(theme: theme)
                    }
                }
            }

            TutorMiniAppFooter(
                theme: theme,
                showBack: step > 0,
                primaryTitle: step == 0 ? (isLoading ? "Reading…" : "See angles") : (step == 1 ? "Practice it" : "Finish"),
                primaryIcon: step == stepTitles.count - 1 ? "checkmark" : "chevron.right",
                primaryDisabled: (step == 0 && isLoading) || primarySource == nil,
                onBack: { if step > 0 { step -= 1 } },
                onPrimary: handlePrimary
            )
        }
    }

    private func handlePrimary() {
        if step == 0 {
            requestAngles()
            return
        }
        if step < stepTitles.count - 1 {
            step += 1
        } else {
            onClose()
        }
    }

    private func requestAngles() {
        guard primarySource != nil, !isLoading else { return }
        if angles != nil {
            step = 1
            return
        }
        isLoading = true
        loadError = nil
        Task {
            do {
                let result = try await memorizeService.generateMnemonics(topic: topicTitle, sourceContext: sourceContext)
                await MainActor.run {
                    angles = result
                    isLoading = false
                    step = 1
                }
            } catch {
                await MainActor.run {
                    loadError = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func whyMnemonics(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            TutorBodyText(
                text: "Memory loves vivid hooks. A good mnemonic stitches dry facts onto something your brain already remembers — a sound, a story, a place.",
                theme: theme
            )
            VStack(alignment: .leading, spacing: 10) {
                TutorSectionLabel(text: "WHAT YOU'LL DO", theme: theme)
                ForEach(Array(zip(["1", "2", "3"], ["Get three angles on the same idea", "Pick the one that sticks", "Lock it in with a quick recall"])), id: \.0) { num, text in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle().fill(theme.primary.opacity(0.12)).frame(width: 24, height: 24)
                            Text(num).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(theme.primary)
                        }
                        Text(text)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(theme.body)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                }
            }
            .padding(16)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))

            if primarySource == nil {
                emptySourcesPlaceholder(theme: theme)
            }
            if isLoading {
                TutorThinkingCard(
                    theme: theme,
                    title: "Building three angles",
                    subtitle: "Mastery is hooking the key terms onto memory anchors…"
                )
            }
            if let loadError {
                tutorErrorCard(theme: theme, message: loadError)
            }
        }
    }

    private func threeAngles(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            TutorBodyText(
                text: "Mastery built three different ways to lock \(topicTitle) into memory. Pick the one that sticks for you.",
                theme: theme
            )
            if let angles {
                angleCard(label: "ACRONYM", heading: angles.acronymTitle, detail: angles.acronymBody, theme: theme)
                angleCard(label: "STORY", heading: angles.storyTitle, detail: angles.storyBody, theme: theme)
                angleCard(label: "MEMORY PALACE", heading: angles.palaceTitle, detail: angles.palaceBody, theme: theme)
            } else {
                tutorLoadingCard(theme: theme)
            }
        }
    }

    private func angleCard(label: String, heading: String, detail: String, theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TutorSectionLabel(text: label, theme: theme)
            Text(heading)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(theme.title)
            Text(detail)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(theme.body)
                .lineSpacing(2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))
    }

    private func practiceIt(theme: TutorMiniAppTheme) -> some View {
        VStack(spacing: 14) {
            TutorSuccessCard(
                title: "Anchored.",
                subtitle: "Your mnemonic for \(topicTitle) is saved. We'll bring it back tomorrow to test the hook.",
                theme: theme
            )
            HStack(spacing: 10) {
                TutorMetric(value: "3", label: "ANGLES", theme: theme)
                TutorMetric(value: "1", label: "ANCHOR", theme: theme)
                TutorMetric(value: "+1", label: "MASTERY", theme: theme)
            }
        }
    }
}

// MARK: - Active Recall (3 steps)

private struct ActiveRecallMiniApp: View {
    let book: Book
    let onClose: () -> Void
    private let kind: TutorMiniAppKind = .activeRecall
    private let memorizeService = MemorizeService()
    @State private var step = 0
    @State private var recallSet: MemorizeService.ActiveRecallSet?
    @State private var revealed: Set<Int> = []
    @State private var grades: [Int: Bool] = [:]
    @State private var isLoading = false
    @State private var loadError: String?

    private let stepTitles = ["Why this works", "Retrieval round", "How it went"]

    private var topic: String {
        tutorSourceItems(from: book, limit: 1).first?.title ?? "Your topic"
    }

    private var sourceContext: String {
        tutorSourceItems(from: book, limit: 6)
            .map { "Title: \($0.title)\nExcerpt: \($0.excerpt)" }
            .joined(separator: "\n\n")
    }

    private var rightCount: Int { grades.values.filter { $0 }.count }
    private var missCount: Int { grades.values.filter { !$0 }.count }
    private var totalCount: Int { recallSet?.questions.count ?? 0 }

    var body: some View {
        let theme = kind.theme
        VStack(spacing: 0) {
            TutorMiniAppShell(
                kind: kind,
                stepTitle: stepTitles[step],
                stepIndex: step,
                stepCount: stepTitles.count,
                onClose: onClose
            ) {
                Group {
                    switch step {
                    case 0: whyItWorks(theme: theme)
                    case 1: retrieval(theme: theme)
                    default: howItWent(theme: theme)
                    }
                }
            }

            TutorMiniAppFooter(
                theme: theme,
                showBack: step > 0,
                primaryTitle: footerTitle,
                primaryIcon: step == stepTitles.count - 1 ? "checkmark" : "chevron.right",
                primaryDisabled: footerDisabled,
                onBack: { if step > 0 { step -= 1 } },
                onPrimary: handlePrimary
            )
        }
    }

    private var footerTitle: String {
        switch step {
        case 0: return isLoading ? "Reading…" : "Begin retrieval"
        case 1: return "See score"
        default: return "Finish"
        }
    }

    private var footerDisabled: Bool {
        switch step {
        case 0: return isLoading || tutorSourceItems(from: book, limit: 1).isEmpty
        case 1: return grades.count < totalCount && totalCount > 0
        default: return false
        }
    }

    private func handlePrimary() {
        if step == 0 {
            requestQuestions()
            return
        }
        if step < stepTitles.count - 1 {
            step += 1
        } else {
            onClose()
        }
    }

    private func requestQuestions() {
        guard !isLoading else { return }
        if recallSet != nil {
            step = 1
            return
        }
        isLoading = true
        loadError = nil
        Task {
            do {
                let result = try await memorizeService.generateActiveRecallSet(topic: topic, sourceContext: sourceContext)
                await MainActor.run {
                    recallSet = result
                    isLoading = false
                    step = 1
                }
            } catch {
                await MainActor.run {
                    loadError = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func whyItWorks(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                TutorSectionLabel(text: "WHY THIS WORKS", theme: theme)
                Text("Pulling beats re-reading.")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundColor(theme.title)
                Text("Re-reading feels productive but the memory trace doesn't deepen. Forcing yourself to retrieve — even when you almost can't — is what makes it stick.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(theme.body)
                    .lineSpacing(3)
            }
            VStack(spacing: 10) {
                tip(num: "1", title: "Close the book", detail: "Try to answer before peeking. Effort is the point.", theme: theme)
                tip(num: "2", title: "Wrong is fine", detail: "A near-miss strengthens memory more than a confident look-up.", theme: theme)
                tip(num: "3", title: "Five questions", detail: "Pulled from your sources you haven't reviewed in a while.", theme: theme)
            }
            HStack(spacing: 10) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(theme.primary)
                Text("Tip: say your answer out loud before you tap — speaking forces commitment.")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(theme.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(theme.primary.opacity(0.18), lineWidth: 1))

            if tutorSourceItems(from: book, limit: 1).isEmpty {
                emptySourcesPlaceholder(theme: theme)
            }
            if isLoading {
                TutorThinkingCard(
                    theme: theme,
                    title: "Pulling 5 retrieval prompts",
                    subtitle: "Mastery is sweeping your sources for what to test…"
                )
            }
            if let loadError {
                tutorErrorCard(theme: theme, message: loadError)
            }
        }
    }

    private func tip(num: String, title: String, detail: String, theme: TutorMiniAppTheme) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(theme.primary.opacity(0.12)).frame(width: 28, height: 28)
                Text(num).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(theme.primary)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(theme.title)
                Text(detail)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(theme.body)
                    .lineSpacing(2)
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))
    }

    private func retrieval(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TutorBodyText(text: "One question at a time. Try in your head, reveal the answer, then mark how you did.", theme: theme)
            if let recallSet, !recallSet.questions.isEmpty {
                ForEach(Array(recallSet.questions.enumerated()), id: \.offset) { idx, q in
                    questionRow(index: idx, question: q, theme: theme)
                }
            } else {
                tutorLoadingCard(theme: theme)
            }
        }
    }

    private func questionRow(index: Int, question: MemorizeService.ActiveRecallQuestion, theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(question.prompt)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(theme.title)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                if !revealed.contains(index) {
                    Button {
                        revealed.insert(index)
                    } label: {
                        Text("Reveal")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(theme.primary)
                    }
                }
            }

            if revealed.contains(index) {
                Text(question.answer)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(theme.body)
                    .lineSpacing(2)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                HStack(spacing: 8) {
                    Button { grades[index] = true } label: {
                        gradeChip(text: "Got it", isOn: grades[index] == true, color: theme.primary, theme: theme)
                    }
                    Button { grades[index] = false } label: {
                        gradeChip(text: "Missed", isOn: grades[index] == false, color: Color(hex: "B0444C"), theme: theme)
                    }
                    Spacer()
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))
    }

    private func gradeChip(text: String, isOn: Bool, color: Color, theme: TutorMiniAppTheme) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundColor(isOn ? .white : color)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(isOn ? color : color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func howItWent(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            TutorSuccessCard(
                title: totalCount > 0 ? "\(rightCount) / \(totalCount) retrieved." : "No questions",
                subtitle: missCount == 0
                    ? "Clean round. We'll stretch the next interval."
                    : "\(missCount) slipped — we'll bring \(missCount == 1 ? "it" : "them") back tomorrow when it's almost faded.",
                theme: theme
            )
            HStack(spacing: 10) {
                TutorMetric(value: "\(rightCount)", label: "RIGHT", theme: theme)
                TutorMetric(value: "\(missCount)", label: "MISS", theme: theme)
                TutorMetric(value: "\(totalCount)", label: "TOTAL", theme: theme)
            }
            if let questions = recallSet?.questions, !questions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    TutorSectionLabel(text: "QUESTION BY QUESTION", theme: theme)
                    ForEach(Array(questions.enumerated()), id: \.offset) { idx, q in
                        let correct = grades[idx] == true
                        HStack(spacing: 10) {
                            ZStack {
                                Circle().fill(correct ? theme.primary.opacity(0.15) : Color(hex: "B0444C").opacity(0.18)).frame(width: 22, height: 22)
                                Image(systemName: correct ? "checkmark" : "xmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(correct ? theme.primary : Color(hex: "B0444C"))
                            }
                            Text(q.prompt)
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(theme.title)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
    }
}

// MARK: - Cornell Method (3 steps)

private struct CornellMiniApp: View {
    let book: Book
    let onClose: () -> Void
    private let kind: TutorMiniAppKind = .cornell
    private let memorizeService = MemorizeService()
    @State private var step = 0
    @State private var cornellSet: MemorizeService.CornellSet?
    @State private var revealed: Set<Int> = []
    @State private var summaryText = ""
    @State private var isLoading = false
    @State private var loadError: String?

    private let stepTitles = ["Read the notes", "Recall by cue", "Write summary"]

    private var topic: String {
        tutorSourceItems(from: book, limit: 1).first?.title ?? "Your topic"
    }

    private var sourceContext: String {
        tutorSourceItems(from: book, limit: 6)
            .map { "Title: \($0.title)\nExcerpt: \($0.excerpt)" }
            .joined(separator: "\n\n")
    }

    var body: some View {
        let theme = kind.theme
        VStack(spacing: 0) {
            TutorMiniAppShell(
                kind: kind,
                stepTitle: stepTitles[step],
                stepIndex: step,
                stepCount: stepTitles.count,
                onClose: onClose
            ) {
                Group {
                    switch step {
                    case 0: readNotes(theme: theme)
                    case 1: recallByCue(theme: theme)
                    default: writeSummary(theme: theme)
                    }
                }
            }

            TutorMiniAppFooter(
                theme: theme,
                showBack: step > 0,
                primaryTitle: footerTitle,
                primaryIcon: step == stepTitles.count - 1 ? "checkmark" : "chevron.right",
                primaryDisabled: footerDisabled,
                onBack: { if step > 0 { step -= 1 } },
                onPrimary: handlePrimary
            )
        }
        .onAppear { loadIfNeeded() }
    }

    private var footerTitle: String {
        switch step {
        case 0: return isLoading ? "Reading…" : "Cover & recall"
        case 1: return "Write summary"
        case 2: return "Finish"
        default: return "Next"
        }
    }

    private var footerDisabled: Bool {
        switch step {
        case 0: return isLoading || cornellSet == nil
        default: return false
        }
    }

    private func handlePrimary() {
        if step < stepTitles.count - 1 {
            step += 1
        } else {
            onClose()
        }
    }

    private func loadIfNeeded() {
        guard cornellSet == nil, !isLoading, !sourceContext.isEmpty else { return }
        isLoading = true
        loadError = nil
        Task {
            do {
                let result = try await memorizeService.generateCornellSet(topic: topic, sourceContext: sourceContext)
                await MainActor.run {
                    cornellSet = result
                    summaryText = result.summaryStarter
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    loadError = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func readNotes(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            TutorBodyText(
                text: "Mastery split your sources into cues and body — Cornell style. Read through once, then on the next step we cover the body and you answer the cues.",
                theme: theme
            )
            if let rows = cornellSet?.rows, !rows.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                        HStack(alignment: .top, spacing: 0) {
                            Text(row.cue)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(theme.primary)
                                .frame(width: 110, alignment: .leading)
                                .padding(.vertical, 12)
                                .padding(.leading, 12)
                            Rectangle().fill(Color(hex: "EAE4DC")).frame(width: 1)
                            Text(row.body)
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(theme.body)
                                .lineSpacing(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 12)
                        }
                        if idx < rows.count - 1 {
                            Rectangle().fill(Color(hex: "EAE4DC")).frame(height: 1)
                        }
                    }
                }
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))
            } else if isLoading {
                tutorLoadingCard(theme: theme)
            } else {
                emptySourcesPlaceholder(theme: theme)
            }
            if let loadError {
                tutorErrorCard(theme: theme, message: loadError)
            }
        }
    }

    private func recallByCue(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TutorBodyText(text: "Tap each cue and answer it out loud before revealing.", theme: theme)
            if let rows = cornellSet?.rows {
                ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("CUE")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(0.5)
                                .foregroundColor(theme.muted)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(theme.primary.opacity(0.1))
                                .clipShape(Capsule())
                            Text(row.cue)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(theme.title)
                            Spacer()
                            if !revealed.contains(idx) {
                                Button {
                                    revealed.insert(idx)
                                } label: {
                                    Text("Reveal")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(theme.primary)
                                }
                            }
                        }
                        if revealed.contains(idx) {
                            Text(row.body)
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(theme.body)
                                .lineSpacing(2)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(theme.primary.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))
                }
            }
        }
    }

    private func writeSummary(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            TutorBodyText(text: "Pull it together: write a one-paragraph summary in your own words.", theme: theme)

            VStack(alignment: .leading, spacing: 8) {
                TutorSectionLabel(text: "YOUR SUMMARY", theme: theme)
                TextEditor(text: $summaryText)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(Color(hex: "1F2420"))
                    .tint(theme.primary)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(minHeight: 160)
                    .background(theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))
            }

            HStack(spacing: 10) {
                TutorMetric(value: "\(cornellSet?.rows.count ?? 0)", label: "CUES", theme: theme)
                TutorMetric(value: "\(revealed.count)", label: "REVEALED", theme: theme)
                TutorMetric(value: "+1", label: "MASTERY", theme: theme)
            }
        }
    }
}

// MARK: - Spaced Repetition (3 steps)

private struct SpacedRepetitionMiniApp: View {
    let book: Book
    let onClose: () -> Void
    private let kind: TutorMiniAppKind = .spaced
    private let memorizeService = MemorizeService()
    @State private var step = 0
    @State private var schedule: MemorizeService.SpacedSchedule?
    @State private var revealed: Set<Int> = []
    @State private var grades: [Int: Bool] = [:]
    @State private var isLoading = false
    @State private var loadError: String?

    private let stepTitles = ["The forgetting curve", "Today's review", "Next reviews"]

    private var topic: String {
        tutorSourceItems(from: book, limit: 1).first?.title ?? "Your topic"
    }

    private var sourceContext: String {
        tutorSourceItems(from: book, limit: 6)
            .map { "Title: \($0.title)\nExcerpt: \($0.excerpt)" }
            .joined(separator: "\n\n")
    }

    private var dueCards: [MemorizeService.SpacedReview] { schedule?.dueNow ?? [] }
    private var upcomingCards: [MemorizeService.SpacedReview] { schedule?.upcoming ?? [] }

    private var dueCount: Int { dueCards.count }

    private var avgInterval: Double {
        let all = dueCards + upcomingCards
        guard !all.isEmpty else { return 0 }
        return Double(all.map(\.intervalDays).reduce(0, +)) / Double(all.count)
    }

    var body: some View {
        let theme = kind.theme
        VStack(spacing: 0) {
            TutorMiniAppShell(
                kind: kind,
                stepTitle: stepTitles[step],
                stepIndex: step,
                stepCount: stepTitles.count,
                onClose: onClose
            ) {
                Group {
                    switch step {
                    case 0: forgettingCurve(theme: theme)
                    case 1: todaysReview(theme: theme)
                    default: nextReviews(theme: theme)
                    }
                }
            }

            TutorMiniAppFooter(
                theme: theme,
                showBack: step > 0,
                primaryTitle: footerTitle,
                primaryIcon: step == stepTitles.count - 1 ? "checkmark" : "chevron.right",
                primaryDisabled: footerDisabled,
                onBack: { if step > 0 { step -= 1 } },
                onPrimary: handlePrimary
            )
        }
        .onAppear { loadIfNeeded() }
    }

    private var footerTitle: String {
        switch step {
        case 0: return isLoading ? "Reading…" : "Review now"
        case 1: return "See schedule"
        case 2: return "Finish"
        default: return "Next"
        }
    }

    private var footerDisabled: Bool {
        switch step {
        case 0: return isLoading || dueCards.isEmpty
        case 1: return grades.count < dueCards.count && !dueCards.isEmpty
        default: return false
        }
    }

    private func handlePrimary() {
        if step < stepTitles.count - 1 {
            step += 1
        } else {
            onClose()
        }
    }

    private func loadIfNeeded() {
        guard schedule == nil, !isLoading, !sourceContext.isEmpty else { return }
        isLoading = true
        loadError = nil
        Task {
            do {
                let result = try await memorizeService.generateSpacedSchedule(topic: topic, sourceContext: sourceContext)
                await MainActor.run {
                    schedule = result
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    loadError = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func forgettingCurve(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            TutorBodyText(
                text: "Without review, you forget most new material within a week. Each well-timed review resets the curve and pushes the next forgetting further out.",
                theme: theme
            )
            VStack(alignment: .leading, spacing: 8) {
                Text("FORGETTING CURVE · EBBINGHAUS")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(0.6)
                    .foregroundColor(theme.muted)
                ForgettingCurveChart(theme: theme)
                    .frame(height: 120)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))

            HStack(spacing: 10) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(theme.primary)
                Text(schedule?.intro ?? (dueCount > 0
                    ? "\(dueCount) cards due now. Reviewing today protects weeks of work."
                    : "Add a source to start your review queue."))
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(theme.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(theme.primary.opacity(0.18), lineWidth: 1))

            if let loadError {
                tutorErrorCard(theme: theme, message: loadError)
            }
        }
    }

    private func todaysReview(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TutorBodyText(
                text: dueCards.isEmpty
                    ? "Add a source to populate your spaced repetition queue."
                    : "\(dueCards.count) cards. Tap reveal, then mark how you did.",
                theme: theme
            )
            if dueCards.isEmpty && isLoading {
                tutorLoadingCard(theme: theme)
            } else if dueCards.isEmpty {
                emptySourcesPlaceholder(theme: theme)
            }
            ForEach(Array(dueCards.enumerated()), id: \.offset) { idx, card in
                spacedCardRow(index: idx, card: card, theme: theme)
            }
        }
    }

    private func spacedCardRow(index: Int, card: MemorizeService.SpacedReview, theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(card.card)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(theme.title)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                if !revealed.contains(index) {
                    Button { revealed.insert(index) } label: {
                        Text("Reveal")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(theme.primary)
                    }
                }
            }
            if revealed.contains(index) {
                Text(card.answer)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(theme.body)
                    .lineSpacing(2)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                HStack(spacing: 8) {
                    Button { grades[index] = true } label: {
                        spacedChip(text: "Got it", isOn: grades[index] == true, color: theme.primary)
                    }
                    Button { grades[index] = false } label: {
                        spacedChip(text: "Missed", isOn: grades[index] == false, color: Color(hex: "B0444C"))
                    }
                    Spacer()
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))
    }

    private func spacedChip(text: String, isOn: Bool, color: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundColor(isOn ? .white : color)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(isOn ? color : color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func nextReviews(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            TutorSuccessCard(
                title: "Schedule rebuilt.",
                subtitle: "Mastery rebalanced your intervals based on how this round went.",
                theme: theme
            )
            HStack(spacing: 10) {
                TutorMetric(value: "\(grades.count)", label: "REVIEWED", theme: theme)
                TutorMetric(value: "\(dueCards.count + upcomingCards.count)", label: "SCHEDULED", theme: theme)
                TutorMetric(value: avgInterval > 0 ? String(format: "%.1fd", avgInterval) : "—", label: "AVG INTERVAL", theme: theme)
            }
            if !upcomingCards.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    TutorSectionLabel(text: "COMING UP", theme: theme)
                    ForEach(Array(upcomingCards.enumerated()), id: \.offset) { _, up in
                        HStack(spacing: 12) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(theme.primary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("In \(up.intervalDays) day\(up.intervalDays == 1 ? "" : "s")")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(theme.title)
                                Text(up.card)
                                    .font(.system(size: 12, weight: .regular, design: .rounded))
                                    .foregroundColor(theme.muted)
                                    .lineLimit(2)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .background(theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
    }
}

// MARK: - Forgetting Curve Chart

private struct ForgettingCurveChart: View {
    let theme: TutorMiniAppTheme

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                Path { path in
                    let baseline = CGFloat(0.92)
                    let segments: [(start: CGFloat, end: CGFloat)] = [
                        (0.00, 0.20),
                        (0.20, 0.45),
                        (0.45, 0.70),
                        (0.70, 1.00)
                    ]
                    for (i, seg) in segments.enumerated() {
                        let startY: CGFloat = i == 0 ? 0.10 : 0.18
                        let endY: CGFloat = baseline - CGFloat(segments.count - 1 - i) * 0.06
                        let x0 = w * seg.start
                        let x1 = w * seg.end
                        if i == 0 {
                            path.move(to: CGPoint(x: x0, y: h * startY))
                        } else {
                            path.move(to: CGPoint(x: x0, y: h * 0.10))
                        }
                        path.addCurve(
                            to: CGPoint(x: x1, y: h * endY),
                            control1: CGPoint(x: x0 + (x1 - x0) * 0.35, y: h * (startY + 0.45)),
                            control2: CGPoint(x: x0 + (x1 - x0) * 0.7, y: h * (endY - 0.05))
                        )
                    }
                }
                .stroke(theme.primary, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                ForEach([0.20, 0.45, 0.70], id: \.self) { x in
                    Circle()
                        .fill(theme.primary)
                        .frame(width: 6, height: 6)
                        .position(x: w * x, y: h * 0.10)
                }

                Path { path in
                    path.move(to: CGPoint(x: 0, y: h * 0.95))
                    path.addLine(to: CGPoint(x: w, y: h * 0.95))
                }
                .stroke(theme.muted.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

                VStack {
                    HStack {
                        Text("100%")
                            .font(.system(size: 9, weight: .regular, design: .rounded))
                            .foregroundColor(theme.muted)
                        Spacer()
                        Text("Review")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(theme.primary)
                            .position(x: w * 0.20, y: -2)
                            .frame(width: 0, height: 0, alignment: .center)
                        Text("Review")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(theme.primary)
                            .position(x: w * 0.45, y: -2)
                            .frame(width: 0, height: 0, alignment: .center)
                        Text("Review")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(theme.primary)
                            .position(x: w * 0.70, y: -2)
                            .frame(width: 0, height: 0, alignment: .center)
                    }
                    Spacer()
                    HStack {
                        Text("0%")
                            .font(.system(size: 9, weight: .regular, design: .rounded))
                            .foregroundColor(theme.muted)
                        Spacer()
                    }
                }
            }
        }
    }
}

// MARK: - FlowChips

private struct FlowChips: View {
    let items: [String]
    let theme: TutorMiniAppTheme

    var body: some View {
        TutorFlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(theme.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(theme.primary.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
    }
}

private struct TutorFlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        let rows = rows(for: subviews, maxWidth: maxWidth)
        let height = rows.reduce(CGFloat.zero) { total, row in total + row.height }
            + CGFloat(max(rows.count - 1, 0)) * lineSpacing
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = rows(for: subviews, maxWidth: bounds.width)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for item in row.items {
                item.subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(item.size))
                x += item.size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private func rows(for subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var currentItems: [RowItem] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let nextWidth = currentItems.isEmpty ? size.width : currentWidth + spacing + size.width
            if nextWidth > maxWidth && !currentItems.isEmpty {
                rows.append(Row(items: currentItems, height: currentHeight))
                currentItems = []
                currentWidth = 0
                currentHeight = 0
            }
            currentItems.append(RowItem(subview: subview, size: size))
            currentWidth = currentItems.count == 1 ? size.width : currentWidth + spacing + size.width
            currentHeight = max(currentHeight, size.height)
        }
        if !currentItems.isEmpty {
            rows.append(Row(items: currentItems, height: currentHeight))
        }
        return rows
    }

    private struct Row {
        let items: [RowItem]
        let height: CGFloat
    }

    private struct RowItem {
        let subview: LayoutSubview
        let size: CGSize
    }
}
