//
//  CacheStore.swift - 简单的 JSON 本地缓存（内存 + 磁盘两层）
//
import Foundation

final class CacheStore {
    static let shared = CacheStore()

    private let dir: URL
    private let enabledKey = "cacheEnabled"
    private let memory = NSCache<NSString, NSData>()   // 内存缓存层，避免频繁读磁盘

    init() {
        memory.countLimit = 200
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        dir = base.appendingPathComponent("BIT101Cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    private var enabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) == nil
            ? true : UserDefaults.standard.bool(forKey: enabledKey)
    }

    /// 读取缓存（先内存后磁盘）；未启用缓存或不存在时返回 nil
    func read<T: Decodable>(_ key: String, as type: T.Type) -> T? {
        guard enabled else { return nil }
        if let data = memory.object(forKey: key as NSString) as Data? {
            return try? JSONDecoder().decode(T.self, from: data)
        }
        let url = dir.appendingPathComponent(key + ".json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        memory.setObject(data as NSData, forKey: key as NSString)
        return try? JSONDecoder().decode(T.self, from: data)
    }

    /// 写入缓存（内存 + 磁盘；仅当启用缓存时）
    func write<T: Encodable>(_ value: T, key: String) {
        guard enabled else { return }
        if let data = try? JSONEncoder().encode(value) {
            memory.setObject(data as NSData, forKey: key as NSString)
            let url = dir.appendingPathComponent(key + ".json")
            try? data.write(to: url)
        }
    }

    /// 清空所有缓存（内存 + 磁盘文件）
    func clear() {
        memory.removeAllObjects()
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        for f in files { try? FileManager.default.removeItem(at: f) }
    }
}
