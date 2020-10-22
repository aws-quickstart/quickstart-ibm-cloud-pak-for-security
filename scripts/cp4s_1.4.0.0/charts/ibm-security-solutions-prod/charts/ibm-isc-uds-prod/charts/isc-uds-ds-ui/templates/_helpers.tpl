{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "ibm-isc-ds-ui.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "ibm-isc-ds-ui.fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "ibm-isc-ds-ui.replicas" -}}
{{- if .Values.global.bindings }}
{{- with index .Values.global.bindings.udswebui }}
{{- if .replicas }}
    replicas: {{ .replicas }}
{{- end }}
{{- end }}
{{- end }}
{{- end -}}