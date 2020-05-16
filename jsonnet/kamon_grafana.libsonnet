local grafana = import 'grafonnet-lib/grafonnet/grafana.libsonnet';

{
  template:: {
    prometheus_datasource():: self + grafana.template.datasource(
      'PROMETHEUS_DS',
      'prometheus',
      'Prometheus',
      hide='label',
    ),
    job(
      includeAll=true,
      multi=true,
      query,
    ):: self + grafana.template.new(
      'job',
      '$PROMETHEUS_DS',
      query=query,
      label='Job',
      refresh='load',
      includeAll=includeAll,
      multi=multi,
    ),
    instance(
      includeAll=true,
      multi=true,
    ):: self +
        grafana.template.new(
          'instance',
          '$PROMETHEUS_DS',
          query='label_values(up{job=~"$job"},instance)',
          label='Instance',
          refresh='load',
          includeAll=includeAll,
          multi=multi,
        ),
    interval(
      query='1m,2m,5m,10m,30m,1h,6h,12h,1d,7d,14d,30d',
    ):: self +
        grafana.template.interval(
          name='interval',
          query=query,
          current='1m',
          label='Interval',
          auto_count=0,
        ),
  },

  gauge:: {
    new(
      title,
      datasource=null,
      calc='mean',
      time_from=null,
      span=null,
      description='',
      height=null,
      transparent=null,
      unit_format=null,
      thresholds=null,
    ):: self + grafana.gauge.new(
      title,
      datasource,
      calc,
      time_from,
      span,
      description,
      height,
      transparent,
    ) {
      fieldConfig: {
        defaults: {
          unit: unit_format,
          thresholds: thresholds,
          mappings: [],
        },
      },
    },
  },

  stat:: {
    new(
      title,
      description='',
      datasource=null,
      timeFrom=null,
      links=[],
      maxPerRow=null,
      options=null,
    )::
      {
        title: title,
        datasource: datasource,
        timeFrom: timeFrom,
        links: links,
        maxPerRow: maxPerRow,
        options: options,
        type: 'stat',
        [if description != '' then 'description']: description,
        fieldConfig: null,
        targets: [
        ],
        _nextTarget:: 0,
        addTarget(target):: self {
          local nextTarget = super._nextTarget,
          _nextTarget: nextTarget + 1,
          targets+: [target { refId: std.char(std.codepoint('A') + nextTarget) }],
        },
        add_field_config(
          unit=null,
          thresholds=null,
        ):: self {
          fieldConfig: {
            defaults: {
              unit: unit,
              thresholds: thresholds,
              mappings: [],
            },
          },
        },
      },
  },

  stats_thresholds:: {
    new(
      mode,
      steps,
    ):: {
      mode: mode,
      steps: steps,
    },
  },

  stats_options:: {
    new(
      orientation='auto',
      colorMode='value',
      graphMode='area',
      justifyMode='auto',
    ):: {
      orientation: orientation,
      colorMode: colorMode,
      graphMode: graphMode,
      justifyMode: justifyMode,
      reduceOptions: null,
      add_reduce_options(
        values=false,
        calcs=['lastNotNull'],
      ):: self {
        reduceOptions: {
          values: values,
          calcs: calcs,
        },
      },
    },
  },

  cpu_stats_panel:: {
    new(
      title,
      description,
      query_expression,
    )::
      $.stat.new(
        title,
        description=description,
        datasource='-- Mixed --',
        options=$.stats_options.new().add_reduce_options(),
      )
      .addTarget(
        grafana.prometheus.target(
          query_expression,
          datasource='$PROMETHEUS_DS',
        )
      )
      .add_field_config(
        unit='percent',
        thresholds=$.stats_thresholds.new(
          mode='absolute',
          steps=[
            { color: 'rgba(31, 96, 196, 1)', value: null },
            { color: 'rgba(140, 44, 186, 1)', value: 50 },
            { color: 'rgba(196, 22, 42, 1)', value: 80 },
          ],
        ),
      ),
  },

  net_bandwidth_overview_panel:: {
    new(
      title,
      description,
      query_expression,
    )::
      $.stat.new(
        title,
        description=description,
        datasource='-- Mixed --',
        options=$.stats_options.new(
          orientation='horizontal'
        ).add_reduce_options(),
      )
      .addTarget(
        grafana.prometheus.target(
          query_expression,
          datasource='$PROMETHEUS_DS',
        )
      )
      .add_field_config(
        unit='Bps',
        thresholds=$.stats_thresholds.new(
          mode='absolute',
          steps=[
            { color: 'semi-dark-green', value: null },
          ],
        ),
      ),
  },
}
