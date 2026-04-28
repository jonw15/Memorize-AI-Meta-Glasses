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
            ZStack {
                theme.surface
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
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

                    VStack(alignment: .leading, spacing: 6) {
                        Text(kind.eyebrow)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(0.6)
                            .foregroundColor(theme.eyebrow)

                        Text(stepTitle)
                            .font(.system(size: 26, weight: .regular, design: .serif))
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
                .padding(.top, 18)
                .padding(.bottom, 22)
            }
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
                    .padding(.top, 22)
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
            }
            .buttonStyle(.plain)
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

// MARK: - Feynman (5 steps)

private struct FeynmanMiniApp: View {
    let book: Book
    let onClose: () -> Void
    private let kind: TutorMiniAppKind = .feynman
    @State private var step = 0
    @State private var selectedConcept: String?
    @State private var teachText = ""

    private var concepts: [TutorSourceItem] {
        let items = tutorSourceItems(from: book, limit: 6)
        if items.isEmpty {
            return [
                TutorSourceItem(title: "Add a source to get started", excerpt: "")
            ]
        }
        return items
    }

    private let stepTitles = [
        "Pick a concept",
        "Teach it in plain words",
        "Where it landed",
        "Refine your explanation",
        "Wrap up"
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
                    case 0: pickConcept(theme: theme)
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
                onBack: { if step > 0 { step -= 1 } },
                onPrimary: {
                    if step < stepTitles.count - 1 { step += 1 } else { onClose() }
                }
            )
        }
    }

    private var primaryTitle: String {
        switch step {
        case 0: return "Start teaching"
        case 1: return "Get feedback"
        case 2: return "Refine"
        case 3: return "Lock it in"
        default: return "Finish"
        }
    }

    private func pickConcept(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            TutorBodyText(
                text: "Pick one concept to teach. Smaller and sharper is better — Feynman said, \"if you can't explain it simply, you don't understand it.\"",
                theme: theme
            )
            VStack(spacing: 10) {
                ForEach(concepts, id: \.title) { concept in
                    Button {
                        selectedConcept = concept.title
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: selectedConcept == concept.title ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(selectedConcept == concept.title ? theme.primary : theme.muted.opacity(0.4))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(concept.title)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(theme.title)
                                Text(concept.excerpt.isEmpty ? "From your sources" : concept.excerpt)
                                    .font(.system(size: 11, weight: .regular, design: .rounded))
                                    .foregroundColor(theme.muted)
                                    .lineLimit(2)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(selectedConcept == concept.title ? theme.primary.opacity(0.6) : Color(hex: "EAE4DC"), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func teachIt(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                TutorSectionLabel(text: "TEACHING", theme: theme)
                Text(selectedConcept ?? "Your concept")
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
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(minHeight: 140)
                }
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))
            }

            HStack {
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Speak instead")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .foregroundColor(theme.title)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(theme.surface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color(hex: "EAE4DC"), lineWidth: 1))
                Spacer()
            }
        }
    }

    private func whereItLanded(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            TutorBodyText(
                text: "Mastery read your explanation back against the source. Here's what landed and what to revisit:",
                theme: theme
            )
            ForEach(landingItems, id: \.title) { item in
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
        }
    }

    private func refine(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                TutorSectionLabel(text: "TRY AGAIN — FOCUS ON:", theme: theme)
                FlowChips(
                    items: [
                        "What's the mechanism?",
                        "Which key term is missing?",
                        "How does it cause the next step?"
                    ],
                    theme: theme
                )
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))

            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    if teachText.isEmpty {
                        Text("Refine your explanation here…")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(theme.muted)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                    }
                    TextEditor(text: $teachText)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(minHeight: 140)
                }
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))
            }

            Text("Much sharper. The mechanism reads cleanly now and the missing term is in.")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(theme.body)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func wrapUp(theme: TutorMiniAppTheme) -> some View {
        VStack(spacing: 14) {
            TutorSuccessCard(
                title: "You taught it.",
                subtitle: "\(selectedConcept ?? "Your concept") is now in your active recall set. We'll surface it again in 2 days.",
                theme: theme
            )
            HStack(spacing: 10) {
                TutorMetric(value: "8.6", label: "CLARITY", theme: theme)
                TutorMetric(value: "2", label: "GAPS CLOSED", theme: theme)
                TutorMetric(value: "+1", label: "MASTERY", theme: theme)
            }
        }
    }

    private struct LandingItem {
        let title: String
        let detail: String
    }

    private var landingItems: [LandingItem] {
        let topic = selectedConcept ?? "your topic"
        return [
            LandingItem(title: "You set the scene", detail: "You opened with the right framing for \(topic) — good starting point."),
            LandingItem(title: "Causality came through", detail: "You linked the steps in order, so a beginner could follow."),
            LandingItem(title: "One mechanism is fuzzy", detail: "There's a step in \(topic) where the explanation skipped past the \"how\" — that's the part to sharpen."),
            LandingItem(title: "A key term went unmentioned", detail: "One core term from your source didn't surface. Pull it in on the next pass.")
        ]
    }
}

// MARK: - Leitner (3 steps)

private struct LeitnerMiniApp: View {
    let book: Book
    let onClose: () -> Void
    private let kind: TutorMiniAppKind = .leitner
    @State private var step = 0

    private let stepTitles = ["Today's boxes", "Review queue", "Box movement"]

    private struct Box {
        let number: Int
        let label: String
        let detail: String
        let count: Int
        let progress: CGFloat
    }

    private struct Movement {
        let card: String
        let from: Int
        let to: Int
        let backwards: Bool
    }

    private var sourceItems: [TutorSourceItem] {
        tutorSourceItems(from: book, limit: 12)
    }

    private var queue: [String] {
        sourceItems.map(\.title)
    }

    private var totalDue: Int {
        max(queue.count, 1)
    }

    private var boxes: [Box] {
        let n = queue.count
        let distribution: [Int]
        switch n {
        case 0: distribution = [0, 0, 0, 0, 0]
        case 1: distribution = [1, 0, 0, 0, 0]
        case 2: distribution = [1, 1, 0, 0, 0]
        case 3: distribution = [1, 1, 1, 0, 0]
        case 4: distribution = [2, 1, 1, 0, 0]
        case 5: distribution = [2, 1, 1, 1, 0]
        default:
            let base = n / 5
            let remainder = n % 5
            distribution = (0..<5).map { base + ($0 < remainder ? 1 : 0) }
        }
        return [
            Box(number: 1, label: "Daily", detail: "New & shaky", count: distribution[0], progress: 0.85),
            Box(number: 2, label: "Every 2d", detail: "Getting there", count: distribution[1], progress: 0.55),
            Box(number: 3, label: "Every 4d", detail: "Steady", count: distribution[2], progress: 0.7),
            Box(number: 4, label: "Weekly", detail: "Solid", count: distribution[3], progress: 0.4),
            Box(number: 5, label: "Monthly", detail: "Mastered", count: distribution[4], progress: 0.25)
        ]
    }

    private var movements: [Movement] {
        let cards = Array(queue.prefix(5))
        return cards.enumerated().map { i, card in
            let backwards = i == cards.count - 1 && cards.count > 2
            return Movement(
                card: card,
                from: backwards ? 3 : (i % 3) + 1,
                to: backwards ? 1 : (i % 3) + 2,
                backwards: backwards
            )
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
                primaryTitle: step == 0 ? "Start review" : (step == stepTitles.count - 1 ? "Finish" : "Next"),
                primaryIcon: step == stepTitles.count - 1 ? "checkmark" : "chevron.right",
                onBack: { if step > 0 { step -= 1 } },
                onPrimary: { if step < stepTitles.count - 1 { step += 1 } else { onClose() } }
            )
        }
    }

    private func todaysBoxes(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            TutorBodyText(
                text: "Cards live in five boxes. Get one right and it moves up a box (longer wait). Miss it and it falls back to box 1.",
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
                    Text("\(totalDue) cards")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundColor(theme.title)
                }
                Spacer()
            }
            .padding(16)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))

            VStack(alignment: .leading, spacing: 10) {
                TutorSectionLabel(text: "YOUR BOXES", theme: theme)
                ForEach(boxes, id: \.number) { box in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(theme.primary.opacity(0.12))
                                .frame(width: 28, height: 28)
                            Text("\(box.number)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(theme.primary)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(box.label)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(theme.title)
                                Text(box.detail)
                                    .font(.system(size: 12, weight: .regular, design: .rounded))
                                    .foregroundColor(theme.muted)
                            }
                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(theme.primary.opacity(0.15))
                                    Capsule().fill(theme.primary)
                                        .frame(width: proxy.size.width * box.progress)
                                }
                            }
                            .frame(height: 4)
                        }
                        Text("\(box.count)")
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
    }

    private func reviewQueue(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            TutorBodyText(
                text: "Quick rep: see the front, recall the back, mark how it went. Wrong answers slide back to box 1.",
                theme: theme
            )
            if queue.isEmpty {
                emptySourcesPlaceholder(theme: theme)
            } else {
                ForEach(queue, id: \.self) { card in
                    HStack {
                        Text(card)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(theme.title)
                        Spacer()
                        Text("Tap to flip")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(theme.muted)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))
                }
            }
        }
    }

    private func boxMovement(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            TutorSuccessCard(
                title: "Boxes updated.",
                subtitle: "4 cards moved up, 1 fell back to daily. Tomorrow's queue is set.",
                theme: theme
            )
            HStack(spacing: 10) {
                TutorMetric(value: "5", label: "REVIEWED", theme: theme)
                TutorMetric(value: "4", label: "UP", theme: theme)
                TutorMetric(value: "1", label: "BACK", theme: theme)
            }
            VStack(alignment: .leading, spacing: 8) {
                TutorSectionLabel(text: "MOVEMENT", theme: theme)
                if movements.isEmpty {
                    emptySourcesPlaceholder(theme: theme)
                }
                ForEach(movements, id: \.card) { mv in
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

// MARK: - Mnemonics (3 steps)

private struct MnemonicsMiniApp: View {
    let book: Book
    let onClose: () -> Void
    private let kind: TutorMiniAppKind = .mnemonics
    @State private var step = 0

    private let stepTitles = ["Why mnemonics", "Three angles", "Practice it"]

    private var primarySource: TutorSourceItem? {
        tutorSourceItems(from: book, limit: 1).first
    }

    private var topicTitle: String {
        primarySource?.title ?? "your topic"
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
                primaryTitle: step == 0 ? "See angles" : (step == 1 ? "Practice it" : "Finish"),
                primaryIcon: step == stepTitles.count - 1 ? "checkmark" : "chevron.right",
                onBack: { if step > 0 { step -= 1 } },
                onPrimary: { if step < stepTitles.count - 1 { step += 1 } else { onClose() } }
            )
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
        }
    }

    private func threeAngles(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            TutorBodyText(
                text: "Mastery built three different ways to lock \(topicTitle) into memory. Pick the one that sticks for you.",
                theme: theme
            )
            if primarySource == nil {
                emptySourcesPlaceholder(theme: theme)
            }
            angleCard(
                label: "FROM THE SOURCE",
                heading: topicTitle,
                detail: primarySource?.excerpt.isEmpty == false
                    ? primarySource!.excerpt
                    : "Pulled from your project sources. Mastery will hook the key terms onto the angles below.",
                theme: theme
            )
            angleCard(
                label: "ACRONYM",
                heading: "First-letter cue",
                detail: "Mastery turns the key terms in \(topicTitle) into a short pronounceable acronym you can say out loud.",
                theme: theme
            )
            angleCard(
                label: "STORY",
                heading: "Picture the chain",
                detail: "A vivid mini-story walking through \(topicTitle) end to end — characters, motion, cause and effect.",
                theme: theme
            )
            angleCard(
                label: "MEMORY PALACE",
                heading: "Place each step",
                detail: "Walk through a familiar room and drop one term from \(topicTitle) at each landmark in order.",
                theme: theme
            )
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
                subtitle: "Your mnemonic is saved. We'll bring it back tomorrow to test the hook.",
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
    @State private var step = 0

    private let stepTitles = ["Why this works", "Retrieval round", "How it went"]

    private struct QA {
        let prompt: String
        let correct: Bool
    }

    private var questions: [QA] {
        let items = tutorSourceItems(from: book, limit: 5)
        guard !items.isEmpty else { return [] }
        return items.enumerated().map { i, item in
            QA(prompt: "What is \(item.title)?", correct: i != 2)
        }
    }

    private var rightCount: Int { questions.filter(\.correct).count }
    private var missCount: Int { questions.count - rightCount }

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
                primaryTitle: step == 0 ? "Begin retrieval" : (step == 1 ? "Score it" : "Finish"),
                primaryIcon: step == stepTitles.count - 1 ? "checkmark" : "chevron.right",
                onBack: { if step > 0 { step -= 1 } },
                onPrimary: { if step < stepTitles.count - 1 { step += 1 } else { onClose() } }
            )
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
            TutorBodyText(text: "One question at a time. Try the answer in your head first.", theme: theme)
            if questions.isEmpty {
                emptySourcesPlaceholder(theme: theme)
            }
            ForEach(questions, id: \.prompt) { q in
                HStack {
                    Text(q.prompt)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(theme.title)
                    Spacer()
                    Text("Reveal")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(theme.primary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))
            }
        }
    }

    private func howItWent(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            TutorSuccessCard(
                title: "\(rightCount) / \(questions.count) retrieved.",
                subtitle: missCount == 0
                    ? "Clean round. We'll stretch the next interval."
                    : "\(missCount) slipped — we'll bring \(missCount == 1 ? "it" : "them") back tomorrow when it's almost faded.",
                theme: theme
            )
            HStack(spacing: 10) {
                TutorMetric(value: "\(rightCount)", label: "RIGHT", theme: theme)
                TutorMetric(value: "\(missCount)", label: "MISS", theme: theme)
                TutorMetric(value: "38s", label: "AVG", theme: theme)
            }
            VStack(alignment: .leading, spacing: 8) {
                TutorSectionLabel(text: "QUESTION BY QUESTION", theme: theme)
                ForEach(questions, id: \.prompt) { q in
                    HStack(spacing: 10) {
                        ZStack {
                            Circle().fill(q.correct ? theme.primary.opacity(0.15) : Color(hex: "B0444C").opacity(0.18)).frame(width: 22, height: 22)
                            Image(systemName: q.correct ? "checkmark" : "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(q.correct ? theme.primary : Color(hex: "B0444C"))
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

// MARK: - Cornell Method (3 steps)

private struct CornellMiniApp: View {
    let book: Book
    let onClose: () -> Void
    private let kind: TutorMiniAppKind = .cornell
    @State private var step = 0

    private let stepTitles = ["Read the notes", "Recall by cue", "Write summary"]

    private struct CornellRow {
        let cue: String
        let body: String
    }

    private var rows: [CornellRow] {
        tutorSourceItems(from: book, limit: 5).map { item in
            CornellRow(
                cue: item.title,
                body: item.excerpt.isEmpty ? "Open the source for full notes." : item.excerpt
            )
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
                    case 0: readNotes(theme: theme)
                    case 1: recallByCue(theme: theme)
                    default: writeSummary(theme: theme)
                    }
                }
            }

            TutorMiniAppFooter(
                theme: theme,
                showBack: step > 0,
                primaryTitle: step == 0 ? "Cover & recall" : (step == 1 ? "Write summary" : "Finish"),
                primaryIcon: step == stepTitles.count - 1 ? "checkmark" : "chevron.right",
                onBack: { if step > 0 { step -= 1 } },
                onPrimary: { if step < stepTitles.count - 1 { step += 1 } else { onClose() } }
            )
        }
    }

    private func readNotes(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            TutorBodyText(
                text: "Mastery split your sources into cues and body — Cornell style. Read through once, then on the next step we cover the body and you answer the cues.",
                theme: theme
            )
            if rows.isEmpty {
                emptySourcesPlaceholder(theme: theme)
            }
            VStack(spacing: 0) {
                ForEach(rows, id: \.cue) { row in
                    HStack(alignment: .top, spacing: 0) {
                        Text(row.cue)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(theme.primary)
                            .frame(width: 96, alignment: .leading)
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
                    if row.cue != rows.last?.cue {
                        Rectangle().fill(Color(hex: "EAE4DC")).frame(height: 1)
                    }
                }
            }
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))
        }
    }

    private func recallByCue(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TutorBodyText(text: "Tap each cue and answer it out loud before revealing.", theme: theme)
            if rows.isEmpty {
                emptySourcesPlaceholder(theme: theme)
            }
            ForEach(rows, id: \.cue) { row in
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
                    Text("Reveal")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(theme.primary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))
            }
        }
    }

    private func writeSummary(theme: TutorMiniAppTheme) -> some View {
        VStack(spacing: 14) {
            TutorSuccessCard(
                title: "Summary saved.",
                subtitle: "Cornell loops cues + body + summary. We'll surface this set again in 2 days.",
                theme: theme
            )
            HStack(spacing: 10) {
                TutorMetric(value: "4", label: "CUES", theme: theme)
                TutorMetric(value: "1", label: "SUMMARY", theme: theme)
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
    @State private var step = 0

    private let stepTitles = ["The forgetting curve", "Today's review", "Next reviews"]

    private struct Upcoming {
        let when: String
        let detail: String
        let count: Int
    }

    private var queue: [String] {
        tutorSourceItems(from: book, limit: 8).map(\.title)
    }

    private var dueCount: Int { queue.count }

    private var upcoming: [Upcoming] {
        let n = max(queue.count, 0)
        return [
            Upcoming(when: "Tomorrow", detail: "Tightest interval", count: max(n / 3, 1)),
            Upcoming(when: "In 4 days", detail: "Picked up steam", count: max(n / 2, 1)),
            Upcoming(when: "Next week", detail: "Most cards land here", count: max(n / 2, 1))
        ]
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
                primaryTitle: step == 0 ? "Review now" : (step == 1 ? "Score it" : "Finish"),
                primaryIcon: step == stepTitles.count - 1 ? "checkmark" : "chevron.right",
                onBack: { if step > 0 { step -= 1 } },
                onPrimary: { if step < stepTitles.count - 1 { step += 1 } else { onClose() } }
            )
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
                Text(dueCount > 0
                    ? "\(dueCount) cards due now. Reviewing today protects weeks of work."
                    : "Add a source to start your review queue.")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(theme.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(theme.primary.opacity(0.18), lineWidth: 1))
        }
    }

    private func todaysReview(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TutorBodyText(
                text: queue.isEmpty
                    ? "Add a source to populate your spaced repetition queue."
                    : "\(queue.count) cards. We rebuild your interval based on how each one goes.",
                theme: theme
            )
            if queue.isEmpty {
                emptySourcesPlaceholder(theme: theme)
            }
            ForEach(queue, id: \.self) { card in
                HStack {
                    Text(card)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(theme.title)
                    Spacer()
                    Text("Reveal")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(theme.primary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))
            }
        }
    }

    private func nextReviews(theme: TutorMiniAppTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            TutorSuccessCard(
                title: "Schedule rebuilt.",
                subtitle: "Mastery rebalanced your intervals based on how this round went.",
                theme: theme
            )
            HStack(spacing: 10) {
                TutorMetric(value: "\(dueCount)", label: "REVIEWED", theme: theme)
                TutorMetric(value: "\(dueCount * 2)", label: "SCHEDULED", theme: theme)
                TutorMetric(value: "+3.2d", label: "AVG INTERVAL", theme: theme)
            }
            VStack(alignment: .leading, spacing: 8) {
                TutorSectionLabel(text: "COMING UP", theme: theme)
                ForEach(upcoming, id: \.when) { up in
                    HStack(spacing: 12) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(theme.primary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(up.when)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(theme.title)
                            Text(up.detail)
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundColor(theme.muted)
                        }
                        Spacer()
                        Text("\(up.count) cards")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(theme.title)
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
