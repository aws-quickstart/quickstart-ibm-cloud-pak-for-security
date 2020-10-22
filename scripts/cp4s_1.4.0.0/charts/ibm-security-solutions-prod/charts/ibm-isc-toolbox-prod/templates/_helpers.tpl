{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "cp4s-toolbox.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "cp4s-toolbox.appName" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "cp4s-toolbox.podcfg" }}
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
{{- if index .val.Values.global.images.serviceability .app }}
  {{- with index .val.Values.global.images.serviceability .app }}
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
{{- with index .val.Values.global.resources.serviceability .app }}
{{- if or .requests .limits }}
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
{{- end }}

{{- define "cp4s-toolbox.storage" }}
{{- if not .val.global.useDynamicProvisioning }}
    storageClass: "-"
{{- else }}
{{- if .inst.installOptions.storageClass }}
    storageClass: {{ .inst.installOptions.storageClass }}
{{- end }}
{{- end }}
{{- end }}

{{- define "cp4s-toolbox.storageDefault" }}
{{- if not .Values.global.useDynamicProvisioning }}
    storageClass: "-"
{{- end }}
{{- end }}

{{- define "toolbox.annotate" }}
    annotations:
      productID: 0da6423dbe774a44bb34266c525d3809
      productName: cp4s-toolbox
      productVersion: 1.4.0
      productMetric: MANAGED_VIRTUAL_SERVER
      productChargedContainers: ""
      cloudpakName: IBM Cloud Pak for Security
      cloudpakId: 929bd9017afc410da9dda2dc67c33b75
      cloudpakVersion: 1.4.0
      productCloudpakRatio: ""
{{- end }}

{{/*
Sanitise and define registries
*/}}
{{- define "foundations.repository" -}}
{{- $frepo := required "global.repository variable is mandatory" .Values.global.repository -}}
{{- if eq "entitled" .Values.global.repositoryType -}}
{{- if contains "/" $frepo -}}
{{ $frepo | trimSuffix "/" }}/foundations
{{- else -}}
{{ $frepo }}
{{- end -}}
{{- else -}}
{{ $frepo }}
{{- end -}}
{{- end -}}

{{- define "solutions.repository" -}}
{{- $repo := required "global.repository variable is mandatory" .Values.global.repository -}}
{{- if eq "entitled" .Values.global.repositoryType -}}
{{- if contains "/" $repo -}}
{{ $repo | trimSuffix "/" }}/solutions
{{- else -}}
{{ $repo }}
{{- end -}}
{{- else -}}
{{ $repo }}
{{- end -}}
{{- end -}}

