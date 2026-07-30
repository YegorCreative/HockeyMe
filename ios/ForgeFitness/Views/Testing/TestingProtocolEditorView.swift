import SwiftUI

struct TestingProtocolEditorView: View {
    @StateObject private var viewModel: TestingProtocolEditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var presentsMetrics = false
    @State private var customName = ""
    @State private var customUnit = ""
    @State private var customCategory = TestingMetricCategory.custom
    let onSaved: () -> Void

    init(
        protocolValue: TestingProtocol? = nil,
        repository: TestingRepository,
        onSaved: @escaping () -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: TestingProtocolEditorViewModel(
                protocolValue: protocolValue,
                repository: repository
            )
        )
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Protocol") {
                    TextField("Name", text: $viewModel.name)
                    TextField(
                        "Description",
                        text: $viewModel.description,
                        axis: .vertical
                    )
                    Toggle(
                        "Allow athlete self-entry",
                        isOn: $viewModel.allowsAthleteEntry
                    )
                    Picker("Status", selection: $viewModel.status) {
                        ForEach(TestingProtocolStatus.allCases, id: \.self) {
                            Text($0.rawValue.capitalized).tag($0)
                        }
                    }
                }

                Section("Metrics") {
                    ForEach(viewModel.metrics) { metric in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(metric.name)
                                Text(
                                    "\(metric.category.title) • \(metric.unit)"
                                )
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                            }
                            Spacer()
                        }
                        .accessibilityElement(children: .combine)
                    }
                    .onDelete(perform: viewModel.removeMetrics)

                    Button("Add Standard Metric") {
                        presentsMetrics = true
                    }

                    TextField("Custom metric name", text: $customName)
                    TextField("Custom unit", text: $customUnit)
                    Picker("Category", selection: $customCategory) {
                        ForEach(TestingMetricCategory.allCases) {
                            Text($0.title).tag($0)
                        }
                    }
                    Button("Add Custom Metric") {
                        viewModel.addCustomMetric(
                            name: customName,
                            unit: customUnit,
                            category: customCategory
                        )
                        customName = ""
                        customUnit = ""
                    }
                    .disabled(customName.isEmpty || customUnit.isEmpty)
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(AppColors.error)
                        .accessibilityLabel("Error: \(error)")
                }
            }
            .navigationTitle("Testing Protocol")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await viewModel.save() {
                                onSaved()
                            }
                        }
                    }
                    .disabled(!viewModel.canSave || viewModel.isSaving)
                }
            }
        }
        .sheet(isPresented: $presentsMetrics) {
            NavigationStack {
                List(StandardTestingMetrics.all) { metric in
                    Button {
                        viewModel.addStandardMetric(metric)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(metric.name)
                            Text("\(metric.category.title) • \(metric.unit)")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                    .disabled(
                        viewModel.metrics.contains { $0.key == metric.key }
                    )
                }
                .navigationTitle("Metric Library")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { presentsMetrics = false }
                    }
                }
            }
        }
    }
}
