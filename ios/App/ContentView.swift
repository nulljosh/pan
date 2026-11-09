import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var equations: [Equation] = defaultEquations
    @AppStorage("degrees") private var degrees = false
    @State private var transform = GraphTransform()
    @State private var exportedImage: ExportedGraph?
    /// iPhone: the equation sheet's height. Starts at a third so the plot shows above it.
    @State private var detent: PresentationDetent = .fraction(0.34)
    /// Sliders whose play button is on, and the values they are sweeping through. Kept out of
    /// the row text so a playing slider does not rewrite and save it sixty times a second.
    @State private var playing: Set<String> = []
    @State private var animated: [String: Double] = [:]

    var body: some View {
        content
            .overlay(alignment: .topTrailing) { exportButton }
            .overlay(alignment: .topLeading) {
                HStack(spacing: 8) { homeButton; angleButton }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .background(Theme.graphBackground)
            .onAppear(perform: restore)
            .task(id: playing) { await animateSliders() }
            .sheet(item: horizontalSizeClass == .compact ? .constant(nil) : $exportedImage) { export in
                ExportSheet(export: export)
            }
    }

    // MARK: - Layout

    /// iPad gets the web app's side-by-side layout; iPhone stacks, since a 320pt-wide
    /// sidebar next to a plot is unusable.
    ///
    /// This branches on the size class rather than `ViewThatFits`. `ViewThatFits` measures
    /// each branch at its *ideal* size, and `graph` is a `GeometryReader`, which has no
    /// intrinsic width, it reports SwiftUI's 10pt default against an unspecified proposal.
    /// That made the side-by-side branch measure ~331pt (10 + divider + 320 sidebar), which
    /// "fits" every iPhone from the 375pt SE up, so iPhones took the HStack and the plot was
    /// left with whatever the 320pt sidebar didn't eat, about 69pt. That is the squashed
    /// graph. The size class is the actual signal for "is this a phone", so ask it directly.
    @ViewBuilder
    private var content: some View {
        // The graph is the whole screen, edge to edge; the equation list floats over it
        // as glass instead of taking a slice of the layout away from the plot.
        let compact = horizontalSizeClass == .compact
        GraphView(equations: drawn, vars: sliderValues, transform: $transform)
            .ignoresSafeArea()
            // iPhone: a real sheet, like Maps. Scrolling the list grows it to full height before it scrolls,
            // the grabber shrinks it to a strip so the whole plot is reachable, and the graph keeps taking
            // drags and pinches underneath. It replaced a fixed 34 percent panel whose list scrolled in a
            // small window and ran under the rounded corners (roadmap, 2026-10-21).
            .sheet(isPresented: .constant(compact)) {
                sidebar
                    .presentationDetents([.height(72), .fraction(0.34), .large], selection: $detent)
                    .presentationDragIndicator(.visible)
                    .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.34)))
                    .interactiveDismissDisabled()
                    // One sheet at a time: on a phone the export sheet is shown from this one.
                    .sheet(item: $exportedImage) { export in ExportSheet(export: export) }
            }
            .overlay(alignment: .trailing) {
                if !compact {
                    sidebar
                        .frame(width: 320)
                        .panGlass(in: RoundedRectangle(cornerRadius: 28))
                        .padding(12)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
            }
    }

    /// The rows the graph draws: visible ones, with each list row expanded into one copy per element.
    private var drawn: [Equation] {
        let lists = Dictionary(equations.compactMap { parseListDef($0.source) }, uniquingKeysWith: { first, _ in first })
        return equations.filter { !$0.hidden }.flatMap { equation -> [Equation] in
            let (source, binds) = expandRow(equation.source, lists: lists)
            if binds.count == 1, binds[0].isEmpty { return [equation] }
            return binds.map { binding in
                var copy = Equation(id: equation.id, source: source, colorIndex: equation.colorIndex)
                copy.bindings = binding
                return copy
            }
        }
    }

    /// Every `a = 3` and `f(x) = ...` row, hidden or not: hiding one must not break the curves using it.
    private var sliderValues: Vars {
        buildVars(
            equations.map(\.source),
            values: Dictionary(equations.compactMap(\.compiled.slider).map { ($0.name, $0.value) }, uniquingKeysWith: { first, _ in first })
                .merging(animated) { _, playing in playing },
            degrees: degrees
        )
    }

    private var sidebar: some View {
        ScrollView {
            EquationListView(
                equations: $equations, onChange: persist,
                playing: playing, animated: animated, onTogglePlay: togglePlay
            )
                .padding(16)
        }
    }

    private var homeButton: some View {
        Button { transform = GraphTransform() } label: {
            Image(systemName: "house")
                .foregroundStyle(Theme.text)
                .frame(width: 44, height: 44)
                .panGlass(in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Reset the view")
    }

    private var angleButton: some View {
        Button { degrees.toggle() } label: {
            Text(degrees ? "DEG" : "RAD")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.text)
                .frame(minWidth: 56, minHeight: 44)
                .panGlass(in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(degrees ? "Angles in degrees, switch to radians" : "Angles in radians, switch to degrees")
    }

    // ponytail: no title bar and no zoom buttons. The graph says what app this is, and
    // pinch and drag already live in GraphView.
    private var exportButton: some View {
        Button(action: exportGraph) {
            Image(systemName: "square.and.arrow.up")
                .foregroundStyle(Theme.text)
                .frame(width: 44, height: 44)
                .panGlass(in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Export graph as an image")
        // Clear the 320pt sidebar on iPad and Mac, or it lands on row one's remove button.
        .padding(.trailing, horizontalSizeClass == .compact ? 0 : 344)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Actions

    /// ponytail: ImageRenderer over the same GraphView, one source of truth for what a
    /// curve looks like, rather than a second drawing path just for export.
    private func exportGraph() {
        let snapshot = GraphView(equations: drawn, vars: sliderValues, transform: .constant(transform))
            .frame(width: 1200, height: 900)
        let renderer = ImageRenderer(content: snapshot)
        renderer.scale = 2
        // cgImage, not uiImage: UIImage does not exist on macOS and NSImage does not exist
        // on iOS, so CoreGraphics is the one type both destinations share.
        guard let cgImage = renderer.cgImage, let png = pngData(from: cgImage) else { return }
        exportedImage = ExportedGraph(image: Image(decorative: cgImage, scale: 2), png: png)
    }

    private func restore() {
        guard let saved = Store.load() else { return }
        equations = saved
    }

    /// Play sweeps each playing slider from one end of its range to the other and back, every 4 s.
    private func animateSliders() async {
        var direction: [String: Double] = [:]
        var last = Date()
        while !playing.isEmpty, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(16))
            let now = Date()
            let dt = min(0.1, now.timeIntervalSince(last))
            last = now
            for slider in equations.compactMap(\.compiled.slider) where playing.contains(slider.name) {
                let span = slider.range.upperBound - slider.range.lowerBound
                var value = (animated[slider.name] ?? slider.value) + (direction[slider.name] ?? 1) * span * dt / 4
                if value >= slider.range.upperBound {
                    value = slider.range.upperBound
                    direction[slider.name] = -1
                } else if value <= slider.range.lowerBound {
                    value = slider.range.lowerBound
                    direction[slider.name] = 1
                }
                animated[slider.name] = value
            }
        }
    }

    /// Pausing writes the slider's current value back into its row, once.
    private func togglePlay(_ name: String) {
        guard playing.remove(name) != nil else {
            playing.insert(name)
            return
        }
        guard let value = animated.removeValue(forKey: name),
              let index = equations.firstIndex(where: { $0.compiled.slider?.name == name }),
              let slider = equations[index].compiled.slider else { return }
        equations[index].update(source: sliderSource(slider, value: value))
        persist()
    }

    private func persist() {
        Store.save(equations)
    }
}

struct ExportedGraph: Identifiable, Transferable {
    let id = UUID()
    /// On-screen preview only.
    let image: Image
    /// What actually gets shared. Sharing the `Image` instead would hand the receiver an
    /// unnamed image and give us nothing testable; PNG bytes with a filename arrive as a
    /// real file in Mail, Messages, Finder and every other share target.
    let png: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.png }
            .suggestedFileName("pan-graph.png")
    }
}

/// ponytail: replaced a `UIViewControllerRepresentable` over `UIActivityViewController`,
/// which is iOS-only. `ShareLink` is the native share affordance on both destinations and
/// needs no representable at all.
struct ExportSheet: View {
    let export: ExportedGraph
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            export.image
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 600)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            ShareLink(item: export, preview: SharePreview("Graph", image: export.image)) {
                Label("Share graph", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)

            Button("Done") { dismiss() }
        }
        .padding(24)
        .frame(minWidth: 360, minHeight: 320)
    }
}
