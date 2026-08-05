import SwiftUI

struct EditorJSRenderer: View {
    let content: EditorJSContent?

    var body: some View {
        if let blocks = content?.blocks {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(blocks) { block in
                    renderBlock(block)
                }
            }
        }
    }

    @ViewBuilder
    func renderBlock(_ block: EditorJSBlock) -> some View {
        switch block.type {
        case "header":
            if let text = block.data?.text {
                switch block.data?.level {
                case 2: Text(text).font(.title3.bold()).padding(.top, 8)
                case 3: Text(text).font(.headline).padding(.top, 4)
                default: Text(text).font(.title2.bold()).padding(.top, 12)
                }
            }
        case "paragraph":
            if let text = block.data?.text {
                Text(text).font(.body).lineSpacing(4)
            }
        case "list":
            if let items = block.data?.items {
                let ordered = block.data?.style == "ordered"
                if ordered {
                    ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(i+1).").foregroundStyle(.secondary).frame(width: 24, alignment: .trailing)
                            Text(item).font(.body)
                        }
                    }
                } else {
                    ForEach(items, id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•").foregroundStyle(.secondary)
                            Text(item).font(.body)
                        }
                    }
                }
            }
        case "code":
            if let code = block.data?.code {
                Text(code).font(.system(.callout, design: .monospaced))
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous).strokeBorder(.secondary.opacity(0.15), lineWidth: 1))
            }
        case "quote":
            VStack(alignment: .leading, spacing: 4) {
                if let text = block.data?.text {
                    Text(text).font(.callout).italic().foregroundStyle(.secondary)
                }
                if let caption = block.data?.caption {
                    Text("— \(caption)").font(.caption).foregroundStyle(.tertiary)
                }
            }
            .padding(.leading, 8)
            .overlay(Rectangle().fill(.secondary.opacity(0.3)).frame(width: 3), alignment: .leading)
            .padding(.vertical, 4)
        case "delimiter":
            GlassDivider().padding(.vertical, 4)
        case "warning":
            VStack(alignment: .leading, spacing: 4) {
                if let title = block.data?.title {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                        Text(title).font(.subheadline.bold())
                    }
                }
                if let msg = block.data?.message {
                    Text(msg).font(.callout).foregroundStyle(.secondary)
                }
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).strokeBorder(.orange.opacity(0.25), lineWidth: 1))
        case "image":
            imageBlock(block)
        case "table":
            if let rows = block.data?.content {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { ri, row in
                        HStack(spacing: 0) {
                            ForEach(row, id: \.self) { cell in
                                Text(cell).font(.caption).padding(.horizontal, 8).padding(.vertical, 4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(ri == 0 ? Color.primary.opacity(0.06) : Color.clear)
                            }
                        }
                        GlassDivider()
                    }
                }
                .background(.ultraThinMaterial.opacity(0.5), in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous).strokeBorder(.secondary.opacity(0.2), lineWidth: 1))
            }
        case "attaches", "file":
            if let f = block.data?.file, let u = f.url, let url = imageURL(u) {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFit().frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                } placeholder: {
                    Label(f.name ?? "附件", systemImage: "paperclip").font(.callout).foregroundStyle(.secondary)
                }
            }
        default:
            if let text = block.data?.displayText, !text.isEmpty {
                Text(text).font(.body)
            }
        }
    }

    @ViewBuilder
    func imageBlock(_ block: EditorJSBlock) -> some View {
        let urlStr = (block.data?.file?.url) ?? block.data?.url
        if let u = urlStr, let url = imageURL(u) {
            VStack(alignment: .leading, spacing: 4) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFit().frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                    case .failure:
                        Label("图片加载失败", systemImage: "photo").font(.callout).foregroundStyle(.secondary)
                    default:
                        ProgressView().frame(maxWidth: .infinity).padding(12)
                    }
                }
                if let cap = block.data?.caption, !cap.isEmpty {
                    Text(cap).font(.caption).foregroundStyle(.tertiary)
                }
            }
        }
    }

    /// 将 BIT101 相对路径的图片地址补全为绝对 URL
    func imageURL(_ s: String) -> URL? {
        if s.hasPrefix("http") { return URL(string: s) }
        return URL(string: "https://bit101.flwfdd.xyz" + (s.hasPrefix("/") ? s : "/" + s))
    }
}

func parseEditorJS(_ str: String) -> EditorJSContent? {
    guard let data = str.data(using: .utf8) else { return nil }
    return try? JSONDecoder().decode(EditorJSContent.self, from: data)
}
