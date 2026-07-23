import SwiftUI

struct StatusView: View {
    @State private var viewModel = StatusViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    healthSection
                    skillsSection
                    toolsetsSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Status")
            .refreshable {
                await viewModel.loadAll()
            }
            .task {
                await viewModel.loadAll()
            }
        }
        .errorToast($viewModel.errorMessage)
    }

    @ViewBuilder
    private var healthSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Health", icon: "heart.text.square")

            if viewModel.healthIsLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if let health = viewModel.healthStatus {
                GroupBox {
                    VStack(spacing: 12) {
                        statusIndicator(health.status)

                        Divider()

                        InfoRow(label: "Version", value: health.version ?? "N/A")
                        if let uptime = health.uptimeFormatted {
                            InfoRow(label: "Uptime", value: uptime)
                        } else if let uptime = health.uptime {
                            InfoRow(label: "Uptime", value: formatUptime(uptime))
                        }

                        if let capabilities = health.capabilities, !capabilities.isEmpty {
                            Divider()
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Capabilities")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                FlowLayout(spacing: 6) {
                                    ForEach(capabilities, id: \.self) { cap in
                                        Text(cap)
                                            .font(.caption2)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(.blue.opacity(0.1), in: Capsule())
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                Text("No health data available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
    }

    @ViewBuilder
    private var skillsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Skills", icon: "gearshape.2")

            if viewModel.skillsIsLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if viewModel.skills.isEmpty {
                Text("No skills found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(viewModel.skills) { skill in
                    SkillRow(skill: skill)
                }
            }
        }
    }

    @ViewBuilder
    private var toolsetsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Toolsets", icon: "wrench.and.screwdriver")

            if viewModel.toolsetsIsLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if viewModel.toolsets.isEmpty {
                Text("No toolsets found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(viewModel.toolsets) { toolset in
                    ToolsetRow(toolset: toolset)
                }
            }
        }
    }

    @ViewBuilder
    private func statusIndicator(_ status: String?) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor(status))
                .frame(width: 12, height: 12)
            Text(status ?? "Unknown")
                .font(.headline)
            Spacer()
        }
    }

    private func statusColor(_ status: String?) -> Color {
        guard let status = status?.lowercased() else { return .gray }
        if status == "ok" || status == "healthy" || status == "running" {
            return .green
        } else if status == "degraded" {
            return .yellow
        }
        return .red
    }

    private func formatUptime(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .monospaced()
        }
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
            Text(title)
                .font(.headline)
        }
        .padding(.top, 4)
    }
}

struct SkillRow: View {
    let skill: Skill

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(skill.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    if let enabled = skill.enabled {
                        Circle()
                            .fill(enabled ? Color.green : Color.secondary)
                            .frame(width: 6, height: 6)
                    }
                    Spacer()
                    if let version = skill.version {
                        Text("v\(version)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                if let description = skill.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct ToolsetRow: View {
    let toolset: Toolset

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                Text(toolset.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if let description = toolset.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let tools = toolset.tools, !tools.isEmpty {
                    FlowLayout(spacing: 4) {
                        ForEach(tools) { tool in
                            Text(tool.name)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.orange.opacity(0.1), in: Capsule())
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var width: CGFloat = 0
        var height: CGFloat = 0
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0

        for size in sizes {
            if lineWidth + size.width > (proposal.width ?? .infinity) {
                width = max(width, lineWidth)
                height += lineHeight + spacing
                lineWidth = size.width + spacing
                lineHeight = size.height
            } else {
                lineWidth += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
        }
        width = max(width, lineWidth)
        height += lineHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for (index, subview) in subviews.enumerated() {
            let size = sizes[index]
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
