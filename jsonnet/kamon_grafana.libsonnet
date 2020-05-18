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
      query='30s,1m,2m,5m,10m,30m,1h,6h,12h,1d,7d,14d,30d',
    ):: self +
        grafana.template.interval(
          name='interval',
          query=query,
          current='1m',
          label='Interval',
          auto_count=0,
        ),
  },

  graph_panel:: {
    new(
      title,
      description=null,
      format,
      min=null,
      max=null,
      decimals=null,
      datasource='$PROMETHEUS_DS',
      legend_show=true,
      legend_values=true,
      legend_min=true,
      legend_max=true,
      legend_current=true,
      legend_total=false,
      legend_avg=true,
      legend_alignAsTable=true,
      legend_rightSide=false,
      legend_sort='max',
      legend_sortDesc=true,
      bars=false,
      stack=false,
      percentage=false,
      lines=true,
      linewidth=1,
      points=false,
      pointradius=2,
    ):: self + grafana.graphPanel.new(
      title=title,
      description=description,
      format=format,
      decimals=decimals,
      min=min,
      max=max,
      datasource=datasource,
      legend_show=legend_show,
      legend_values=legend_values,
      legend_min=legend_min,
      legend_max=legend_max,
      legend_current=legend_current,
      legend_total=legend_total,
      legend_avg=legend_avg,
      legend_alignAsTable=legend_alignAsTable,
      legend_rightSide=legend_rightSide,
      legend_sort=legend_sort,
      legend_sortDesc=legend_sortDesc,
      lines=lines,
      linewidth=linewidth,
      points=points,
      pointradius=pointradius,
      bars=bars,
      stack=stack,
      percentage=percentage,
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

  bargauge:: {
    new(
      title,
      description='',
      datasource=null,
      calc='lastNotNull',
      time_from=null,
      span=null,
      height=null,
      transparent=null,
      unit_format=null,
      thresholds=null,
      fieldConfig=null,
      options_orientation='auto',
      options_displayMode='lcd',
      options_showUnfilled=true,
    ):: self +
        {
          [if description != '' then 'description']: description,
          [if height != null then 'height']: height,
          [if transparent != null then 'transparent']: transparent,
          [if time_from != null then 'timeFrom']: time_from,
          [if span != null then 'span']: span,
          title: title,
          type: 'bargauge',
          datasource: datasource,
          options: {
            reduceOptions: {
              values: false,
              calcs: [
                calc,
              ],
            },
            orientation: options_orientation,
            displayMode: options_displayMode,
            showUnfilled: options_showUnfilled,
          },
          _nextTarget:: 0,
          addTarget(target):: self {
            local nextTarget = super._nextTarget,
            _nextTarget: nextTarget + 1,
            targets+: [target { refId: std.char(std.codepoint('A') + nextTarget) }],
          },
          add_field_config(
            field_config=null,
          ):: self {
            fieldConfig: field_config,
          },
        },
  },

  barstats_field_config(
    unit=null,
    min=null,
    max=null,
    thresholds=null,
    decimals=null,
  ):: self {

    _overrides:: [],
    defaults: {
      unit: unit,
      thresholds: thresholds,
      mappings: [],
      [if min != null then 'min']: min,
      [if max != null then 'max']: max,
      [if decimals != null then 'decimals']: decimals,
    },
    addOverride(
      matcher_id='byName',
      matcher_options,
      properties,
    ):: self {
      overrides+: [{
        matcher: { id: matcher_id, options: matcher_options },
        properties: properties,
      }],
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
        datasource='$PROMETHEUS_DS',
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
