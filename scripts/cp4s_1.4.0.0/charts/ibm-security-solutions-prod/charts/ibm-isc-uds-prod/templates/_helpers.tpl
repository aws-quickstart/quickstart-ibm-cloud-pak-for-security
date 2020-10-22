{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "ibm-isc-uds-chart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "ibm-isc-uds-chart.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "ibm-isc-uds.podcfg" -}}
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
{{- if index .val.Values.global.images.uds .app }}
  {{- with index .val.Values.global.images.uds .app }}
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
{{- with index .val.Values.global.resources.uds .app }}
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

{{- define "ibm-isc-uds-chart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "uds.annotations" }}
    annotations:
      productID: 7ee99d252b954699b06596672248be67
      productName: Universal Data Service
      productVersion: 1.4.0
      productMetric: MANAGED_VIRTUAL_SERVER
      cloudpakName: IBM Cloud Pak for Security
      cloudpakId: 929bd9017afc410da9dda2dc67c33b75
      cloudpakVersion: 1.4.0
{{- end }}

{{- define "udi.prefix" -}}
{{- if .val.Values.global.prefix -}}
{{- printf "%s-%s" .val.Values.global.prefix .name | trunc 63 -}}
{{- else -}}
{{- .name | trunc 63 -}}
{{- end -}}
{{- end -}}

{{- define "udi.minioPrefix" -}}
{{- if .val.Values.global.minio.prefix -}}
{{- printf "%s-%s" .val.Values.global.minio.prefix .name | trunc 63 -}}
{{- else -}}
{{- .name | trunc 63 -}}
{{- end -}}
{{- end -}}

{{- define "udi.ingressPrefix" -}}
{{- if .Values.global.ingressPrefix -}}
{{- .Values.global.ingressPrefix -}}
{{- else -}}
{{- .Chart.Name -}}
{{- end -}}
{{- end -}}

{{- define "udi.uiPrefix" -}}
{{- if .Values.global.uiPrefix -}}
/{{- .Values.global.uiPrefix -}}
{{- end -}}
{{- end -}}

{{- define "platform.repository" -}}
{{- if eq "entitled" .Values.global.repositoryType -}}
{{- if contains "/" .Values.global.repository -}}
{{ .Values.global.repository | trimSuffix "/" }}/solutions
{{- else -}}
{{ .Values.global.repository }}
{{- end -}}
{{- else -}}
{{ .Values.global.repository }}
{{- end -}}
{{- end -}}

{{/*
Display license
*/}}
{{- define "ibm-isc-uds-prod.license" -}}
{{- $licenseName := .Values.global.licenseFileName -}}
{{- $licenseAccept := .Values.global.license -}}
{{- $license := .Files.Get $licenseName -}}
{{- $msg := "Please read the above license and set global.license=accept to install the product." -}}
{{- $border := printf "\n%s\n" (repeat (len $msg ) "=") -}}
{{- printf "\n%s\n\n\n%s%s%s" $license $border $msg $border -}}
{{- end -}}
