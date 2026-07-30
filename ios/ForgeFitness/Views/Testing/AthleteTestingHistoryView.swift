import Charts
import SwiftUI

struct AthleteTestingHistoryView: View {
    let sessions: [TestingSession]

    private var analytics: [TestingMetricAnalytics] {
        let metrics = Dictionary(
            uniqueKeysWithValues: sessions.flatMap(\.metrics).map {
                ($0.id, $0)
            }
        )
        let results = sessions.flatMap(\.results)
        let start = Calendar.current.date(
            byAdding: .year,
            value: -1,
            to: Date()
        ) ?? .distantPast
        return metrics.values.compactMap {
            PerformanceAnalytics.analytics(
                metric: $0,
                results: results,
                seasonStart: start
            )
        }.sorted { $0.metricName < $1.metricName }
    }

    var body: some View {
        List {
            if analytics.isEmpty {
                ContentUnavailableView(
                    "No Testing History",
                    systemImage: "chart.xyaxis.line",
                    description: Text(
                        "Completed testing results will appear here."
                    )
                )
            } else {
                ForEach(analytics) { item in
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        HStack {
                            Text(item.metricName)
                                .font(AppTypography.headline)
                            Spacer()
                            Text(
                                "\(item.latest.formatted()) \(item.unit)"
                            )
                            .font(AppTypography.body)
                        }

                        if let improvement = item.improvementPercent {
                            Text(
                                "\(improvement.formatted(.number.precision(.fractionLength(1))))% improvement"
                            )
                            .font(AppTypography.caption)
                            .foregroundStyle(
                                improvement >= 0
                                    ? AppColors.success
                                    : AppColors.warning
                            )
                        }

                        Chart(item.history) {
                            LineMark(
                                x: .value("Date", $0.date),
                                y: .value("Result", $0.value)
                            )
                            PointMark(
                                x: .value("Date", $0.date),
                                y: .value("Result", $0.value)
                            )
                        }
                        .frame(height: 120)
                        .accessibilityLabel(
                            "\(item.metricName) performance history"
                        )

                        Text(
                            "Season best \(item.seasonBest.formatted()) • Career best \(item.careerBest.formatted())"
                        )
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                    }
                    .padding(.vertical, AppSpacing.sm)
                    .accessibilityElement(children: .contain)
                }
            }
        }
        .navigationTitle("Testing History")
    }
}
