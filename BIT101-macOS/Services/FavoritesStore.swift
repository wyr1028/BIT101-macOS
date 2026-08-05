//
//  FavoritesStore.swift - 本地收藏（帖子/文章）
//
import Foundation
import SwiftUI

enum FavoritesStore {
    private static let key = "favorites"
    private static var set: Set<String> = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])

    static func isFavorited(_ id: String) -> Bool { set.contains(id) }

    @discardableResult
    static func toggle(_ id: String) -> Bool {
        if set.contains(id) {
            set.remove(id)
        } else {
            set.insert(id)
        }
        UserDefaults.standard.set(Array(set), forKey: key)
        return set.contains(id)
    }
}

/// 紧凑版收藏按钮（仅星形图标）
struct FavoriteIconButton: View {
    let id: String
    @State private var fav: Bool

    init(id: String) {
        self.id = id
        _fav = State(initialValue: FavoritesStore.isFavorited(id))
    }

    var body: some View {
        Button {
            fav = FavoritesStore.toggle(id)
        } label: {
            Image(systemName: fav ? "star.fill" : "star")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(fav ? .yellow : .secondary)
        }
        .buttonStyle(.plain)
        .wideHitArea(24)
    }
}

/// 收藏按钮（星形，黄色高亮）
struct FavoriteButton: View {
    let id: String
    @State private var fav: Bool

    init(id: String) {
        self.id = id
        _fav = State(initialValue: FavoritesStore.isFavorited(id))
    }

    var body: some View {
        Button {
            fav = FavoritesStore.toggle(id)
        } label: {
            Label(fav ? "已收藏" : "收藏", systemImage: fav ? "star.fill" : "star")
                .foregroundColor(fav ? .yellow : .secondary)
        }
        .buttonStyle(.plain)
        .wideHitArea()
    }
}
