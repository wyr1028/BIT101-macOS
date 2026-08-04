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
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
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
            Divider().padding(.vertical, 4)
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
            .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        case "table":
            if let rows = block.data?.content {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { ri, row in
                        HStack(spacing: 0) {
                            ForEach(row, id: \.self) { cell in
                                Text(cell).font(.caption).padding(.horizontal, 8).padding(.vertical, 4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(ri == 0 ? Color.secondary.opacity(0.1) : Color.clear)
                            }
                        }
                        Divider()
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.2)))
            }
        default:
            if let text = block.data?.displayText, !text.isEmpty {
                Text(text).font(.body)
            }
        }
    }
}

func parseEditorJS(_ str: String) -> EditorJSContent? {
    guard let data = str.data(using: .utf8) else { return nil }
    return try? JSONDecoder().decode(EditorJSContent.self, from: data)
}
