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

local load_average_description = 'Tracks the system load average in 1m / 5m / 15m.\n\nThey indicate the average number of tasks (processes) wanting to run in the last 1m / 5m / 15m.\n\nOn Linux systems, these numbers is approximated and include processes wanting to run on the CPUs, as well as processes blocked in uninterruptible I/O (usually disk I/O).\nThis gives a high-level idea of resource load (or demand).\n\nThe three numbers give some idea of how load is changing over time.\n\nExcellent post on the subject: http://www.brendangregg.com/blog/2017-08-08/linux-load-averages.html';

grafana.dashboard.new(
  'System metrics dashboard',
  refresh='1m',
  time_from='now-1h',
  description='System metrics dashboard for apps instrumented with Kamon 2.x',
  tags=['kamon', 'prometheus', 'system-metrics'],
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
  kamon_grafana.template.job(
    query='label_values({component="host"}, cluster)',
  ),
)
.addTemplate(
  kamon_grafana.template.instance(
    includeAll=false,
    multi=false,
  ),
)
.addTemplate(
  kamon_grafana.template.interval()
)
.addPanel(
  row.new(
    title='Overview',
  ) + {
    collapsed: false,
  },
  gridPos={ h: 1, w: 24, x: 0, y: 0 },
)
.addPanel(
  kamon_grafana.bargauge.new(
    title='System resources overview',
    description='System resources usage',
    datasource='$PROMETHEUS_DS',
    options_orientation='horizontal',
    options_displayMode='lcd',
    options_showUnfilled=true,
  )
  .add_field_config(
    field_config=kamon_grafana.barstats_field_config(
      unit='percentunit',
      min=0,
      max=1,
      decimals=2,
      thresholds=kamon_grafana.stats_thresholds.new(
        'percentage',
        [
          { color: colors.dark_yellow, value: null },
          { color: colors.dark_green, value: 50 },
          { color: colors.dark_red, value: 80 },
        ],
      ),
    ).addOverride(
      matcher_options='CPU usage',
      properties=[
        {
          id: 'unit',
          value: 'percent',
        },
        {
          id: 'min',
          value: 0,
        },
        {
          id: 'max',
          value: 100,
        },
      ]
    )
  )
  .addTarget(
    prometheus.target(
      'sum(rate(host_cpu_usage_sum{instance=~"$instance", mode="combined"}[$interval]))\n/\nsum(rate(host_cpu_usage_count{instance=~"$instance", mode="combined"}[$interval]))',
      legendFormat='CPU usage',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'host_memory_used_bytes{instance=~"$instance"}\n/\nhost_memory_total_bytes{instance=~"$instance"}',
      legendFormat='Memory utilization',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      '(host_swap_memory_used_bytes{instance=~"$instance"}\n/\nhost_swap_memory_total_bytes{instance=~"$instance"}) OR on() vector(0)',
      legendFormat='SWAP utilization',
      datasource='$PROMETHEUS_DS',
      instant=true,
    )
  ),
  gridPos={ h: 3, w: 6, x: 0, y: 1 },
)
.addPanel(
  kamon_grafana.cpu_stats_panel.new(
    title='CPU %usr',
    description='Tracks the current time the CPU is busy on user mode.',
    query_expression=
    'sum(rate(host_cpu_usage_sum{instance=~"$instance", mode="user"}[$interval]))\n/\nsum(rate(host_cpu_usage_count{instance=~"$instance", mode="user"}[$interval]))',
  ),
  gridPos={ h: 3, w: 2, x: 6, y: 1 },
)
.addPanel(
  kamon_grafana.cpu_stats_panel.new(
    title='CPU %system',
    description='Tracks the current time the CPU is busy on system mode.',
    query_expression=
    'sum(rate(host_cpu_usage_sum{instance=~"$instance", mode="system"}[$interval]))\n/\nsum(rate(host_cpu_usage_count{instance=~"$instance", mode="system"}[$interval]))',
  ),
  gridPos={ h: 3, w: 2, x: 8, y: 1 },
)
.addPanel(
  kamon_grafana.cpu_stats_panel.new(
    title='CPU %wait',
    description='Tracks the current time the CPU is stuck waiting for IO.\n\nIf this value is high, the disk might be the bottleneck.',
    query_expression=
    'sum(rate(host_cpu_usage_sum{instance=~"$instance", mode="wait"}[$interval]))\n/\nsum(rate(host_cpu_usage_count{instance=~"$instance", mode="wait"}[$interval]))',
  ),
  gridPos={ h: 3, w: 2, x: 10, y: 1 },
)
.addPanel(
  kamon_grafana.bargauge.new(
    title='Network usage',
    description='Traks network usage',
    datasource='$PROMETHEUS_DS',
    options_orientation='horizontal',
    options_displayMode='lcd',
    options_showUnfilled=true,
  )
  .add_field_config(
    field_config=kamon_grafana.barstats_field_config(
      unit='Bps',
      min=0,
      decimals=2,
    ).addOverride(
      matcher_options='read',
      properties=[
        {
          id: 'thresholds',
          value: {
            mode: 'percentage',
            steps: [
              {
                color: colors.dark_green,
                value: null,
              },
            ],
          },
        },
      ]
    ).addOverride(
      matcher_options='write',
      properties=[
        {
          id: 'thresholds',
          value: {
            mode: 'percentage',
            steps: [
              {
                color: colors.dark_red,
                value: null,
              },
            ],
          },
        },
      ]
    )
  )
  .addTarget(
    prometheus.target(
      'rate(host_network_data_read_bytes_total{instance=~"$instance"}[$interval])',
      legendFormat='read',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'rate(host_network_data_write_bytes_total{instance=~"$instance"}[$interval])',
      legendFormat='write',
      datasource='$PROMETHEUS_DS',
    )
  ),
  gridPos={ h: 3, w: 7, x: 12, y: 1 },
)
.addPanel(
  kamon_grafana.bargauge.new(
    title='Retransmits',
    description='Tracks ratio for failed network packets',
    datasource='$PROMETHEUS_DS',
    options_orientation='horizontal',
    options_displayMode='gradient',
    options_showUnfilled=true,
  )
  .add_field_config(
    field_config=kamon_grafana.barstats_field_config(
      unit='percentunit',
      min=0,
      max=1,
    ).addOverride(
      matcher_options='read',
      properties=[
        {
          id: 'thresholds',
          value: {
            mode: 'percentage',
            steps: [
              {
                color: colors.dark_green,
                value: null,
              },
            ],
          },
        },
      ]
    ).addOverride(
      matcher_options='write',
      properties=[
        {
          id: 'thresholds',
          value: {
            mode: 'percentage',
            steps: [
              {
                color: colors.dark_red,
                value: null,
              },
            ],
          },
        },
      ]
    )
  )
  .addTarget(
    prometheus.target(
      'sum(host_network_packets_read_failed_total{instance=~"$instance"})\n/\nsum(host_network_packets_read_total_total{instance=~"$instance"})',
      legendFormat='read',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'sum(host_network_packets_write_failed_total{instance=~"$instance"})\n/\nsum(host_network_packets_write_total_total{instance=~"$instance"})',
      legendFormat='write',
      datasource='$PROMETHEUS_DS',
    )
  ),
  gridPos={ h: 3, w: 2, x: 19, y: 1 },
)
.addPanel(
  kamon_grafana.stat.new(
    'Top 2 Disk usage',
    description='Tracks usage of space on Disk',
    datasource='$PROMETHEUS_DS',
    options=kamon_grafana.stats_options.new(
      orientation='horizontal'
    ).add_reduce_options(),
  )
  .addTarget(
    prometheus.target(
      'topk(2, (sum by(mount)(host_storage_mount_space_used_bytes{instance=~"$instance"})\n/\nsum by(mount)(host_storage_mount_space_total_bytes{instance=~"$instance"})))',
      datasource='$PROMETHEUS_DS',
      legendFormat='{{mount}}',
      instant=true,
    )
  )
  .add_field_config(
    unit='percentunit',
    thresholds=kamon_grafana.stats_thresholds.new(
      mode='absolute',
      steps=[
        { color: colors.dark_green, value: null },
        { color: colors.dark_yellow, value: 0.5 },
        { color: colors.dark_red, value: 0.8 },
      ],
    ),
  ),
  gridPos={ h: 6, w: 3, x: 21, y: 1 },
)
.addPanel(
  kamon_grafana.bargauge.new(
    title='System load average',
    description=load_average_description,
    datasource='$PROMETHEUS_DS',
    options_orientation='horizontal',
    options_displayMode='lcd',
    options_showUnfilled=true,
  )
  .add_field_config(
    field_config=kamon_grafana.barstats_field_config(
      unit='short',
      min=0,
      decimals=2,
      thresholds=kamon_grafana.stats_thresholds.new(
        mode='absolute',
        steps=[
          { color: colors.semi_dark_blue, value: null },
        ],
      ),
    )
  )
  .addTarget(
    prometheus.target(
      'host_load_average{instance=~"$instance", period="1m"}',
      legendFormat='Avg. 1m',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'host_load_average{instance=~"$instance", period="5m"}',
      legendFormat='Avg. 5m',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'host_load_average{instance=~"$instance", period="15m"}',
      legendFormat='Avg. 15m',
      datasource='$PROMETHEUS_DS',
    )
  ),
  gridPos={ h: 3, w: 6, x: 0, y: 4 },
)
.addPanel(
  kamon_grafana.cpu_stats_panel.new(
    title='Proc %usr',
    description='Tracks the current time the CPU is busy by the process in user mode.',
    query_expression=
    'sum(rate(process_cpu_usage_sum{instance=~"$instance", mode="user"}[$interval]))\n/\nsum(rate(process_cpu_usage_count{instance=~"$instance", mode="user"}[$interval]))',
  ),
  gridPos={ h: 3, w: 2, x: 6, y: 4 },
)
.addPanel(
  kamon_grafana.cpu_stats_panel.new(
    title='Proc %system',
    description='Tracks the current time the CPU is busy by the process in kernel mode.',
    query_expression=
    'sum(rate(process_cpu_usage_sum{instance=~"$instance", mode="system"}[$interval]))\n/\nsum(rate(process_cpu_usage_count{instance=~"$instance", mode="system"}[$interval]))',
  ),
  gridPos={ h: 3, w: 2, x: 8, y: 4 },
)
.addPanel(
  kamon_grafana.cpu_stats_panel.new(
    title='CPU %steal',
    description='Tracks the current time the CPU is stolen by some process outside the VM.\n\nIf this value is high, it could be caused either by the supervisor is very busy, by a noisy neighbor or by some limitation on the quota assigned by the virtualization service.',
    query_expression=
    'sum(rate(host_cpu_usage_sum{instance=~"$instance", mode="stolen"}[$interval]))\n/\nsum(rate(host_cpu_usage_count{instance=~"$instance", mode="stolen"}[$interval]))',
  ),
  gridPos={ h: 3, w: 2, x: 10, y: 4 },
)
.addPanel(
  kamon_grafana.bargauge.new(
    title='Disk usage',
    description='Traks the usage of disk space',
    datasource='$PROMETHEUS_DS',
    options_orientation='horizontal',
    options_displayMode='lcd',
    options_showUnfilled=true,
  )
  .add_field_config(
    field_config=kamon_grafana.barstats_field_config(
      unit='Bps',
      min=0,
      decimals=2,
    ).addOverride(
      matcher_options='read',
      properties=[
        {
          id: 'thresholds',
          value: {
            mode: 'percentage',
            steps: [
              {
                color: colors.dark_green,
                value: null,
              },
            ],
          },
        },
      ]
    ).addOverride(
      matcher_options='write',
      properties=[
        {
          id: 'thresholds',
          value: {
            mode: 'percentage',
            steps: [
              {
                color: colors.dark_red,
                value: null,
              },
            ],
          },
        },
      ]
    )
  )
  .addTarget(
    prometheus.target(
      'rate(host_storage_device_data_read_bytes_total{instance=~"$instance"}[$interval])',
      legendFormat='read',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'rate(host_storage_device_data_write_bytes_total{instance=~"$instance"}[$interval])',
      legendFormat='write',
      datasource='$PROMETHEUS_DS',
    )
  ),
  gridPos={ h: 3, w: 7, x: 12, y: 4 },
)
.addPanel(
  kamon_grafana.stat.new(
    '# FDs',
    description='Tracks the number of file descriptors in used by the process.',
    datasource='-- Mixed --',
    options=kamon_grafana.stats_options.new().add_reduce_options(),
  )
  .addTarget(
    prometheus.target(
      'process_ulimit_file_descriptors_used{instance=~"$instance"}',
      datasource='$PROMETHEUS_DS',
    )
  )
  .add_field_config(
    unit='short',
    thresholds=kamon_grafana.stats_thresholds.new(
      mode='absolute',
      steps=[
        { color: 'dark-blue', value: null },
      ],
    ),
  ),
  gridPos={ h: 3, w: 2, x: 19, y: 4 },
)
.addPanel(
  row.new(
    title='Load / Health',
  ),
  gridPos={ h: 1, w: 24, x: 0, y: 11 },
)
.addPanel(
  kamon_grafana.graph_panel.new(
    title='System load average in 1m / 5m / 15m',
    description=load_average_description,
    format='short',
    legend_sort='current',
  )
  .addTarget(
    prometheus.target(
      'host_load_average{instance=~"$instance", period="1m"}',
      legendFormat='Avg 1m',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'host_load_average{instance=~"$instance", period="5m"}',
      legendFormat='Avg 5m',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'host_load_average{instance=~"$instance", period="15m"}',
      legendFormat='Avg 15m',
      datasource='$PROMETHEUS_DS',
    )
  ),
  gridPos={ h: 6, w: 24, x: 0, y: 12 },
)
.addPanel(
  heatmapPanel.new(
    title='VM Hiccups (or idle jitters) in nanoseconds (p90)',
    description=
    'Tracks the hiccups detected in the VM (also known as idle jitters) measured in nanoseconds. The 90ht percentile is presented.\n\nFor more info: https://www.azul.com/jhiccup/',
    color_cardColor='#b4ff00',
    color_colorScale='sqrt',
    color_colorScheme='interpolateBlues',
    color_exponent=0.5,
    color_max=null,
    color_min=null,
    color_mode='spectrum',
    dataFormat='timeseries',
    legend_show=true,
    yAxis_format='ns',
  )
  .addTarget(
    prometheus.target(
      'histogram_quantile(0.9, sum(rate(process_hiccups_seconds_bucket{instance=~"$instance"}[$interval])) by (le, instance))',
      legendFormat='p90',
      datasource='$PROMETHEUS_DS',
    )
  ),
  gridPos={ h: 6, w: 24, x: 0, y: 18 },
)
.addPanel(
  row.new(
    title='CPU',
  ),
  gridPos={ h: 1, w: 24, x: 0, y: 24 },
)
.addPanel(
  kamon_grafana.graph_panel.new(
    title='VM CPU usage',
    description='Tracks the usage of CPU by the VM in the different typical views.',
    format='percent',
  )
  .addTarget(
    prometheus.target(
      'rate(host_cpu_usage_sum{instance=~"$instance", mode="user"}[$interval])\n/\nrate(host_cpu_usage_count{instance=~"$instance", mode="user"}[$interval])',
      legendFormat='User mode',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'rate(host_cpu_usage_sum{instance=~"$instance", mode="system"}[$interval])\n/\nrate(host_cpu_usage_count{instance=~"$instance", mode="system"}[$interval])',
      legendFormat='Kernel mode',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'rate(host_cpu_usage_sum{instance=~"$instance", mode="wait"}[$interval])\n/\nrate(host_cpu_usage_count{instance=~"$instance", mode="wait"}[$interval])',
      legendFormat='IO wait',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'rate(host_cpu_usage_sum{instance=~"$instance", mode="stolen"}[$interval])\n/\nrate(host_cpu_usage_count{instance=~"$instance", mode="stolen"}[$interval])',
      legendFormat='Stolen',
      datasource='$PROMETHEUS_DS',
    )
  ),
  gridPos={ h: 6, w: 24, x: 0, y: 25 },
)
.addPanel(
  kamon_grafana.graph_panel.new(
    title='Process CPU usage',
    description='Tracks the usage of CPU by the app in the different typical views.',
    format='percent',
  )
  .addTarget(
    prometheus.target(
      'rate(process_cpu_usage_sum{instance=~"$instance", mode="user"}[$interval])\n/\nrate(process_cpu_usage_count{instance=~"$instance", mode="user"}[$interval])',
      legendFormat='User mode',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'rate(process_cpu_usage_sum{instance=~"$instance", mode="system"}[$interval])\n/\nrate(process_cpu_usage_count{instance=~"$instance", mode="system"}[$interval])',
      legendFormat='Kernel mode',
      datasource='$PROMETHEUS_DS',
    )
  ),
  gridPos={ h: 6, w: 24, x: 0, y: 31 },
)
.addPanel(
  row.new(
    title='Memory',
  ),
  gridPos={ h: 1, w: 24, x: 0, y: 37 },
)
.addPanel(
  kamon_grafana.graph_panel.new(
    title='Host Memory',
    description='Tracks the total memory available Vs. the amount of used memory.',
    format='decbytes',
  )
  .addTarget(
    prometheus.target(
      'host_memory_used_bytes{instance=~"$instance"}',
      legendFormat='Used Memory',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'host_memory_total_bytes{instance=~"$instance"}',
      legendFormat='Total Memory',
      datasource='$PROMETHEUS_DS',
    )
  ),
  gridPos={ h: 6, w: 24, x: 0, y: 38 },
)
.addPanel(
  kamon_grafana.graph_panel.new(
    title='Swap Memory',
    description='Tracks the total swap memory available Vs. the amount of used swap memory.',
    format='decbytes',
  )
  .addTarget(
    prometheus.target(
      'host_swap_memory_used_bytes{instance=~"$instance"}',
      legendFormat='Used Swap Memory',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'host_swap_memory_total_bytes{instance=~"$instance"}',
      legendFormat='Total Swap Memory',
      datasource='$PROMETHEUS_DS',
    )
  ),
  gridPos={ h: 6, w: 24, x: 0, y: 45 },
)
.addPanel(
  row.new(
    title='Network',
  ),
  gridPos={ h: 1, w: 24, x: 0, y: 52 },
)
.addPanel(
  kamon_grafana.graph_panel.new(
    title='Read / Write bandwidth',
    description='Tracks incoming and outgoing data through the network interfaces.',
    format='Bps',
  )
  .addTarget(
    prometheus.target(
      'rate(host_network_data_read_bytes_total{instance=~"$instance"}[$interval])',
      legendFormat='read',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'rate(host_network_data_write_bytes_total{instance=~"$instance"}[$interval]) * -1',
      legendFormat='write',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addSeriesOverride({
    alias: 'read',
    color: 'rgba(55, 135, 45, 1)',
  })
  .addSeriesOverride({
    alias: 'write',
    color: 'rgba(196, 22, 42, 1)',
  }),
  gridPos={ h: 6, w: 24, x: 0, y: 53 },
)
.addPanel(
  kamon_grafana.graph_panel.new(
    title='Failed Read / Write packets',
    description='Tracks incoming and outgoing failed packets on all network interfaces.',
    format='Bps',
  )
  .addTarget(
    prometheus.target(
      'rate(host_network_packets_read_failed_total{instance=~"$instance"}[$interval])',
      legendFormat='read',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'rate(host_network_packets_write_failed_total{instance=~"$instance"}[$interval]) * -1',
      legendFormat='write',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addSeriesOverride({
    alias: 'read',
    color: 'rgba(55, 135, 45, 1)',
  })
  .addSeriesOverride({
    alias: 'write',
    color: 'rgba(196, 22, 42, 1)',
  }),
  gridPos={ h: 6, w: 24, x: 0, y: 59 },
)
.addPanel(
  row.new(
    title='Disk',
  ),
  gridPos={ h: 1, w: 24, x: 0, y: 65 },
)
.addPanel(
  kamon_grafana.graph_panel.new(
    title='Disk usage',
    description='Tracks usage of disk.',
    format='percentunit',
  )
  .addTarget(
    prometheus.target(
      'sum by(mount)(host_storage_mount_space_used_bytes{instance=~"$instance"})\n/\nsum by (mount)(host_storage_mount_space_total_bytes{instance=~"$instance"})',
      legendFormat='{{mount}}',
      datasource='$PROMETHEUS_DS',
    )
  ),
  gridPos={ h: 6, w: 24, x: 0, y: 66 },
)
.addPanel(
  kamon_grafana.graph_panel.new(
    title='Data transferred',
    description='Tracks the amount of data transferred to disk device.',
    format='Bps',
  )
  .addTarget(
    prometheus.target(
      'rate(host_storage_device_data_read_bytes_total{instance=~"$instance"}[$interval])',
      legendFormat='read',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'rate(host_storage_device_data_write_bytes_total{instance=~"$instance"}[$interval]) * -1',
      legendFormat='write',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addSeriesOverride({
    alias: 'read',
    color: 'rgba(55, 135, 45, 1)',
  })
  .addSeriesOverride({
    alias: 'write',
    color: 'rgba(196, 22, 42, 1)',
  }),
  gridPos={ h: 6, w: 24, x: 0, y: 72 },
)
.addPanel(
  kamon_grafana.graph_panel.new(
    title='Disk I/O (ops/sec)',
    description='Tracks the number of completed disk I/O operations.',
    format='ops',
  )
  .addTarget(
    prometheus.target(
      'rate(host_storage_device_ops_read_total{instance=~"$instance"}[$interval])',
      legendFormat='read',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'rate(host_storage_device_ops_write_total{instance=~"$instance"}[$interval]) * -1',
      legendFormat='write',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addSeriesOverride({
    alias: 'read',
    color: 'rgba(55, 135, 45, 1)',
  })
  .addSeriesOverride({
    alias: 'write',
    color: 'rgba(196, 22, 42, 1)',
  }),
  gridPos={ h: 6, w: 24, x: 0, y: 78 },
)
.addPanel(
  row.new(
    title='JVM Metrics',
  ),
  gridPos={ h: 1, w: 24, x: 0, y: 84 },
)
.addPanel(
  kamon_grafana.graph_panel.new(
    title='Heap',
    description='Tracks the amount of memory used by the JVM heap.',
    format='decbytes',
  )
  .addTarget(
    prometheus.target(
      'jvm_memory_max_bytes{instance=~"$instance", region="heap"}',
      legendFormat='max',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'jvm_memory_committed_bytes{instance=~"$instance", region="heap"}',
      legendFormat='committed',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'jvm_memory_used_bytes_sum{instance=~"$instance", region="heap"}\n/\njvm_memory_used_bytes_count{instance=~"$instance", region="heap"}',
      legendFormat='used',
      datasource='$PROMETHEUS_DS',
    )
  ),
  gridPos={ h: 6, w: 12, x: 0, y: 85 },
)
.addPanel(
  kamon_grafana.graph_panel.new(
    title='Off-Heap',
    description='Tracks the amount of memory used by the JVM outside the heap.',
    format='decbytes',
  )
  .addTarget(
    prometheus.target(
      'jvm_memory_max_bytes{instance=~"$instance", region="non-heap"}',
      legendFormat='max',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'jvm_memory_committed_bytes{instance=~"$instance", region="non-heap"}',
      legendFormat='committed',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'jvm_memory_used_bytes_sum{instance=~"$instance", region="non-heap"}\n/\njvm_memory_used_bytes_count{instance=~"$instance", region="non-heap"}',
      legendFormat='used',
      datasource='$PROMETHEUS_DS',
    )
  )
  .addTarget(
    prometheus.target(
      'jvm_memory_free_bytes_sum{instance=~"$instance", region="non-heap"}\n/\njvm_memory_free_bytes_count{instance=~"$instance", region="non-heap"}',
      legendFormat='free',
      datasource='$PROMETHEUS_DS',
    )
  ),
  gridPos={ h: 6, w: 12, x: 12, y: 85 },
)
.addPanel(
  kamon_grafana.graph_panel.new(
    title='Garbage Collection',
    description='Tracks the distribution of GC events duration',
    format='s',
    lines=false,
    points=true,
  )
  .addTarget(
    prometheus.target(
      'rate(jvm_gc_seconds_sum{instance=~"$instance"}[$interval])\n/\nrate(jvm_gc_seconds_count{instance =~"$instance"}[$interval])',
      legendFormat='GC count: {{collector}}',
      datasource='$PROMETHEUS_DS',
    )
  ),
  gridPos={ h: 6, w: 24, x: 0, y: 91 },
)
.addPanel(
  row.new(
    title='Executor Metrics',
  ),
  gridPos={ h: 1, w: 24, x: 0, y: 97 },
)
.addPanel(
  kamon_grafana.graph_panel.new(
    title='Number Of Threads',
    description='Tracks the number of threads in use.',
    format='decbytes',
  )
  .addTarget(
    prometheus.target(
      'rate(executor_threads_total_count{instance=~"$instance"}[$interval])\n/\nrate(executor_threads_total_sum{instance=~"$instance"}[$interval])',
      legendFormat='{{ name }} ({{ type }})',
      datasource='$PROMETHEUS_DS',
    )
  ),
  gridPos={ h: 6, w: 8, x: 0, y: 98 },
)
.addPanel(
  kamon_grafana.graph_panel.new(
    title='Number Of Tasks Completed',
    format='short',
  )
  .addTarget(
    prometheus.target(
      'rate(executor_tasks_completed_total{instance=~"$instance"}[$interval])',
      legendFormat='{{ name }} ({{ type }})',
      datasource='$PROMETHEUS_DS',
    )
  ),
  gridPos={ h: 6, w: 8, x: 8, y: 98 },
)
.addPanel(
  kamon_grafana.graph_panel.new(
    title='Queue Size',
    format='short',
  )
  .addTarget(
    prometheus.target(
      'rate(executor_queue_size_bucket{instance=~"$instance", le="+Inf"}[$interval])',
      legendFormat='{{ name }} ({{ type }})',
      datasource='$PROMETHEUS_DS',
    )
  ),
  gridPos={ h: 6, w: 8, x: 16, y: 98 },
)
.addPanel(
  kamon_grafana.graph_panel.new(
    title='Maximum Number of Threads',
    description='Tracks maximum number of Threads of the executors.',
    format='short',
  )
  .addTarget(
    prometheus.target(
      'executor_threads_max{instance=~"$instance"}',
      legendFormat='{{ name }} ({{ type }})',
      datasource='$PROMETHEUS_DS',
    )
  ),
  gridPos={ h: 6, w: 8, x: 0, y: 104 },
)
.addPanel(
  kamon_grafana.graph_panel.new(
    title='Minimum Number of Threads',
    description='Tracks minimum number of Threads of the executors.',
    format='short',
  )
  .addTarget(
    prometheus.target(
      'executor_threads_min{instance=~"$instance"}',
      legendFormat='{{ name }} ({{ type }})',
      datasource='$PROMETHEUS_DS',
    )
  ),
  gridPos={ h: 6, w: 8, x: 8, y: 104 },
)
.addPanel(
  kamon_grafana.graph_panel.new(
    title='Executor parallelism',
    description='Tracks executor parallelism.',
    format='short',
  )
  .addTarget(
    prometheus.target(
      'executor_parallelism{instance=~"$instance"}',
      legendFormat='{{ name }} ({{ type }})',
      datasource='$PROMETHEUS_DS',
    )
  ),
  gridPos={ h: 6, w: 8, x: 16, y: 104 },
) + version
