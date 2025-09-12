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
            List(viewModel.internships) { internship in
                VStack(alignment: .leading) {
                    Text(internship.company)
                        .font(.headline)
                    Text(internship.role)
                        .font(.subheadline)
                    Text(internship.location)
                        .font(.caption)
                    Link("Apply", destination: URL(string: internship.link)!)
                        .font(.caption)
                    Text("Posted: \(internship.datePosted)")
                        .font(.caption2)
                }
            }
            .navigationTitle("Internships 2026")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gear")
                    }
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

    // Simple Markdown Table Parser
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
                    let link = columns[4].replacingOccurrences(of: "<a href=\"", with: "").replacingOccurrences(of: "\">", with: "").replacingOccurrences(of: "<img src=", with: "").components(separatedBy: ">" ).first ?? ""
                    let datePosted = columns[5]
                    internships.append(Internship(company: company, role: role, location: location, link: link, datePosted: datePosted))
                }
            }
        }
        return internships
    }
}
    }
}

#Preview {
    ContentView()
}
