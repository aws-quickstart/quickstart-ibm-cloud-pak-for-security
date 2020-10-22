{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "ibm-isc-aitk-prod.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "ibm-isc-aitk-prod.fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "ibm-isc-aitk-prod.replicas" -}}
{{- if .val.bindings }}
{{- with index .val.bindings .app }}
{{- if .replicas }}
    replicas: {{ .replicas }}
{{- end }}
{{- end }}
{{- end }}
{{- end -}}

{{- define "aitk.couch_db_instance" -}}
{{- if .val.bindings }}
{{- if index .val.bindings .app }}
{{- with index .val.bindings .app }}
    instance: couch-{{ .couchdbInstance | default "default" }}
{{- end }}
{{- else }}
    instance: couch-default
{{- end }}
{{- else }}
    instance: couch-default
{{- end }}
{{- end -}}

{{- define "aitk.couch_db_opts" -}}
{{- if .val.bindings }}
{{- if index .val.bindings .app }}
{{- with index .val.bindings .app }}
    instanceUser: {{ .couchdbInstanceUser | default "false" }}
{{- end }}
{{- else }}
    instanceUser: false
{{- end }}  
{{- else }}
    instanceUser: false
{{- end }}
{{- end -}}

{{- define "aitk.resources" -}}
{{- with index .val.Values.global.resources.platform.orchestrator .app }}
      resources:
{{- if .requests }}
        requests:
{{- if .requests.cpu }}
          cpu: {{ .requests.cpu }}
{{- end }}
{{- if .requests.memory }}
          memory: {{ .requests.memory }}
{{- end }}
{{- end }}
{{- if .limits }}
        limits:
{{- if .limits.cpu }}
          cpu: {{ .limits.cpu }}
{{- end }}
{{- if .limits.memory }}
          memory: {{ .limits.memory }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
