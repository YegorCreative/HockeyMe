# Forge Fitness Monitoring

## Client signals

`LoggingService` uses Apple unified logging with fixed event names and private
metadata. `DiagnosticsService` subscribes to MetricKit for crash and metric
payload availability. `PerformanceMonitor` records operation duration, while
`NetworkDiagnostics` records status class, connectivity, and duration without
URLs, headers, bodies, tokens, names, notes, or email addresses.

Analytics is disabled through `AnalyticsService.setEnabled(false)`. Events are
operational and do not include personal content or stable advertising
identifiers. The privacy manifest declares no tracking or collected data.

## Release health indicators

- Crash-free sessions and MetricKit crash diagnostics
- App launch, hang, memory, disk, and CPU regressions
- Authentication success/failure ratio
- Workout start/completion and offline synchronization failures
- Testing result save failures
- Invitation delivery failure and rate-limit ratio
- Supabase API latency, Postgres latency, error rates, storage, and connections

## Alert severity

- Critical: cross-tenant access, credential exposure, data loss, widespread
  authentication failure, or sustained crash loop.
- High: invitation outage, workout writes failing, migrations blocked, or major
  performance regression.
- Medium: elevated errors, partial provider degradation, or sync backlog.
- Low: isolated recoverable error or non-urgent operational anomaly.

Alert payloads must contain environment, build, event name, aggregate count,
status class, and duration only. Never send sensitive request context.
