{{- /*
Chart specific config file for SCH (Shared Configurable Helpers)

_sch-chart-config.tpl is a config file for the chart to specify additional 
values and/or override values defined in the sch/_config.tpl file.
 
*/ -}}

{{- /*
"sch.chart.config.values" contains the chart specific values used to override or provide
additional configuration values used by the Shared Configurable Helpers.
*/ -}}
{{- define "isc-tisrfi.sch.chart.config.values" -}}
   sch:
  chart:
    appName: "ibm-isc-tis"
    components:
      api:
        deploymentName: "tisrfi"
{{- end -}}
{{- define "isc-tisaia.sch.chart.config.values" -}}
   sch:
  chart:
    appName: "ibm-isc-tis"
    components:
      api:
        deploymentName: "tisaia"
{{- end -}}
{{- define "isc-tisdatagateway.sch.chart.config.values" -}}
   sch:
  chart:
    appName: "ibm-isc-tis"
    components:
      api:
        deploymentName: "tisdatagateway"
{{- end -}}
{{- define "isc-tiscoordinator.sch.chart.config.values" -}}
   sch:
  chart:
    appName: "ibm-isc-tis"
    components:
      api:
        deploymentName: "tiscoordinator"
{{- end -}}
{{- define "isc-tis-scoring-controller.sch.chart.config.values" -}}
   sch:
  chart:
    appName: "ibm-isc-tis"
    components:
      api:
        deploymentName: "tisscoring"
{{- end -}}
