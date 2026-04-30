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
    case feynman, leitner, mnemonics, activeRecall, cornell, spaced, findMistake

    var id: String { rawValue }

    var eyebrow: String {
        switch self {
        case .feynman: return "TUTOR · FEYNMAN TECHNIQUE"
        case .leitner: return "TUTOR · LEITNER SYSTEM"
        case .mnemonics: return "TUTOR · MNEMONICS"
        case .activeRecall: return "TUTOR · ACTIVE RECALL"
        case .cornell: return "TUTOR · CORNELL METHOD"
        case .spaced: return "TUTOR · SPACED REPETITION"
        case .findMistake: return "TUTOR · FIND THE MISTAKE"
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
        case .findMistake: return .activeRecall
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
        case "find_mistake": return .findMistake
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
    var counterOverride: String? = nil
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

                    Text(counterOverride ?? "\(stepIndex + 1) / \(stepCount)")
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
    var onSessionComplete: (String, String) -> Void = { _, _ in }

    var body: some View {
        switch kind {
        case .feynman: FeynmanMiniApp(book: book, onClose: onClose, onSessionComplete: onSessionComplete)
        case .leitner: LeitnerMiniApp(book: book, onClose: onClose)
        case .mnemonics: MnemonicsMiniApp(book: book, onClose: onClose, onSessionComplete: onSessionComplete)
        case .activeRecall: ActiveRecallMiniApp(book: book, onClose: onClose)
        case .cornell: CornellMiniApp(book: book, onClose: onClose, onSessionComplete: onSessionComplete)
        case .spaced: SpacedRepetitionMiniApp(book: book, onClose: onClose)
        case .findMistake: FindMistakeMiniApp(book: book, onClose: onClose, onSessionComplete: onSessionComplete)
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
        items.append(TutorSourceItem(title: name, excerpt: tutorTrimExcerpt(firstText, maxLength: 200)))
        if items.count >= limit { break }
    }

    if items.isEmpty {
        for page in book.pages where page.status == .completed {
            let text = page.extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let title = String(text.split(separator: "\n").first ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let display = title.isEmpty ? String(text.prefix(40)) : title
            guard seen.insert(display).inserted else { continue }
            items.append(TutorSourceItem(title: display, excerpt: tutorTrimExcerpt(text, maxLength: 200)))
            if items.count >= limit { break }
        }
    }

    return items
}

/// Build the full source-context string the tutor mini-apps feed to the AI.
/// Pulls every uploaded source (and legacy camera pages) and concatenates all of their
/// completed pages — no character cap. Gemini Flash's input window (~1M tokens / ~4M chars)
/// comfortably handles even a multi-source project.
func tutorFullSourceContext(from book: Book) -> String {
    var blocks: [String] = []

    for source in book.sources {
        let title = source.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { continue }
        let combined = source.pages
            .filter { $0.status == .completed }
            .map { $0.extractedText }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !combined.isEmpty else { continue }
        blocks.append("Source: \(title)\n\(combined)")
    }

    if blocks.isEmpty {
        let legacy = book.pages
            .filter { $0.status == .completed }
            .map { $0.extractedText }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !legacy.isEmpty {
            blocks.append("Source: Camera notes\n\(legacy)")
        }
    }

    return blocks.joined(separator: "\n\n---\n\n")
}

private func tutorTrimExcerpt(_ raw: String, maxLength: Int) -> String {
    let cleaned = raw
        .replacingOccurrences(of: "\n", with: " ")
        .replacingOccurrences(of: "  ", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard cleaned.count > maxLength else { return cleaned }

    let cutoff = cleaned.index(cleaned.startIndex, offsetBy: maxLength)
    let prefix = String(cleaned[..<cutoff])

    // Prefer ending on a sentence boundary, fall back to word boundary, then hard cut + ellipsis.
    if let sentenceEnd = prefix.lastIndex(where: { ".!?".contains($0) }) {
        let untilEnd = prefix[..<prefix.index(after: sentenceEnd)]
        if untilEnd.count >= 60 { // require at least one decent sentence before truncating
            return String(untilEnd)
        }
    }

    if let lastSpace = prefix.lastIndex(of: " ") {
        return String(prefix[..<lastSpace]) + "…"
    }

    return prefix + "…"
}

// MARK: - Feynman (4 steps)

private struct FeynmanMiniApp: View {
    let book: Book
    let onClose: () -> Void
    var onSessionComplete: (String, String) -> Void = { _, _ in }
    private let kind: TutorMiniAppKind = .feynman
    private let memorizeService = MemorizeService()
    @State private var step = 0
    @State private var hasSavedSession = false
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
        tutorFullSourceContext(from: book)
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
                    subtitle: "Reading your sources for \(topic)…"
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
                    saveFeynmanSession()
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
                text: "We read your explanation back against the source. Here's what landed and what to revisit:",
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
                    subtitle: "Reading what changed between drafts…"
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

    private func saveFeynmanSession() {
        guard !hasSavedSession else { return }
        hasSavedSession = true
        var lines: [String] = [
            "Feynman Technique session — \(topic)",
            "",
            "Verdict: \(verdict?.headline ?? "Session complete")",
            "Clarity: \(verdict?.clarityScore ?? 0)/10",
            ""
        ]
        if !teachText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("First explanation:")
            lines.append(teachText)
            lines.append("")
        }
        if !refinedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("Refined explanation:")
            lines.append(refinedText)
            lines.append("")
        }
        if let improvements = verdict?.improvements, !improvements.isEmpty {
            lines.append("What improved:")
            improvements.forEach { lines.append("- \($0.title): \($0.detail)") }
            lines.append("")
        }
        if let gaps = verdict?.remainingGaps, !gaps.isEmpty {
            lines.append("Still worth revisiting: \(gaps.joined(separator: ", "))")
        }
        let rawData = lines.joined(separator: "\n")
        // Try to add an AI recap on top; fall back to raw body if AI fails.
        Task {
            let summary = (try? await memorizeService.summarizeTutorSession(
                sessionType: "Feynman Technique",
                topic: topic,
                rawSessionData: rawData
            )) ?? ""
            let body = summary.isEmpty ? rawData : "\(summary)\n\n— — —\n\n\(rawData)"
            await MainActor.run {
                onSessionComplete(topic, body)
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
        tutorFullSourceContext(from: book)
    }

    private var cards: [MemorizeService.LeitnerCard] { deck?.cards ?? [] }

    private var boxCounts: [Int] {
        var counts = [0, 0, 0, 0, 0]
        for card in cards {
            let b = max(1, min(5, card.box))
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
            let from = max(1, min(5, card.box))
            let to = grade ? min(5, from + 1) : 1
            return Movement(card: card.front, from: from, to: to, backwards: !grade && from > 1)
        }
    }

    private var movedUpCount: Int { movements.filter { !$0.backwards && $0.to > $0.from }.count }
    private var movedBackCount: Int { movements.filter { $0.backwards }.count }

    private var sourceId: String {
        book.id.uuidString
    }

    private func cardTypeLabel(_ type: String) -> String {
        switch type {
        case "definition": return "Definition"
        case "explanation": return "Explanation"
        case "fill_blank": return "Fill in the blank"
        case "why": return "Why / How"
        case "process": return "Process"
        default: return type.capitalized
        }
    }

    private func difficultyColor(_ difficulty: String) -> Color {
        switch difficulty {
        case "easy": return Color(hex: "276B32")
        case "medium": return Color(hex: "C99526")
        case "hard": return Color(hex: "B0444C")
        default: return Color(hex: "8D958E")
        }
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
                let result = try await memorizeService.generateLeitnerDeck(
                    topic: topic,
                    sourceContext: sourceContext,
                    sourceId: sourceId
                )
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
            HStack(spacing: 6) {
                Text(cardTypeLabel(card.cardType))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(0.4)
                    .foregroundColor(theme.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(theme.primary.opacity(0.12))
                    .clipShape(Capsule())

                Text(card.difficulty.capitalized)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(0.4)
                    .foregroundColor(difficultyColor(card.difficulty))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(difficultyColor(card.difficulty).opacity(0.12))
                    .clipShape(Capsule())

                Spacer()

                Text("Box \(card.box)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(theme.muted)
            }

            HStack {
                Text(card.front)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(theme.title)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
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
    var onSessionComplete: (String, String) -> Void = { _, _ in }
    private let kind: TutorMiniAppKind = .mnemonics
    private let memorizeService = MemorizeService()

    @State private var step = 0
    @State private var hasSavedSession = false
    @State private var items: [String] = []
    @State private var orderMatters = false
    @State private var selectedType: MemorizeService.MnemonicType = .sentence
    @State private var mnemonic: MemorizeService.MnemonicResult?
    @State private var recallText = ""
    @State private var firstEvaluation: MemorizeService.MnemonicRecallEvaluation?
    @State private var refinedMnemonic: String?
    @State private var reinforceText = ""
    @State private var secondEvaluation: MemorizeService.MnemonicRecallEvaluation?

    @State private var isLoadingItems = false
    @State private var isLoadingMnemonic = false
    @State private var isEvaluating = false
    @State private var isRefining = false
    @State private var loadError: String?
    @State private var hintRevealed = false
    @FocusState private var focusedItemIndex: Int?

    private let stepTitles = [
        "Items to memorize",
        "Build the mnemonic",
        "Recall test",
        "Weak spots & refine",
        "Reinforce & wrap up"
    ]

    private var topic: String {
        tutorSourceItems(from: book, limit: 1).first?.title ?? "Your topic"
    }

    private var sourceContext: String {
        tutorFullSourceContext(from: book)
    }

    private var estimatedListHeight: CGFloat {
        // Each row has ~32pt of fixed chrome (number badge + buttons + padding) plus
        // a textfield that wraps. Approximate ~30 chars per line at this width.
        let perRow: [CGFloat] = items.map { text in
            let approxCharsPerLine: Double = 28
            let lineCount = max(1, Int(ceil(Double(max(text.count, 1)) / approxCharsPerLine)))
            return CGFloat(lineCount) * 22 + 38
        }
        let total = perRow.reduce(0, +) + CGFloat(max(items.count - 1, 0)) * 8
        return max(total, 64)
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
                    case 0: itemsStep(theme: theme)
                    case 1: buildStep(theme: theme)
                    case 2: recallStep(theme: theme)
                    case 3: refineStep(theme: theme)
                    default: wrapStep(theme: theme)
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
        .onAppear { loadItemsIfNeeded() }
    }

    private var footerTitle: String {
        switch step {
        case 0: return isLoadingItems ? "Reading…" : "Pick a type"
        case 1: return isLoadingMnemonic ? "Building…" : "Test recall"
        case 2: return isEvaluating ? "Checking…" : "See score"
        case 3: return isRefining ? "Refining…" : "Reinforce"
        default: return "Finish"
        }
    }

    private var footerDisabled: Bool {
        switch step {
        case 0: return isLoadingItems || items.isEmpty
        case 1: return isLoadingMnemonic || mnemonic == nil
        case 2: return isEvaluating || recallText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 3: return isRefining
        default: return false
        }
    }

    private func handlePrimary() {
        switch step {
        case 0:
            step = 1
        case 1:
            step = 2
        case 2:
            evaluateRecall()
        case 3:
            refineAndAdvance()
        default:
            onClose()
        }
    }

    private func loadItemsIfNeeded() {
        guard items.isEmpty, !isLoadingItems, !sourceContext.isEmpty else { return }
        isLoadingItems = true
        loadError = nil
        Task {
            do {
                let result = try await memorizeService.extractMnemonicItems(topic: topic, sourceContext: sourceContext)
                await MainActor.run {
                    items = Array(result.items.prefix(7))
                    orderMatters = result.orderMatters
                    isLoadingItems = false
                }
            } catch {
                await MainActor.run {
                    loadError = error.localizedDescription
                    isLoadingItems = false
                }
            }
        }
    }

    private func requestMnemonic() {
        guard mnemonic == nil, !isLoadingMnemonic, !items.isEmpty else { return }
        isLoadingMnemonic = true
        Task {
            do {
                let result = try await memorizeService.generateMnemonic(topic: topic, items: items, mnemonicType: selectedType)
                await MainActor.run {
                    mnemonic = MemorizeService.MnemonicResult(
                        items: items,
                        triggers: result.triggers,
                        mnemonicType: result.mnemonicType,
                        mnemonic: result.mnemonic,
                        orderMatters: orderMatters
                    )
                    isLoadingMnemonic = false
                }
            } catch {
                await MainActor.run {
                    loadError = error.localizedDescription
                    isLoadingMnemonic = false
                }
            }
        }
    }

    private func evaluateRecall() {
        let recall = recallText
            .split(whereSeparator: { $0 == "," || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !recall.isEmpty, !isEvaluating else { return }
        isEvaluating = true
        Task {
            do {
                let result = try await memorizeService.evaluateMnemonicRecall(
                    originalItems: items,
                    userRecall: recall,
                    orderMatters: orderMatters
                )
                await MainActor.run {
                    firstEvaluation = result
                    isEvaluating = false
                    step = 3
                }
            } catch {
                await MainActor.run {
                    loadError = error.localizedDescription
                    isEvaluating = false
                }
            }
        }
    }

    private func saveMnemonicsSession() {
        guard !hasSavedSession else { return }
        hasSavedSession = true
        var lines: [String] = [
            "Mnemonics session — \(topic)",
            "",
            "Type: \(selectedType.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)",
            ""
        ]
        if !items.isEmpty {
            lines.append("Items memorized:")
            items.forEach { lines.append("- \($0)") }
            lines.append("")
        }
        if let mnemonic, !mnemonic.mnemonic.isEmpty {
            lines.append("Mnemonic:")
            lines.append(mnemonic.mnemonic)
            lines.append("")
        }
        if let refined = refinedMnemonic, !refined.isEmpty, refined != mnemonic?.mnemonic {
            lines.append("Refined mnemonic:")
            lines.append(refined)
            lines.append("")
        }
        if let evaluation = firstEvaluation {
            lines.append("First recall score: \(evaluation.score)/100")
            if !evaluation.weakItems.isEmpty {
                lines.append("Weak items: \(evaluation.weakItems.joined(separator: ", "))")
            }
        }
        let rawData = lines.joined(separator: "\n")
        Task {
            let summary = (try? await memorizeService.summarizeTutorSession(
                sessionType: "Mnemonics",
                topic: topic,
                rawSessionData: rawData
            )) ?? ""
            let body = summary.isEmpty ? rawData : "\(summary)\n\n— — —\n\n\(rawData)"
            await MainActor.run {
                onSessionComplete(topic, body)
            }
        }
    }

    private func refineAndAdvance() {
        guard let firstEvaluation, !isRefining, let mnemonic else {
            step = 4
            saveMnemonicsSession()
            return
        }
        if firstEvaluation.weakItems.isEmpty {
            refinedMnemonic = mnemonic.mnemonic
            step = 4
            saveMnemonicsSession()
            return
        }
        isRefining = true
        Task {
            do {
                let updated = try await memorizeService.refineMnemonic(
                    topic: topic,
                    items: items,
                    mnemonicType: selectedType,
                    previousMnemonic: mnemonic.mnemonic,
                    weakItems: firstEvaluation.weakItems
                )
                await MainActor.run {
                    refinedMnemonic = updated
                    isRefining = false
                    step = 4
                    saveMnemonicsSession()
                }
            } catch {
                await MainActor.run {
                    loadError = error.localizedDescription
                    isRefining = false
                }
            }
        }
    }

    // MARK: Steps

    private func itemsStep(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            TutorBodyText(
                text: "Here are the key items to memorize. Tap an item to rename it, drag it up or down to reorder, or remove what you don't need.",
                theme: theme
            )

            if isLoadingItems {
                TutorThinkingCard(theme: theme, title: "Pulling items", subtitle: "Reading your sources…")
            } else if items.isEmpty {
                emptySourcesPlaceholder(theme: theme)
            } else {
                List {
                    ForEach(items.indices, id: \.self) { idx in
                        editableItemRow(index: idx, theme: theme)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                            .deleteDisabled(true)
                    }
                    .onMove { from, to in
                        items.move(fromOffsets: from, toOffset: to)
                        mnemonic = nil
                    }
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .scrollContentBackground(.hidden)
                .frame(height: estimatedListHeight)
                .environment(\.editMode, .constant(.active))

                Button {
                    items.append("")
                    mnemonic = nil
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Add item")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(theme.primary)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(theme.primary.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(items.count >= 7)
                .opacity(items.count >= 7 ? 0.4 : 1.0)

                if items.count >= 7 {
                    Text("7-item limit reached.")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(theme.muted)
                }
            }
            if let loadError {
                tutorErrorCard(theme: theme, message: loadError)
            }
        }
    }

    private func editableItemRow(index: Int, theme: TutorMiniAppTheme) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(theme.primary.opacity(0.15)).frame(width: 26, height: 26)
                Text("\(index + 1)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(theme.primary)
            }

            TextField(
                "Item",
                text: Binding(
                    get: { index < items.count ? items[index] : "" },
                    set: { newValue in
                        if index < items.count {
                            items[index] = newValue
                            mnemonic = nil
                        }
                    }
                ),
                axis: .vertical
            )
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundColor(theme.title)
            .tint(theme.primary)
            .lineLimit(1...4)
            .submitLabel(.done)
            .focused($focusedItemIndex, equals: index)

            Button {
                focusedItemIndex = index
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(theme.primary)
                    .frame(width: 26, height: 26)
                    .background(theme.primary.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 4)

            Button {
                guard index < items.count else { return }
                items.remove(at: index)
                mnemonic = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: "B0444C"))
                    .frame(width: 26, height: 26)
                    .background(Color(hex: "FCE3E3"))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))
    }

    private func buildStep(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                TutorSectionLabel(text: "MNEMONIC TYPE", theme: theme)
                TutorFlowLayout(spacing: 8, lineSpacing: 8) {
                    typeChip(.acronym, label: "Acronym", theme: theme)
                    typeChip(.sentence, label: "Sentence", theme: theme)
                    typeChip(.visualImagery, label: "Visual imagery", theme: theme)
                    typeChip(.storyChain, label: "Story chain", theme: theme)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))

            if isLoadingMnemonic {
                TutorThinkingCard(theme: theme, title: "Building your mnemonic", subtitle: "Hooking each item onto something vivid…")
            } else if let mnemonic {
                VStack(alignment: .leading, spacing: 10) {
                    TutorSectionLabel(text: "YOUR MNEMONIC", theme: theme)
                    Text(mnemonic.mnemonic)
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(theme.title)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                    if !mnemonic.triggers.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(mnemonic.triggers.enumerated()), id: \.offset) { _, trig in
                                HStack(spacing: 8) {
                                    Text(trig.trigger)
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(theme.primary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(theme.primary.opacity(0.12))
                                        .clipShape(Capsule())
                                    Text("→ \(trig.item)")
                                        .font(.system(size: 13, weight: .regular, design: .rounded))
                                        .foregroundColor(theme.body)
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))
            } else {
                Button {
                    requestMnemonic()
                } label: {
                    HStack {
                        Image(systemName: "wand.and.sparkles")
                        Text("Generate \(typeDisplay(selectedType))")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(theme.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(theme.primary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            if let loadError {
                tutorErrorCard(theme: theme, message: loadError)
            }
        }
    }

    private func typeChip(_ type: MemorizeService.MnemonicType, label: String, theme: TutorMiniAppTheme) -> some View {
        let isOn = selectedType == type
        return Button {
            if selectedType != type {
                selectedType = type
                mnemonic = nil
            }
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(isOn ? theme.primaryText : theme.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isOn ? theme.primary : theme.primary.opacity(0.12))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func typeDisplay(_ type: MemorizeService.MnemonicType) -> String {
        switch type {
        case .acronym: return "acronym"
        case .sentence: return "sentence"
        case .visualImagery: return "visual mnemonic"
        case .storyChain: return "story chain"
        }
    }

    private func recallStep(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            TutorBodyText(
                text: "Hide the list. Type the items you remember\(orderMatters ? " in order" : "") — separate by commas or new lines.",
                theme: theme
            )
            if let mnemonic {
                if hintRevealed {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            TutorSectionLabel(text: "MNEMONIC (REVEALED)", theme: theme)
                            Spacer()
                            Button {
                                hintRevealed = false
                            } label: {
                                Text("Hide")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(theme.primary)
                            }
                        }
                        Text(mnemonic.mnemonic)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(theme.body)
                            .lineSpacing(3)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(theme.primary.opacity(0.18), lineWidth: 1))
                } else {
                    Button {
                        hintRevealed = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Stuck? Peek at your mnemonic")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(theme.primary)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .background(theme.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(theme.primary.opacity(0.18), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                TutorSectionLabel(text: "FROM MEMORY", theme: theme)
                ZStack(alignment: .topLeading) {
                    if recallText.isEmpty {
                        Text("Mercury, Venus, Earth, …")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(theme.muted)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                    }
                    TextEditor(text: $recallText)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(Color(hex: "1F2420"))
                        .tint(theme.primary)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(minHeight: 140)
                }
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))
            }
            if isEvaluating {
                TutorThinkingCard(theme: theme, title: "Checking your recall", subtitle: "Comparing against the original list…")
            }
            if let loadError {
                tutorErrorCard(theme: theme, message: loadError)
            }
        }
    }

    private func refineStep(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let evaluation = firstEvaluation {
                HStack(spacing: 10) {
                    TutorMetric(value: "\(evaluation.score)", label: "SCORE", theme: theme)
                    TutorMetric(value: "\(evaluation.correctItems.count)", label: "RIGHT", theme: theme)
                    TutorMetric(value: "\(evaluation.missedItems.count)", label: "MISSED", theme: theme)
                }

                if !evaluation.weakItems.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        TutorSectionLabel(text: "WEAK SPOTS", theme: theme)
                        FlowChips(items: evaluation.weakItems, theme: theme)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))
                }

                if !evaluation.outOfOrderItems.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        TutorSectionLabel(text: "OUT OF ORDER", theme: theme)
                        FlowChips(items: evaluation.outOfOrderItems, theme: theme)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))
                }

                if !evaluation.comment.isEmpty {
                    Text(evaluation.comment)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(theme.body)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }

            if isRefining {
                TutorThinkingCard(theme: theme, title: "Refining your mnemonic", subtitle: "Making the weak spots more vivid…")
            }
            if let loadError {
                tutorErrorCard(theme: theme, message: loadError)
            }
        }
    }

    private func wrapStep(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            TutorSuccessCard(
                title: "Lesson complete.",
                subtitle: "Your refined mnemonic for \(topic) is locked in. We'll bring it back tomorrow.",
                theme: theme
            )
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.primary)
                Text("Progress saved · 5 steps done")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(theme.title)
                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.primary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(theme.primary.opacity(0.22), lineWidth: 1))

            if let refinedMnemonic, !refinedMnemonic.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    TutorSectionLabel(text: "REFINED MNEMONIC", theme: theme)
                    Text(refinedMnemonic)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(theme.title)
                        .lineSpacing(4)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))
            }

            HStack(spacing: 10) {
                TutorMetric(value: "\(items.count)", label: "ITEMS", theme: theme)
                TutorMetric(value: "\(firstEvaluation?.score ?? 0)", label: "1ST SCORE", theme: theme)
                TutorMetric(value: "\(firstEvaluation?.weakItems.count ?? 0)", label: "WEAK", theme: theme)
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
    private let masteryThreshold: Double = 0.75

    @State private var step = 0
    @State private var prompts: [MemorizeService.RecallPrompt] = []
    @State private var attempts: [MemorizeService.RecallAttempt] = []
    @State private var queue: [MemorizeService.RecallPrompt] = []
    @State private var queueIndex = 0
    @State private var inRetryPhase = false

    @State private var userAnswer = ""
    @State private var confidence: String?
    @State private var currentAttempt: MemorizeService.RecallAttempt?

    @State private var isLoadingPrompts = false
    @State private var isEvaluating = false
    @State private var loadError: String?

    private let stepTitles = ["Learning target", "Recall round", "Mastery summary"]

    private var topic: String {
        tutorSourceItems(from: book, limit: 1).first?.title ?? "Your topic"
    }

    private var sourceItem: TutorSourceItem? {
        tutorSourceItems(from: book, limit: 1).first
    }

    private var contentChunk: String {
        tutorFullSourceContext(from: book)
    }

    private var sourceId: String { book.id.uuidString }

    private var currentPrompt: MemorizeService.RecallPrompt? {
        guard queueIndex < queue.count else { return nil }
        return queue[queueIndex]
    }

    private var totalQueueLength: Int { queue.count }

    private var masteryScore: Int {
        guard !prompts.isEmpty else { return 0 }
        var lastByPrompt: [String: Int] = [:]
        for a in attempts { lastByPrompt[a.promptId] = a.score }
        let total = prompts.map { lastByPrompt[$0.id] ?? 0 }.reduce(0, +)
        return total / prompts.count
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
                    case 0: targetStep(theme: theme)
                    case 1: recallStep(theme: theme)
                    default: summaryStep(theme: theme)
                    }
                }
            }

            TutorMiniAppFooter(
                theme: theme,
                showBack: step > 0 && currentAttempt == nil,
                primaryTitle: footerTitle,
                primaryIcon: step == stepTitles.count - 1 ? "checkmark" : "chevron.right",
                primaryDisabled: footerDisabled,
                onBack: handleBack,
                onPrimary: handlePrimary
            )
        }
        .onAppear { loadPromptsIfNeeded() }
    }

    private var footerTitle: String {
        switch step {
        case 0: return isLoadingPrompts ? "Reading…" : "Begin retrieval"
        case 1:
            if let attempt = currentAttempt {
                if attempt.score < Int(masteryThreshold * 100) {
                    return "Try again"
                }
                return queueIndex < queue.count - 1 ? "Next prompt" : (hasMoreWeakWork ? "Retry weak prompts" : "Finish round")
            }
            return isEvaluating ? "Grading…" : "Submit answer"
        default: return "Finish"
        }
    }

    private var footerDisabled: Bool {
        switch step {
        case 0: return isLoadingPrompts || prompts.isEmpty
        case 1:
            if currentAttempt != nil { return false }
            return isEvaluating
                || userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || confidence == nil
        default: return false
        }
    }

    private var hasMoreWeakWork: Bool {
        guard !inRetryPhase else { return false }
        let weak = memorizeService.identifyWeakPrompts(attempts: attempts, masteryThreshold: masteryThreshold)
        return !weak.isEmpty
    }

    private func handlePrimary() {
        switch step {
        case 0:
            step = 1
        case 1:
            if let attempt = currentAttempt {
                advanceAfterFeedback(lastAttempt: attempt)
            } else {
                submitAnswer()
            }
        default:
            onClose()
        }
    }

    private func handleBack() {
        guard step > 0 else { return }
        if currentAttempt != nil { return }
        step -= 1
    }

    private func loadPromptsIfNeeded() {
        guard prompts.isEmpty, !isLoadingPrompts, !contentChunk.isEmpty else { return }
        isLoadingPrompts = true
        loadError = nil
        Task {
            do {
                let result = try await memorizeService.generateRecallPrompts(
                    sourceId: sourceId,
                    contentChunk: contentChunk
                )
                await MainActor.run {
                    prompts = result
                    queue = result
                    queueIndex = 0
                    isLoadingPrompts = false
                }
            } catch {
                await MainActor.run {
                    loadError = error.localizedDescription
                    isLoadingPrompts = false
                }
            }
        }
    }

    private func submitAnswer() {
        guard let prompt = currentPrompt, let confidenceValue = confidence, !isEvaluating else { return }
        let trimmed = userAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let isRetry = inRetryPhase || attempts.contains { $0.promptId == prompt.id }
        isEvaluating = true
        Task {
            do {
                let attempt = try await memorizeService.evaluateRecallAnswer(
                    prompt: prompt,
                    userAnswer: trimmed,
                    confidence: confidenceValue,
                    isRetry: isRetry
                )
                await MainActor.run {
                    attempts.append(attempt)
                    currentAttempt = attempt
                    isEvaluating = false
                }
            } catch {
                await MainActor.run {
                    loadError = error.localizedDescription
                    isEvaluating = false
                }
            }
        }
    }

    private func advanceAfterFeedback(lastAttempt: MemorizeService.RecallAttempt) {
        let needsRetry = lastAttempt.score < Int(masteryThreshold * 100)
        let isLastInQueue = queueIndex >= queue.count - 1

        if needsRetry {
            // Retry same prompt (immediate)
            currentAttempt = nil
            userAnswer = ""
            confidence = nil
            return
        }

        if isLastInQueue {
            if !inRetryPhase {
                let weakIDs = memorizeService.identifyWeakPrompts(attempts: attempts, masteryThreshold: masteryThreshold)
                let weakPrompts = prompts.filter { weakIDs.contains($0.id) }
                if !weakPrompts.isEmpty {
                    queue = weakPrompts
                    queueIndex = 0
                    inRetryPhase = true
                    currentAttempt = nil
                    userAnswer = ""
                    confidence = nil
                    return
                }
            }
            // No more work — go to summary
            step = 2
            return
        }

        queueIndex += 1
        currentAttempt = nil
        userAnswer = ""
        confidence = nil
    }

    // MARK: Steps

    private func targetStep(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                TutorSectionLabel(text: "LEARNING TARGET", theme: theme)
                Text(sourceItem?.title ?? topic)
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .foregroundColor(theme.title)
                if let excerpt = sourceItem?.excerpt, !excerpt.isEmpty {
                    Text(excerpt)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(theme.body)
                        .lineSpacing(3)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))

            if isLoadingPrompts {
                TutorThinkingCard(theme: theme, title: "Building recall prompts", subtitle: "Pulling 3–5 retrieval questions from this chunk…")
            } else if !prompts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    TutorSectionLabel(text: "RECALL ROUND · \(prompts.count) PROMPTS", theme: theme)
                    ForEach(prompts, id: \.id) { p in
                        HStack(spacing: 10) {
                            promptTypeChip(p.promptType, theme: theme)
                            Text(p.difficulty.capitalized)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(0.4)
                                .foregroundColor(difficultyColor(p.difficulty))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(difficultyColor(p.difficulty).opacity(0.12))
                                .clipShape(Capsule())
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }

            if tutorSourceItems(from: book, limit: 1).isEmpty && !isLoadingPrompts {
                emptySourcesPlaceholder(theme: theme)
            }
            if let loadError {
                tutorErrorCard(theme: theme, message: loadError)
            }
        }
    }

    private func recallStep(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(inRetryPhase ? "RETRY · WEAK PROMPT \(queueIndex + 1)/\(totalQueueLength)" : "PROMPT \(queueIndex + 1)/\(totalQueueLength)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.6)
                    .foregroundColor(theme.muted)
                Spacer()
                if let p = currentPrompt {
                    promptTypeChip(p.promptType, theme: theme)
                }
            }

            if let prompt = currentPrompt {
                Text(prompt.prompt)
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .foregroundColor(theme.title)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))

                if let attempt = currentAttempt {
                    feedbackCard(attempt: attempt, prompt: prompt, theme: theme)
                } else {
                    answerCard(theme: theme)
                    confidencePicker(theme: theme)
                    if isEvaluating {
                        TutorThinkingCard(theme: theme, title: "Grading your answer", subtitle: "Comparing against the key points…")
                    }
                }
            } else {
                tutorLoadingCard(theme: theme)
            }

            if let loadError {
                tutorErrorCard(theme: theme, message: loadError)
            }
        }
    }

    private func answerCard(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TutorSectionLabel(text: "FROM MEMORY", theme: theme)
            ZStack(alignment: .topLeading) {
                if userAnswer.isEmpty {
                    Text("Type your answer…")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(theme.muted)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                }
                TextEditor(text: $userAnswer)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(Color(hex: "1F2420"))
                    .tint(theme.primary)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(minHeight: 130)
            }
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))
        }
    }

    private func confidencePicker(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TutorSectionLabel(text: "CONFIDENCE", theme: theme)
            HStack(spacing: 8) {
                confidenceChip("low", label: "Low", theme: theme)
                confidenceChip("medium", label: "Medium", theme: theme)
                confidenceChip("high", label: "High", theme: theme)
            }
        }
    }

    private func confidenceChip(_ value: String, label: String, theme: TutorMiniAppTheme) -> some View {
        let isOn = confidence == value
        return Button { confidence = value } label: {
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(isOn ? theme.primaryText : theme.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isOn ? theme.primary : theme.primary.opacity(0.12))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func feedbackCard(attempt: MemorizeService.RecallAttempt, prompt: MemorizeService.RecallPrompt, theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                TutorMetric(value: "\(attempt.score)", label: "SCORE", theme: theme)
                TutorMetric(value: "\(attempt.correctPoints.count)", label: "RIGHT", theme: theme)
                TutorMetric(value: "\(attempt.missingPoints.count)", label: "MISSING", theme: theme)
            }

            if attempt.falseConfidence {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "C99526"))
                    Text("False confidence — you rated this high but missed key points.")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(theme.body)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "FFF1D6"))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if !attempt.feedback.isEmpty {
                Text(attempt.feedback)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(theme.body)
                    .lineSpacing(3)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if !attempt.missingPoints.isEmpty {
                pointList(title: "MISSING", points: attempt.missingPoints, color: Color(hex: "B0444C"), theme: theme)
            }
            if !attempt.incorrectPoints.isEmpty {
                pointList(title: "INCORRECT", points: attempt.incorrectPoints, color: Color(hex: "C99526"), theme: theme)
            }
            if !attempt.correctPoints.isEmpty {
                pointList(title: "GOT IT", points: attempt.correctPoints, color: theme.primary, theme: theme)
            }
        }
    }

    private func pointList(title: String, points: [String], color: Color, theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.5)
                .foregroundColor(color)
            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(color).frame(width: 5, height: 5).padding(.top, 7)
                    Text(point)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(theme.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))
    }

    private func summaryStep(theme: TutorMiniAppTheme) -> some View {
        let score = masteryScore
        return VStack(alignment: .leading, spacing: 14) {
            TutorSuccessCard(
                title: score >= Int(masteryThreshold * 100) ? "Mastery hit." : "Solid round.",
                subtitle: "Mastery score: \(score)/100. \(prompts.count) prompts, \(attempts.count) attempts.",
                theme: theme
            )
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.primary)
                Text("Lesson complete · session saved")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(theme.title)
                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.primary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(theme.primary.opacity(0.22), lineWidth: 1))

            HStack(spacing: 10) {
                TutorMetric(value: "\(score)", label: "MASTERY", theme: theme)
                TutorMetric(value: "\(attempts.filter { !$0.isRetry }.count)", label: "FIRST TRY", theme: theme)
                TutorMetric(value: "\(attempts.filter { $0.isRetry }.count)", label: "RETRIES", theme: theme)
            }

            let falseConfidenceAttempts = attempts.filter { $0.falseConfidence }
            if !falseConfidenceAttempts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    TutorSectionLabel(text: "FALSE CONFIDENCE", theme: theme)
                    ForEach(falseConfidenceAttempts, id: \.id) { a in
                        if let p = prompts.first(where: { $0.id == a.promptId }) {
                            Text("• \(p.prompt)")
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(theme.body)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "FFF1D6"))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                TutorSectionLabel(text: "PROMPT BY PROMPT", theme: theme)
                ForEach(prompts, id: \.id) { p in
                    let last = attempts.last(where: { $0.promptId == p.id })
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill((last?.score ?? 0) >= Int(masteryThreshold * 100) ? theme.primary.opacity(0.15) : Color(hex: "B0444C").opacity(0.18))
                                .frame(width: 22, height: 22)
                            Image(systemName: (last?.score ?? 0) >= Int(masteryThreshold * 100) ? "checkmark" : "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor((last?.score ?? 0) >= Int(masteryThreshold * 100) ? theme.primary : Color(hex: "B0444C"))
                        }
                        Text(p.prompt)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(theme.title)
                            .lineLimit(2)
                        Spacer()
                        Text("\(last?.score ?? 0)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(theme.muted)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    private func promptTypeChip(_ type: String, theme: TutorMiniAppTheme) -> some View {
        Text(promptTypeLabel(type))
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(0.4)
            .foregroundColor(theme.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(theme.primary.opacity(0.12))
            .clipShape(Capsule())
    }

    private func promptTypeLabel(_ type: String) -> String {
        switch type {
        case "definition": return "Definition"
        case "why_how": return "Why / How"
        case "steps_process": return "Process"
        case "compare_contrast": return "Compare"
        case "application_example": return "Apply"
        default: return type.capitalized
        }
    }

    private func difficultyColor(_ difficulty: String) -> Color {
        switch difficulty {
        case "easy": return Color(hex: "276B32")
        case "medium": return Color(hex: "C99526")
        case "hard": return Color(hex: "B0444C")
        default: return Color(hex: "8D958E")
        }
    }
}

// MARK: - Cornell Method (3 steps)

private struct CornellMiniApp: View {
    let book: Book
    let onClose: () -> Void
    var onSessionComplete: (String, String) -> Void = { _, _ in }
    private let kind: TutorMiniAppKind = .cornell
    private let memorizeService = MemorizeService()
    @State private var step = 0
    @State private var hasSavedSession = false
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
        tutorFullSourceContext(from: book)
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
            saveCornellSession()
            onClose()
        }
    }

    private func saveCornellSession() {
        guard !hasSavedSession else { return }
        hasSavedSession = true
        var lines: [String] = [
            "Cornell Method session — \(topic)",
            ""
        ]
        if let rows = cornellSet?.rows, !rows.isEmpty {
            lines.append("Cues & body:")
            for row in rows {
                lines.append("- \(row.cue): \(row.body)")
            }
            lines.append("")
        }
        let trimmedSummary = summaryText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSummary.isEmpty {
            lines.append("Your summary:")
            lines.append(trimmedSummary)
        }
        let rawData = lines.joined(separator: "\n")
        Task {
            let summary = (try? await memorizeService.summarizeTutorSession(
                sessionType: "Cornell Method",
                topic: topic,
                rawSessionData: rawData
            )) ?? ""
            let body = summary.isEmpty ? rawData : "\(summary)\n\n— — —\n\n\(rawData)"
            await MainActor.run {
                onSessionComplete(topic, body)
            }
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
                text: "Your sources are split into cues and body — Cornell style. Read through once, then on the next step we cover the body and you answer the cues.",
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
                ZStack(alignment: .topLeading) {
                    if summaryText.isEmpty {
                        Text("Start writing here…")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(theme.muted)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                    }
                    TextEditor(text: $summaryText)
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
        tutorFullSourceContext(from: book)
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
                subtitle: "Your intervals were rebalanced based on how this round went.",
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

// MARK: - Find the Mistake (3 steps)

private struct FindMistakeMiniApp: View {
    let book: Book
    let onClose: () -> Void
    var onSessionComplete: (String, String) -> Void = { _, _ in }
    private let kind: TutorMiniAppKind = .findMistake
    private let memorizeService = MemorizeService()
    private let masteryThreshold: Double = 0.75

    @State private var step = 0
    @State private var hasSavedSession = false
    @State private var items: [MemorizeService.FixMistakeItem] = []
    @State private var attempts: [MemorizeService.FixAttempt] = []
    @State private var queue: [MemorizeService.FixMistakeItem] = []
    @State private var queueIndex = 0
    @State private var inRetryPhase = false

    @State private var selectedOptionIndex: Int?
    @State private var currentAttempt: MemorizeService.FixAttempt?

    @State private var isLoadingItems = false
    @State private var loadError: String?

    private let stepTitles = ["Source", "Spot the mistake", "Mastery summary"]

    private var topic: String {
        tutorSourceItems(from: book, limit: 1).first?.title ?? "Your topic"
    }

    private var sourceItem: TutorSourceItem? {
        tutorSourceItems(from: book, limit: 1).first
    }

    private var sourceText: String {
        tutorFullSourceContext(from: book)
    }

    private var sourceId: String { book.id.uuidString }

    private var currentItem: MemorizeService.FixMistakeItem? {
        guard queueIndex < queue.count else { return nil }
        return queue[queueIndex]
    }

    private var totalQueueLength: Int { queue.count }

    private var masteryScore: Int {
        guard !items.isEmpty else { return 0 }
        var lastByItem: [String: Int] = [:]
        for a in attempts { lastByItem[a.itemId] = a.score }
        let total = items.map { lastByItem[$0.id] ?? 0 }.reduce(0, +)
        return total / items.count
    }

    var body: some View {
        let theme = kind.theme
        VStack(spacing: 0) {
            TutorMiniAppShell(
                kind: kind,
                stepTitle: stepTitles[step],
                stepIndex: step,
                stepCount: stepTitles.count,
                counterOverride: shellCounterOverride,
                onClose: onClose
            ) {
                Group {
                    switch step {
                    case 0: targetStep(theme: theme)
                    case 1: spotStep(theme: theme)
                    default: summaryStep(theme: theme)
                    }
                }
            }

            TutorMiniAppFooter(
                theme: theme,
                showBack: step > 0 && currentAttempt == nil,
                primaryTitle: footerTitle,
                primaryIcon: step == stepTitles.count - 1 ? "checkmark" : "chevron.right",
                primaryDisabled: footerDisabled,
                onBack: { if step > 0 && currentAttempt == nil { step -= 1 } },
                onPrimary: handlePrimary
            )
        }
        .onAppear { loadItemsIfNeeded() }
    }

    private var shellCounterOverride: String? {
        guard step == 1, totalQueueLength > 0 else { return nil }
        return "\(min(queueIndex + 1, totalQueueLength)) / \(totalQueueLength)"
    }

    private var footerTitle: String {
        switch step {
        case 0: return isLoadingItems ? "Reading…" : "Begin"
        case 1:
            if let attempt = currentAttempt {
                if !attempt.isCorrect { return "Try again" }
                return queueIndex < queue.count - 1 ? "Next item" : (hasMoreWeakWork ? "Retry weak items" : "Finish round")
            }
            return "Submit"
        default: return "Finish"
        }
    }

    private var footerDisabled: Bool {
        switch step {
        case 0: return isLoadingItems || items.isEmpty
        case 1:
            if currentAttempt != nil { return false }
            return selectedOptionIndex == nil
        default: return false
        }
    }

    private var hasMoreWeakWork: Bool {
        guard !inRetryPhase else { return false }
        let weak = memorizeService.identifyWeakFixItems(attempts: attempts, masteryThreshold: masteryThreshold)
        return !weak.isEmpty
    }

    private func handlePrimary() {
        switch step {
        case 0:
            step = 1
        case 1:
            if let attempt = currentAttempt {
                advanceAfterFeedback(lastAttempt: attempt)
            } else {
                submitCorrection()
            }
        default:
            onClose()
        }
    }

    private func loadItemsIfNeeded() {
        guard items.isEmpty, !isLoadingItems, !sourceText.isEmpty else { return }
        isLoadingItems = true
        loadError = nil
        Task {
            do {
                let result = try await memorizeService.generateFixMistakeItems(
                    sourceId: sourceId,
                    sourceText: sourceText
                )
                await MainActor.run {
                    items = result
                    queue = result
                    queueIndex = 0
                    isLoadingItems = false
                }
            } catch {
                await MainActor.run {
                    loadError = error.localizedDescription
                    isLoadingItems = false
                }
            }
        }
    }

    private func submitCorrection() {
        guard let item = currentItem, let selected = selectedOptionIndex else { return }
        let isRetry = inRetryPhase || attempts.contains { $0.itemId == item.id }
        let attempt = memorizeService.evaluateCorrection(
            item: item,
            selectedOptionIndex: selected,
            isRetry: isRetry
        )
        attempts.append(attempt)
        currentAttempt = attempt
    }

    private func advanceAfterFeedback(lastAttempt: MemorizeService.FixAttempt) {
        let needsRetry = !lastAttempt.isCorrect
        let isLastInQueue = queueIndex >= queue.count - 1

        if needsRetry {
            currentAttempt = nil
            selectedOptionIndex = nil
            return
        }

        if isLastInQueue {
            if !inRetryPhase {
                let weakIDs = memorizeService.identifyWeakFixItems(attempts: attempts, masteryThreshold: masteryThreshold)
                let weakItems = items.filter { weakIDs.contains($0.id) }
                if !weakItems.isEmpty {
                    queue = weakItems
                    queueIndex = 0
                    inRetryPhase = true
                    currentAttempt = nil
                    selectedOptionIndex = nil
                    return
                }
            }
            step = 2
            saveFindMistakeSession()
            return
        }

        queueIndex += 1
        currentAttempt = nil
        selectedOptionIndex = nil
    }

    private func saveFindMistakeSession() {
        guard !hasSavedSession else { return }
        hasSavedSession = true
        var lines: [String] = [
            "Find the Mistake session — \(topic)",
            "",
            "Mastery score: \(masteryScore)/100",
            "Items: \(items.count) · Attempts: \(attempts.count)",
            ""
        ]
        let firstTry = attempts.filter { !$0.isRetry }
        let retries = attempts.filter { $0.isRetry }
        lines.append("First-try correct: \(firstTry.filter { $0.isCorrect }.count)/\(firstTry.count)")
        if !retries.isEmpty {
            lines.append("Retries: \(retries.count)")
        }
        lines.append("")
        let weak = memorizeService.identifyWeakFixItems(attempts: attempts, masteryThreshold: masteryThreshold)
        if !weak.isEmpty {
            lines.append("Items still worth revisiting:")
            for id in weak {
                if let item = items.first(where: { $0.id == id }) {
                    lines.append("- \(item.correctStatement)")
                }
            }
        }
        let rawData = lines.joined(separator: "\n")
        Task {
            let summary = (try? await memorizeService.summarizeTutorSession(
                sessionType: "Find the Mistake",
                topic: topic,
                rawSessionData: rawData
            )) ?? ""
            let body = summary.isEmpty ? rawData : "\(summary)\n\n— — —\n\n\(rawData)"
            await MainActor.run {
                onSessionComplete(topic, body)
            }
        }
    }

    // MARK: Steps

    private func targetStep(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                TutorSectionLabel(text: "SOURCE", theme: theme)
                Text(sourceItem?.title ?? topic)
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .foregroundColor(theme.title)
                if let excerpt = sourceItem?.excerpt, !excerpt.isEmpty {
                    Text(excerpt)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(theme.body)
                        .lineSpacing(3)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))

            TutorBodyText(
                text: "We'll show you statements that contain ONE plausible mistake. Read each one and pick the option that fixes it correctly.",
                theme: theme
            )

            if isLoadingItems {
                TutorThinkingCard(theme: theme, title: "Building flawed statements", subtitle: "Pulling 3–5 items from your source…")
            } else if !items.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    TutorSectionLabel(text: "ROUND · \(items.count) ITEMS", theme: theme)
                    ForEach(items, id: \.id) { item in
                        HStack(spacing: 10) {
                            errorTypeChip(item.errorType, theme: theme)
                            Text(item.difficulty.capitalized)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(0.4)
                                .foregroundColor(difficultyColor(item.difficulty))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(difficultyColor(item.difficulty).opacity(0.12))
                                .clipShape(Capsule())
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }

            if tutorSourceItems(from: book, limit: 1).isEmpty && !isLoadingItems {
                emptySourcesPlaceholder(theme: theme)
            }
            if let loadError {
                tutorErrorCard(theme: theme, message: loadError)
            }
        }
    }

    private func spotStep(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(inRetryPhase ? "RETRY · WEAK ITEM \(queueIndex + 1)/\(totalQueueLength)" : "ITEM \(queueIndex + 1)/\(totalQueueLength)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.6)
                    .foregroundColor(theme.muted)
                Spacer()
                if let item = currentItem {
                    errorTypeChip(item.errorType, theme: theme)
                }
            }

            if let item = currentItem {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: "B0444C"))
                        Text("STATEMENT WITH A MISTAKE")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(0.6)
                            .foregroundColor(Color(hex: "B0444C"))
                    }
                    Text(item.incorrectStatement)
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .foregroundColor(theme.title)
                        .lineSpacing(4)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "FCE3E3"))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "B0444C").opacity(0.25), lineWidth: 1))

                optionsList(item: item, theme: theme)
                if let attempt = currentAttempt {
                    feedbackCard(attempt: attempt, item: item, theme: theme)
                }
            } else {
                tutorLoadingCard(theme: theme)
            }

            if let loadError {
                tutorErrorCard(theme: theme, message: loadError)
            }
        }
    }

    private func optionsList(item: MemorizeService.FixMistakeItem, theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TutorSectionLabel(text: "PICK THE CORRECT VERSION", theme: theme)
            ForEach(Array(item.options.enumerated()), id: \.offset) { idx, optionText in
                optionRow(index: idx, item: item, text: optionText, theme: theme)
            }
        }
    }

    private func optionRow(index: Int, item: MemorizeService.FixMistakeItem, text: String, theme: TutorMiniAppTheme) -> some View {
        let isAnswered = currentAttempt != nil
        let isSelected = selectedOptionIndex == index
        let isCorrectAnswer = index == item.correctOptionIndex
        let userPickedThis = currentAttempt?.selectedOptionIndex == index

        let backgroundColor: Color = {
            if !isAnswered { return isSelected ? theme.primary.opacity(0.12) : theme.surface }
            if isCorrectAnswer { return Color(hex: "D6F4D8") }
            if userPickedThis { return Color(hex: "FCE3E3") }
            return theme.surface
        }()

        let borderColor: Color = {
            if !isAnswered { return isSelected ? theme.primary.opacity(0.55) : Color(hex: "EAE4DC") }
            if isCorrectAnswer { return Color(hex: "276B32").opacity(0.55) }
            if userPickedThis { return Color(hex: "B0444C").opacity(0.55) }
            return Color(hex: "EAE4DC")
        }()

        let letter = ["A", "B", "C", "D"][min(index, 3)]

        return Button {
            guard !isAnswered else { return }
            selectedOptionIndex = index
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Text(letter)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected || isAnswered && (isCorrectAnswer || userPickedThis) ? .white : theme.muted)
                    .frame(width: 26, height: 26)
                    .background(
                        Circle().fill({
                            if isAnswered, isCorrectAnswer { return Color(hex: "276B32") }
                            if isAnswered, userPickedThis { return Color(hex: "B0444C") }
                            if isSelected { return theme.primary }
                            return Color(hex: "F4EFE6")
                        }())
                    )

                Text(text)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(theme.title)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isAnswered, isCorrectAnswer {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "276B32"))
                } else if isAnswered, userPickedThis {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(hex: "B0444C"))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(borderColor, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .disabled(isAnswered)
    }

    private func feedbackCard(attempt: MemorizeService.FixAttempt, item: MemorizeService.FixMistakeItem, theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: attempt.isCorrect ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(attempt.isCorrect ? Color(hex: "276B32") : Color(hex: "B0444C"))
                Text(attempt.isCorrect ? "Correct." : "Not quite.")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(attempt.isCorrect ? Color(hex: "276B32") : Color(hex: "B0444C"))
                Spacer()
            }

            if !attempt.feedback.isEmpty {
                Text(attempt.feedback)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(theme.body)
                    .lineSpacing(3)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private func summaryStep(theme: TutorMiniAppTheme) -> some View {
        let score = masteryScore
        return VStack(alignment: .leading, spacing: 14) {
            TutorSuccessCard(
                title: score >= Int(masteryThreshold * 100) ? "Mistakes squared away." : "Round complete.",
                subtitle: "Mastery score: \(score)/100. \(items.count) items, \(attempts.count) attempts.",
                theme: theme
            )
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.primary)
                Text("Lesson complete · session saved")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(theme.title)
                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.primary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(theme.primary.opacity(0.22), lineWidth: 1))

            HStack(spacing: 10) {
                TutorMetric(value: "\(score)", label: "MASTERY", theme: theme)
                TutorMetric(value: "\(attempts.filter { !$0.isRetry }.count)", label: "FIRST TRY", theme: theme)
                TutorMetric(value: "\(attempts.filter { $0.isRetry }.count)", label: "RETRIES", theme: theme)
            }

            VStack(alignment: .leading, spacing: 8) {
                TutorSectionLabel(text: "ITEM BY ITEM", theme: theme)
                ForEach(items, id: \.id) { item in
                    let last = attempts.last(where: { $0.itemId == item.id })
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill((last?.score ?? 0) >= Int(masteryThreshold * 100) ? theme.primary.opacity(0.15) : Color(hex: "B0444C").opacity(0.18))
                                .frame(width: 22, height: 22)
                            Image(systemName: (last?.score ?? 0) >= Int(masteryThreshold * 100) ? "checkmark" : "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor((last?.score ?? 0) >= Int(masteryThreshold * 100) ? theme.primary : Color(hex: "B0444C"))
                        }
                        Text(item.incorrectStatement)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(theme.title)
                            .lineLimit(2)
                        Spacer()
                        Text("\(last?.score ?? 0)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(theme.muted)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    private func errorTypeChip(_ type: String, theme: TutorMiniAppTheme) -> some View {
        Text(errorTypeLabel(type))
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(0.4)
            .foregroundColor(theme.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(theme.primary.opacity(0.12))
            .clipShape(Capsule())
    }

    private func errorTypeLabel(_ type: String) -> String {
        switch type {
        case "wrong_fact": return "Wrong fact"
        case "missing_component": return "Missing piece"
        case "reversed_logic": return "Reversed logic"
        case "misdefinition": return "Bad definition"
        case "sequence_error": return "Sequence error"
        default: return type.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func difficultyColor(_ difficulty: String) -> Color {
        switch difficulty {
        case "easy": return Color(hex: "276B32")
        case "medium": return Color(hex: "C99526")
        case "hard": return Color(hex: "B0444C")
        default: return Color(hex: "8D958E")
        }
    }
}
