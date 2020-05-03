local grafana = import 'grafonnet-lib/grafonnet/grafana.libsonnet';

{
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
