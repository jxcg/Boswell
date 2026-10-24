import BoswellCore
import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("The AI drafts. Code checks. You decide.")
                        .font(.headline)
                    Text("Fictional-data prototype. Not for real patient use.")
                        .foregroundStyle(.secondary)
                }

                Section("Evidence key") {
                    ForEach(Confidence.allCases, id: \.self) { confidence in
                        HStack(spacing: 16) {
                            Text(confidence.symbol)
                                .font(.title2.bold())
                                .frame(width: 28)
                                .foregroundStyle(confidence.tint)
                                .accessibilityHidden(true)
                            Text(confidence.label)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }

                Section {
                    Text("Verified means the draft matches transcript evidence, not that it is clinically correct. Every item still needs clinician review.")
                    Text("Recording and note drafting are not available yet.")
                        .foregroundStyle(.secondary)
                }

                Section("Developer checks") {
                    NavigationLink("Check this iPhone") {
                        DeviceCheckView()
                    }
                }
            }
            .navigationTitle("Boswell")
        }
    }
}

private extension Confidence {
    var tint: Color {
        switch self {
        case .green: return .green
        case .yellow: return .yellow
        case .red: return .red
        }
    }
}

#Preview {
    ContentView()
}
