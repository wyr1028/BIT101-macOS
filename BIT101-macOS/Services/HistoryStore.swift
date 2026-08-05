//
//  HistoryStore.swift - 本地浏览历史（最近打开的话题/文章）
//
import Foundation
import SwiftUI

struct HistoryEntry: Codable, Identifiable {
    var id: String { "\(type)\(itemId)" }
    let type: String       // "poster" / "paper"
    let itemId: Int
    let title: String
    let date: Date
}

enum HistoryStore {
    private static let key = "browseHistory"

    static var entries: [HistoryEntry] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([HistoryEntry].self, from: data) else { return [] }
        return list
    }

    static func record(type: String, id: Int, title: String) {
        var list = entries
        list.removeAll { $0.type == type && $0.itemId == id }
        list.insert(HistoryEntry(type: type, itemId: id, title: title, date: Date()), at: 0)
        if list.count > 15 { list = Array(list.prefix(15)) }
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

/// 「最近浏览」横向胶囊条
struct RecentHistoryStrip: View {
    let type: String
    var onOpen: (HistoryEntry) -> Void

    var body: some View {
        let entries = HistoryStore.entries.filter { $0.type == type }
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: Sp.s) {
                Text("最近浏览").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Sp.s) {
                        ForEach(entries) { e in
                            Button { onOpen(e) } label: {
                                Text(e.title).font(.caption).lineLimit(1)
                                    .padding(.horizontal, Sp.m).padding(.vertical, 4)
                                    .background(Capsule().fill(.ultraThinMaterial))
                                    .overlay(Capsule().strokeBorder(.secondary.opacity(0.2), lineWidth: 1))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}
