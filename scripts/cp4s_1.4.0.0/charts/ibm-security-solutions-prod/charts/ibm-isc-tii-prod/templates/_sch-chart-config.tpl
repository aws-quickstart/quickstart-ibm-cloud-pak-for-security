{{- /*
Chart specific config file for SCH (Shared Configurable Helpers)
_sch-chart-config.tpl is a config file for the chart to specify additional
values and/or override values defined in the sch/_config.tpl file.

*/ -}}

{{- /*
"sch.chart.config.values" contains the chart specific values used to override or provide
additional configuration values used by the Shared Configurable Helpers.
*/ -}}
{{- define "isc-tiisearch.sch.chart.config.values" -}}
   sch:
  chart:
    appName: "ibm-isc-tii"
    components:
      api:
        deploymentName: "tiisearch"
{{- end -}}
{{- define "isc-tiiapp.sch.chart.config.values" -}}
   sch:
  chart:
    appName: "ibm-isc-tii"
    components:
      api:
        deploymentName: "tiiapp"
{{- end -}}
{{- define "isc-tiireports.sch.chart.config.values" -}}
   sch:
  chart:
    appName: "ibm-isc-tii"
    components:
      api:
        deploymentName: "tiireports"
{{- end -}}
{{- define "isc-tiithreats.sch.chart.config.values" -}}
   sch:
  chart:
    appName: "ibm-isc-tii"
    components:
      api:
        deploymentName: "tiithreats"
{{- end -}}
{{- define "isc-tiisettings.sch.chart.config.values" -}}
   sch:
  chart:
    appName: "ibm-isc-tii"
    components:
      api:
        deploymentName: "tiisettings"
{{- end -}}
