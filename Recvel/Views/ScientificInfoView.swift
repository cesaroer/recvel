import SwiftUI
import UIKit

enum ScientificTerm: String, CaseIterable, Identifiable {
    case hrv = "HRV"
    case rhr = "RHR"
    case vo2Max = "VO₂ max"
    case spo2 = "SpO₂"
    case sdnn = "SDNN"
    case rem = "REM"
    case met = "MET"

    var id: String { rawValue }

    private var key: String {
        switch self {
        case .hrv: "hrv"
        case .rhr: "rhr"
        case .vo2Max: "vo2"
        case .spo2: "spo2"
        case .sdnn: "sdnn"
        case .rem: "rem"
        case .met: "met"
        }
    }

    var fullName: String { RecvelL10n.text("term.\(key).name") }
    var summary: String { RecvelL10n.text("term.\(key).summary") }
    var limitation: String { RecvelL10n.text("term.\(key).limit") }

    var sources: [ScientificSource] {
        switch self {
        case .hrv, .sdnn:
            [
                ScientificSource(
                    title: "Task Force ESC/NASPE: Heart rate variability",
                    url: URL(string: "https://pubmed.ncbi.nlm.nih.gov/8598068/")!
                ),
                ScientificSource(
                    title: "HRV as a digital biomarker",
                    url: URL(string: "https://pmc.ncbi.nlm.nih.gov/articles/PMC12849089/")!
                )
            ]
        case .rhr:
            [ScientificSource(
                title: "Resting heart rate and mortality",
                url: URL(string: "https://pubmed.ncbi.nlm.nih.gov/24290115/")!
            )]
        case .vo2Max:
            [
                ScientificSource(
                    title: "Apple Watch VO2 max validation",
                    url: URL(string: "https://pmc.ncbi.nlm.nih.gov/articles/PMC12080799/")!
                ),
                ScientificSource(
                    title: "FRIEND cardiorespiratory fitness reference",
                    url: URL(string: "https://pubmed.ncbi.nlm.nih.gov/26455884/")!
                )
            ]
        case .spo2:
            [ScientificSource(
                title: "Apple: Blood Oxygen measurements",
                url: URL(string: "https://support.apple.com/en-us/120358")!
            )]
        case .rem:
            [ScientificSource(
                title: "Wearable sleep staging validation review",
                url: URL(string: "https://pmc.ncbi.nlm.nih.gov/articles/PMC10654909/")!
            )]
        case .met:
            [ScientificSource(
                title: "Compendium of Physical Activities",
                url: URL(string: "https://pubmed.ncbi.nlm.nih.gov/21681120/")!
            )]
        }
    }
}

struct ScientificSource: Identifiable, Hashable {
    let title: String
    let url: URL
    var id: URL { url }
}

struct ScientificInfoButton: View {
    let term: ScientificTerm
    @State private var showsDefinition = false
    @State private var showsMethodology = false

    var body: some View {
        Button {
            Haptics.soft()
            showsDefinition.toggle()
        } label: {
            Image(systemName: "info.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            RecvelL10n.text("scientific.info.accessibility", values: ["term": term.rawValue])
        )
        .accessibilityIdentifier("scientific.info.\(term.id)")
        .popover(isPresented: $showsDefinition, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
            definitionPopover
                .presentationCompactAdaptation(.popover)
        }
        .sheet(isPresented: $showsMethodology) {
            ScientificMethodologyView(term: term)
        }
        .task(id: showsDefinition) {
            guard showsDefinition,
                  !UIAccessibility.isVoiceOverRunning,
                  !UIAccessibility.isSwitchControlRunning else { return }
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            showsDefinition = false
        }
    }

    private var definitionPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(term.rawValue)
                    .font(.headline.weight(.bold))
                Text(term.fullName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
            }

            Text(term.summary)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                showsDefinition = false
                showsMethodology = true
            } label: {
                Label("common.learnMore", systemImage: "doc.text.magnifyingglass")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.cyan)
        }
        .padding(15)
        .frame(idealWidth: 310, maxWidth: 340, alignment: .leading)
        .liquidGlass(cornerRadius: 8, tint: .cyan)
        .contentShape(Rectangle())
        .onTapGesture { showsDefinition = false }
    }
}

private struct ScientificMethodologyView: View {
    @Environment(\.dismiss) private var dismiss
    let term: ScientificTerm

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                WidthLockedScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(term.rawValue)
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                            Text(term.fullName)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }

                        methodologyCard(
                            titleKey: "scientific.definition",
                            icon: "waveform.path.ecg",
                            text: term.summary,
                            color: .cyan
                        )
                        methodologyCard(
                            titleKey: "scientific.limitation",
                            icon: "exclamationmark.shield.fill",
                            text: term.limitation,
                            color: ScoreKind.energy.color
                        )

                        Text("scientific.sources")
                            .font(.title3.weight(.bold))
                        ForEach(term.sources) { source in
                            Link(destination: source.url) {
                                HStack(spacing: 12) {
                                    Image(systemName: "book.closed.fill")
                                        .foregroundStyle(.cyan)
                                    Text(source.title)
                                        .font(.subheadline.weight(.medium))
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(14)
                                .liquidGlass(cornerRadius: 8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("scientific.methodology.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.close") { dismiss() }
                }
            }
            .liquidGlassNavigationBar()
        }
    }

    private func methodologyCard(titleKey: String, icon: String, text: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(titleKey, systemImage: icon)
                .font(.headline)
                .foregroundStyle(color)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .liquidGlass(cornerRadius: 8, tint: color)
    }
}
