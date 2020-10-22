{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
# {{- define "ibm-isc-tii.name" -}}
# {{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
# {{- end -}}

# {{/*
# Create a default fully qualified app name.
# We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
# */}}
# {{- define "ibm-isc-tii.appName" -}}
# {{- $name := default .Chart.Name .Values.nameOverride -}}
# {{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
# {{- end -}}

{{- define "ibm-isc-tii.replicas" -}}
{{- if .Values.global.bindings }}
{{- with index .Values.global.bindings.tiisearch }}
{{- if .replicas }}
    replicas: {{ .replicas }}
{{- end }}
{{- end }}
{{- end }}
{{- end -}}


{{- define "ibm-isc-tii.podcfg" -}}
{{- if .replicas }}
    replicas: {{ .replicas }}
{{- else }}
  {{- if .val.Values.global.bindings }}
    {{- with index .val.Values.global.bindings .app }}
    {{- if .replicas }}
    replicas: {{ .replicas }}
    {{- end }}
    {{- end }}
  {{- end }}
{{- end }}
    release: {{ .val.Release.Name }}
{{- if index .val.Values.global.images.tii .app }}
  {{- with index .val.Values.global.images.tii .app }}
    image:
      repository: {{ .image }}
      tag: {{ .tag }}
  {{- end }}
{{- if .val.Values.global.imagePullPolicy }}
      pullPolicy: {{ .val.Values.global.imagePullPolicy }}
{{- end }}
{{- else }}
{{- required "The image not found" .val.nonexist }}
{{- end }}
{{- with index .val.Values.global.resources.tii .app }}
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
{{- end -}}

{{- define "ibm-isc-tii.couch_db_instance" -}}
{{- if .val.global.bindings }}
{{- if index .val.global.bindings .app }}
{{- with index .val.global.bindings .app }}
    instance: couch-{{ .couchdbInstance | default "default" }}
{{- end }}
{{- else }}
    instance: couch-default
{{- end }}
{{- else }}
    instance: couch-default
{{- end }}
{{- end -}}

{{- define "ibm-isc-tii.couch_db_opts" -}}
{{- if .val.global.bindings }}
{{- if index .val.global.bindings .app }}
{{- with index .val.global.bindings .app }}
    instanceUser: {{ .couchdbInstanceUser | default "false" }}
{{- end }}
{{- else }}
    instanceUser: false
{{- end }}
{{- else }}
    instanceUser: false
{{- end }}
{{- end -}}

{{- define "ibm-isc-tii.redis_init" }}
    - name: init redis for {{ .app }}
      operation: redis
      dependencies:
{{- if .val.global.bindings }}
{{- if index .val.global.bindings .app }}
{{- with index .val.global.bindings .app }}
      - redis-{{ .redis | default "default" }}
{{- end }}
{{- else }}
      - redis-default
{{- end }}
{{- else }}
      - redis-default
{{- end }}
{{- end }}

{{- define "ibm-isc-tii.redis_dep" }}
{{- if .val.global.bindings }}
{{- if index .val.global.bindings .app }}
{{- with index .val.global.bindings .app }}
      - redis-{{ .redis | default "default" }}
{{- end }}
{{- else }}
      - redis-default
{{- end }}
{{- else }}
      - redis-default
{{- end }}
{{- end }}

{{- define "tii.annotations" }}
    annotations:
      productID: 0070760bf12a4857be9f6880f950a894
      productName: Threat Intelligence Insights
      productVersion: 1.4.0
      productMetric: MANAGED_VIRTUAL_SERVER
      productChargedContainers: All
      cloudpakName: IBM Cloud Pak for Security
      cloudpakId: 929bd9017afc410da9dda2dc67c33b75
      cloudpakVersion: 1.4.0
      productCloudpakRatio: 1:1
{{- end }}

{{- define "platform.repository" -}}
{{- if eq (default .Values.global.repositoryType "local") "entitled" -}}
{{- if contains "/" .Values.global.repository -}}
{{ .Values.global.repository | trimSuffix "/" }}/solutions
{{- else -}}
{{ .Values.global.repository }}
{{- end -}}
{{- else -}}
{{ .Values.global.repository }}
{{- end -}}
{{- end -}}
