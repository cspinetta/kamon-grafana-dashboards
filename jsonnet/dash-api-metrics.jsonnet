local grafana = import 'grafonnet-lib/grafonnet/grafana.libsonnet';
local dashboard = grafana.dashboard;
local row = grafana.row;
local template = grafana.template;
local graphPanel = grafana.graphPanel;
local heatmapPanel = grafana.heatmapPanel;
local singlestat = grafana.singlestat;
local gauge = grafana.gauge;
local prometheus = grafana.prometheus;
local kamon_grafana = import 'kamon_grafana.libsonnet';
local version = import 'version.libsonnet';
local colors = import 'colors.libsonnet';

grafana.dashboard.new(
  'API dashboard',
  refresh='1m',
  time_from='now-1h',
  description='API dashboard for apps instrumented with Kamon 2.x',
  tags=['kamon', 'prometheus', 'web-server'],
)
.addRequired(
  id='grafana',
  type='grafana',
  name='Grafana',
  version='7.0.0',
)
.addRequired(
  id='prometheus',
  type='datasource',
  name='Prometheus',
  version='1.0.0',
)
.addTemplate(
  kamon_grafana.template.prometheus_datasource()
)
.addTemplate(
  template.custom(
    name='app_filter',
    label='App filter',
    query='my-app.*|another-app.*',
    current='my-app.*|another-app.*',
    hide='2',
  )
)
.addTemplate(
  kamon_grafana.template.job(
    query='label_values(up{job=~"$app_filter"}, cluster)',
  ),
)
.addTemplate(
  kamon_grafana.template.instance(),
)
.addTemplate(
  kamon_grafana.template.interval()
)
.addTemplate(
  grafana.template.new(
    name='client_operation',
    datasource='$PROMETHEUS_DS',
    query='label_values(span_processing_time_seconds_count{job=~"$job", span_kind="client"},operation)',
    current='all',
    label='',
    refresh='load',
    hide='2',
    sort=1,
    includeAll=true,
  )
)
.addPanel(
  row.new(
    title='API overview',
  ) + {
    collapsed: false,
  },
  gridPos={ h: 1, w: 24, x: 0, y: 0 },
)
.addPanel(
  kamon_grafana.graph_panel.new(
    title='Throughput (avg. $interval)',
    description=
    'The average requests rate in the last $interval across all selected instances stacked by status',
    format='rpm',
    lines=false,
    bars=true,
    stack=true,
  )
  .addTarget(
    prometheus.target(
      'sum(increase(http_server_requests_total{instance=~"$instance", http_status_code="2xx"}[$interval]))',
      legendFormat='2xx rpm',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'sum(increase(http_server_requests_total{instance=~"$instance", http_status_code="3xx"}[$interval]))',
      legendFormat='3xx rpm',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'sum(increase(http_server_requests_total{instance=~"$instance", http_status_code="4xx"}[$interval]))',
      legendFormat='4xx rpm',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'sum(increase(http_server_requests_total{instance=~"$instance", http_status_code="5xx"}[$interval]))',
      legendFormat='5xx rpm',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addSeriesOverride({
    alias: '2xx rpm',
    color: colors.dark_green,
  })
  .addSeriesOverride({
    alias: '3xx rpm',
    color: colors.dark_blue,
  })
  .addSeriesOverride({
    alias: '4xx rpm',
    color: colors.dark_yellow,
  })
  .addSeriesOverride({
    alias: '5xx rpm',
    color: colors.dark_red,
  }),
  gridPos={ h: 6, w: 24, x: 0, y: 1 },
)
.addPanel(
  kamon_grafana.graph_panel.new(
    title='Latency: only 2xx status response',
    description=
    'Latency of requests with 2xx status response over $interval',
    format='s',
    lines=true,
    bars=false,
  )
  .addTarget(
    prometheus.target(
      'histogram_quantile(0.999, sum(rate(span_processing_time_seconds_bucket{instance=~"$instance", span_kind="server", http_status_code=~"2.*"}[$interval])) by (le))',
      legendFormat='p99.9',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'histogram_quantile(0.99, sum(rate(span_processing_time_seconds_bucket{instance=~"$instance", span_kind="server", http_status_code=~"2.*"}[$interval])) by (le))',
      legendFormat='p99',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'histogram_quantile(0.90, sum(rate(span_processing_time_seconds_bucket{instance=~"$instance", span_kind="server", http_status_code=~"2.*"}[$interval])) by (le))',
      legendFormat='p90',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'histogram_quantile(0.50, sum(rate(span_processing_time_seconds_bucket{instance=~"$instance", span_kind="server", http_status_code=~"2.*"}[$interval])) by (le))',
      legendFormat='p50',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addSeriesOverride({
    alias: 'p99.9',
    color: colors.dark_green,
  })
  .addSeriesOverride({
    alias: 'p99',
    color: colors.semi_dark_green,
  })
  .addSeriesOverride({
    alias: 'p90',
    color: colors.light_green,
  })
  .addSeriesOverride({
    alias: 'p50',
    color: colors.super_light_green,
  }),
  gridPos={ h: 6, w: 24, x: 0, y: 7 },
)
.addPanel(
  kamon_grafana.graph_panel.new(
    title="Approximated Uptime: 'requests with 2xx status response' / 'requests with 2xx or 5xx status response'",
    description=
    "Given:\n  * Success requests: status 2xx\n  * Valid requests: status 2xx or status 5xx\n\nThe uptime could be estimated by 'success requests' / 'valid requests'.\n\nThis is just an approximation because it doesn't take in account a lot of corner cases. For a more accurate metric it should be measured from outside the app.\n",
    format='percentunit',
    min=0,
    max=1,
    bars=true,
    lines=false,
    percentage=true,
  )
  .addTarget(
    prometheus.target(
      'sum(rate(http_server_requests_total{instance=~"$instance", http_status_code="2xx"}[$interval]))\n /\n sum(rate(http_server_requests_total{instance=~"$instance", http_status_code=~"2xx|5xx"}[$interval]))',
      legendFormat='uptime',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addSeriesOverride({
    alias: 'uptime',
    color: colors.dark_green,
  }),
  gridPos={ h: 6, w: 16, x: 0, y: 13 },
)
.addPanel(
  kamon_grafana.graph_panel.new(
    title='2xx | 4xx | 3xx | 5xx % (avg. $interval)',
    description='Relative frequency distribution of response 2xx, 3xx, 4xx and 5xx over $interval',
    format='percentunit',
    min=0,
    max=100,
    bars=true,
    lines=false,
    stack=true,
    percentage=true,
  )
  .addTarget(
    prometheus.target(
      'sum(rate(http_server_requests_total{instance=~"$instance", http_status_code="5xx"}[$interval]))\n/\nsum(rate(http_server_requests_total{instance=~"$instance"}[$interval]))',
      legendFormat='Failures (5xx)',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'sum(rate(http_server_requests_total{instance=~"$instance", http_status_code="4xx"}[$interval]))\n/\nsum(rate(http_server_requests_total{instance=~"$instance"}[$interval]))',
      legendFormat='Client errors (4xx)',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'sum(rate(http_server_requests_total{instance=~"$instance", http_status_code="3xx"}[$interval]))\n/\nsum(rate(http_server_requests_total{instance=~"$instance"}[$interval]))',
      legendFormat='Redirects (3xx)',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'sum(rate(http_server_requests_total{instance=~"$instance", http_status_code="2xx"}[$interval]))\n/\nsum(rate(http_server_requests_total{instance=~"$instance"}[$interval]))',
      legendFormat='Success (2xx)',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addSeriesOverride({
    alias: 'Failures (5xx)',
    color: colors.dark_red,
  })
  .addSeriesOverride({
    alias: 'Client errors (4xx)',
    color: colors.dark_yellow,
  })
  .addSeriesOverride({
    alias: 'Redirects (3xx)',
    color: colors.dark_blue,
  })
  .addSeriesOverride({
    alias: 'Success (2xx)',
    color: colors.dark_green,
  }),
  gridPos={ h: 6, w: 8, x: 16, y: 13 },
)
.addPanel(
  kamon_grafana.graph_panel.new(
    title='Latency: only 3xx status response',
    description=
    'Latency of requests with 3xx status response over $interval',
    format='s',
    lines=true,
    bars=false,
  )
  .addTarget(
    prometheus.target(
      'histogram_quantile(0.999, sum(rate(span_processing_time_seconds_bucket{instance=~"$instance", span_kind="server", http_status_code=~"3.*"}[$interval])) by (le))',
      legendFormat='p99.9',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'histogram_quantile(0.99, sum(rate(span_processing_time_seconds_bucket{instance=~"$instance", span_kind="server", http_status_code=~"3.*"}[$interval])) by (le))',
      legendFormat='p99',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'histogram_quantile(0.90, sum(rate(span_processing_time_seconds_bucket{instance=~"$instance", span_kind="server", http_status_code=~"3.*"}[$interval])) by (le))',
      legendFormat='p90',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'histogram_quantile(0.50, sum(rate(span_processing_time_seconds_bucket{instance=~"$instance", span_kind="server", http_status_code=~"3.*"}[$interval])) by (le))',
      legendFormat='p50',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addSeriesOverride({
    alias: 'p99.9',
    color: colors.dark_blue,
  })
  .addSeriesOverride({
    alias: 'p99',
    color: colors.semi_dark_blue,
  })
  .addSeriesOverride({
    alias: 'p90',
    color: colors.light_blue,
  })
  .addSeriesOverride({
    alias: 'p50',
    color: colors.super_light_blue,
  }),
  gridPos={ h: 6, w: 8, x: 0, y: 19 },
)
.addPanel(
  kamon_grafana.graph_panel.new(
    title='Latency: only 4xx status response',
    description=
    'Latency of requests with 4xx status response over $interval',
    format='s',
    lines=true,
    bars=false,
  )
  .addTarget(
    prometheus.target(
      'histogram_quantile(0.999, sum(rate(span_processing_time_seconds_bucket{instance=~"$instance", span_kind="server", http_status_code=~"4.*"}[$interval])) by (le))',
      legendFormat='p99.9',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'histogram_quantile(0.99, sum(rate(span_processing_time_seconds_bucket{instance=~"$instance", span_kind="server", http_status_code=~"4.*"}[$interval])) by (le))',
      legendFormat='p99',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'histogram_quantile(0.90, sum(rate(span_processing_time_seconds_bucket{instance=~"$instance", span_kind="server", http_status_code=~"4.*"}[$interval])) by (le))',
      legendFormat='p90',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'histogram_quantile(0.50, sum(rate(span_processing_time_seconds_bucket{instance=~"$instance", span_kind="server", http_status_code=~"4.*"}[$interval])) by (le))',
      legendFormat='p50',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addSeriesOverride({
    alias: 'p99.9',
    color: colors.dark_yellow,
  })
  .addSeriesOverride({
    alias: 'p99',
    color: colors.semi_dark_yellow,
  })
  .addSeriesOverride({
    alias: 'p90',
    color: colors.light_yellow,
  })
  .addSeriesOverride({
    alias: 'p50',
    color: colors.super_light_yellow,
  }),
  gridPos={ h: 6, w: 8, x: 8, y: 19 },
)
.addPanel(
  kamon_grafana.graph_panel.new(
    title='Latency: only 5xx status response',
    description=
    'Latency of requests with 5xx status response over $interval',
    format='s',
    lines=true,
    bars=false,
  )
  .addTarget(
    prometheus.target(
      'histogram_quantile(0.999, sum(rate(span_processing_time_seconds_bucket{instance=~"$instance", span_kind="server", http_status_code=~"5.*"}[$interval])) by (le))',
      legendFormat='p99.9',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'histogram_quantile(0.99, sum(rate(span_processing_time_seconds_bucket{instance=~"$instance", span_kind="server", http_status_code=~"5.*"}[$interval])) by (le))',
      legendFormat='p99',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'histogram_quantile(0.90, sum(rate(span_processing_time_seconds_bucket{instance=~"$instance", span_kind="server", http_status_code=~"5.*"}[$interval])) by (le))',
      legendFormat='p90',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'histogram_quantile(0.50, sum(rate(span_processing_time_seconds_bucket{instance=~"$instance", span_kind="server", http_status_code=~"5.*"}[$interval])) by (le))',
      legendFormat='p50',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addSeriesOverride({
    alias: 'p99.9',
    color: colors.dark_red,
  })
  .addSeriesOverride({
    alias: 'p99',
    color: colors.semi_dark_red,
  })
  .addSeriesOverride({
    alias: 'p90',
    color: colors.light_red,
  })
  .addSeriesOverride({
    alias: 'p50',
    color: colors.super_light_red,
  }),
  gridPos={ h: 6, w: 8, x: 16, y: 19 },
)
.addPanel(
  row.new(
    title='Clients metrics | $client_operation',
    repeat='client_operation',
  ) + {
    collapsed: false,
  },
  gridPos={ h: 1, w: 24, x: 0, y: 25 },
)
.addPanel(
  kamon_grafana.graph_panel.new(
    title='Throughput of outgoing requests over $interval',
    description=
    'The average outgoing requests rate in the last $interval across all selected instances',
    format='rpm',
    lines=false,
    bars=true,
    stack=true,
    legend_rightSide=true,
  )
  .addTarget(
    prometheus.target(
      'sum(increase(span_processing_time_seconds_count{instance=~"$instance", error="false", span_kind="client", operation="$client_operation"}[$interval]))',
      legendFormat='{{operation}} with no error',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'sum(increase(span_processing_time_seconds_count{instance=~"$instance", error="true", span_kind="client", operation="$client_operation"}[$interval]))',
      legendFormat='{{operation}} with error',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addSeriesOverride({
    alias: '/.*with no error/',
    color: colors.dark_green,
  })
  .addSeriesOverride({
    alias: '/.*with error/',
    color: colors.dark_red,
  }),
  gridPos={ h: 6, w: 24, x: 0, y: 26 },
)
.addPanel(
  kamon_grafana.graph_panel.new(
    title='Latency of outgoing requests over $interval',
    description=
    'Latency of outgoing requests in the last $interval across all selected instances',
    format='s',
    lines=true,
    bars=false,
    legend_rightSide=true,
  )
  .addTarget(
    prometheus.target(
      'histogram_quantile(0.99, sum(rate(span_processing_time_seconds_bucket{instance=~"$instance", span_kind="client", error="false", operation="$client_operation"}[$interval])) by (le))',
      legendFormat='p99 {{operation}} with no error',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'histogram_quantile(0.99, sum(rate(span_processing_time_seconds_bucket{instance=~"$instance", span_kind="client", error="true", operation="$client_operation"}[$interval])) by (le))',
      legendFormat='p99 {{operation}} with error',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'histogram_quantile(0.90, sum(rate(span_processing_time_seconds_bucket{instance=~"$instance", span_kind="client", error="false", operation="$client_operation"}[$interval])) by (le))',
      legendFormat='p90 {{operation}} with no error',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'histogram_quantile(0.90, sum(rate(span_processing_time_seconds_bucket{instance=~"$instance", span_kind="client", error="true", operation="$client_operation"}[$interval])) by (le))',
      legendFormat='p90 {{operation}} with error',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'histogram_quantile(0.50, sum(rate(span_processing_time_seconds_bucket{instance=~"$instance", span_kind="client", error="false", operation="$client_operation"}[$interval])) by (le))',
      legendFormat='p50 {{operation}} with no error',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'histogram_quantile(0.50, sum(rate(span_processing_time_seconds_bucket{instance=~"$instance", span_kind="client", error="true", operation="$client_operation"}[$interval])) by (le))',
      legendFormat='p50 {{operation}} with error',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addSeriesOverride({
    alias: '/p99.*with no error/',
    color: colors.dark_green,
  })
  .addSeriesOverride({
    alias: '/p90.*with no error/',
    color: colors.semi_dark_green,
  })
  .addSeriesOverride({
    alias: '/p50.*with no error/',
    color: colors.light_green,
  })
  .addSeriesOverride({
    alias: '/p99.*with error/',
    color: colors.dark_red,
  })
  .addSeriesOverride({
    alias: '/p90.*with error/',
    color: colors.semi_dark_red,
  })
  .addSeriesOverride({
    alias: '/p50.*with error/',
    color: colors.light_red,
  }),
  gridPos={ h: 6, w: 24, x: 0, y: 32 },
) + version
