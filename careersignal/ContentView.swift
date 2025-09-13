//
//  ContentView.swift
//  careersignal
//
//  Created by Eliot Pontarelli on 9/12/25.
//

import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var viewModel = InternshipViewModel()
    @State private var showSettings = false

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.csBackgroundTop, Color.csBackgroundBottom]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                List(viewModel.internships) { internship in
                    InternshipRow(internship: internship)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Internships 2026")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gear")
                    }
                    .tint(Color.csAccent)
                }
            }
            .sheet(isPresented: $showSettings) {
                NotificationSettingsView()
            }
            .onAppear {
                viewModel.fetchInternships()
                viewModel.startPolling()
            }
        }
        .preferredColorScheme(.dark)
        .tint(Color.csAccent)
    }
}
// MARK: - Notification Settings View
struct NotificationSettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true

    var body: some View {
        NavigationView {
            Form {
                Toggle("Enable Internship Notifications", isOn: $notificationsEnabled)
            }
            .navigationTitle("Settings")
        }
    }
}
// MARK: - Internship Model
struct Internship: Identifiable {
    let id = UUID()
    let company: String
    let role: String
    let location: String
    let link: String
    let datePosted: String
}

// MARK: - ViewModel
class InternshipViewModel: ObservableObject {
    @Published var internships: [Internship] = []
    private var cancellables = Set<AnyCancellable>()
    private var lastInternshipIDs: Set<String> = []

    func fetchInternships() {
        guard let url = URL(string: "https://raw.githubusercontent.com/vanshb03/Summer2026-Internships/main/README.md") else { return }
        URLSession.shared.dataTaskPublisher(for: url)
            .map { String(data: $0.data, encoding: .utf8) ?? "" }
            .map { self.parseInternships(from: $0) }
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newInternships in
                guard let self = self else { return }
                let newIDs = Set(newInternships.map { $0.company + $0.role + $0.location })
                let addedIDs = newIDs.subtracting(self.lastInternshipIDs)
                let notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
                if notificationsEnabled && !self.lastInternshipIDs.isEmpty {
                    for id in addedIDs {
                        if let internship = newInternships.first(where: { $0.company + $0.role + $0.location == id }) {
                            NotificationManager.shared.sendNotification(title: "New Internship Posted!", body: "\(internship.company) - \(internship.role)")
                        }
                    }
                }
                self.lastInternshipIDs = newIDs
                self.internships = newInternships
            }
            .store(in: &cancellables)
    }
    // Optionally, poll for updates every X minutes
    func startPolling() {
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.fetchInternships()
        }
    }

    // Simple Markdown/HTML Table Parser with robust link extraction
    func parseInternships(from markdown: String) -> [Internship] {
        var internships: [Internship] = []
        let lines = markdown.components(separatedBy: "\n")
        var inTable = false
        for line in lines {
            if line.contains("| Company |") { inTable = true; continue }
            if inTable && line.starts(with: "|") && !line.contains("----") {
                let columns = line.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                if columns.count >= 6 {
                    let company = columns[1]
                    let role = columns[2]
                    let location = columns[3]
                    let linkText = columns[4]
                    let link = extractFirstURL(from: linkText) ?? ""
                    let datePosted = columns[5]
                    internships.append(Internship(company: company, role: role, location: location, link: link, datePosted: datePosted))
                }
            }
        }
        return internships
    }

    // Extracts the first URL from markdown or HTML content
    private func extractFirstURL(from text: String) -> String? {
        // Try HTML: <a href="URL">
        if let hrefRange = text.range(of: "href=\""),
           let endQuote = text[hrefRange.upperBound...].firstIndex(of: "\"") {
            let url = String(text[hrefRange.upperBound..<endQuote])
            return url
        }
        // Try Markdown: [label](URL)
        if let openParen = text.firstIndex(of: "("), let closeParen = text.firstIndex(of: ")"), openParen < closeParen {
            let url = String(text[text.index(after: openParen)..<closeParen])
            if url.starts(with: "http://") || url.starts(with: "https://") { return url }
        }
        // Fallback: regex-like scan for http(s):// until a space, quote, angle or paren
        if let range = text.range(of: "https?://[A-Za-z0-9._%/\\-?#=&:+~]+", options: .regularExpression) {
            return String(text[range])
        }
        return nil
    }
}
// MARK: - Row View
struct InternshipRow: View {
    let internship: Internship
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(internship.company)
                .font(.system(.headline, design: .monospaced))
                .foregroundColor(.white)

            Text(internship.role)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundColor(Color.csAccent)

            HStack {
                Image(systemName: "mappin.and.ellipse").foregroundColor(Color.csAccent)
                Text(internship.location)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                if let url = URL(string: internship.link) {
                    ApplyButton(url: url)
                } else {
                    Text("Apply link unavailable")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Text("Posted: \(internship.datePosted)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 2)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
        .fill(Color.csCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
            .stroke(Color.csAccent.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.5), radius: 8, x: 0, y: 4)
        )
    }
}

// Compact capsule-styled Apply button with tight leading padding
private struct ApplyButton: View {
    let url: URL
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button(action: { openURL(url) }) {
            Text("Apply")
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.vertical, 8)
                .padding(.leading, 12)   // tighter leading
                .padding(.trailing, 12)
                .background(
                    Capsule().fill(Color.csAccent)
                )
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
