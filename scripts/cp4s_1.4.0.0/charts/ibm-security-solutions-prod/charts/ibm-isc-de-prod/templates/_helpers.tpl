{{/* vim: set filetype=mustache: */}}

{{/*
The majority of standard parameters, like name, fullname, etc. are avaiable using the
ibm-sch chart.
*/}}

{{/*
Helper functions which can be used for used for .Values.arch in PPA Charts
Check if tag contains specific platform suffix and if not set based on kube platform
uncomment this section for PPA charts, can be removed in github.com charts

{{- define "content-repo-template.platform" -}}
{{- if not .Values.arch }}
  {{- if (eq "linux/amd64" .Capabilities.KubeVersion.Platform) }}
    {{- printf "-%s" "x86_64" }}
  {{- end -}}
  {{- if (eq "linux/ppc64le" .Capabilities.KubeVersion.Platform) }}
    {{- printf "-%s" "ppc64le" }}
  {{- end -}}
{{- else -}}
  {{- if eq .Values.arch "amd64" }}
    {{- printf "-%s" "x86_64" }}
  {{- else -}}
    {{- printf "-%s" .Values.arch }}
  {{- end -}}
{{- end -}}
{{- end -}}

{{- define "content-repo-template.arch" -}}
  {{- if (eq "linux/amd64" .Capabilities.KubeVersion.Platform) }}
    {{- printf "%s" "amd64" }}
  {{- end -}}
  {{- if (eq "linux/ppc64le" .Capabilities.KubeVersion.Platform) }}
    {{- printf "%s" "ppc64le" }}
  {{- end -}}
{{- end -}}

*/}}

{{- define "ibm-isc-de-prod-chart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}


{{- define "ibm-isc-de-prod-chart.fullname" -}}
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


{{- define "ibm-isc-de-prod-chart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "ibm-isc-de.podcfg" -}}
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
{{- if index .val.Values.global.images.de .app }}
  {{- with index .val.Values.global.images.de .app }}
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
{{- with index .val.Values.global.resources.de .app }}
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

{{- define "de.annotations" }}
    annotations:
      cloudpakId: 929bd9017afc410da9dda2dc67c33b75
      cloudpakName: IBM Cloud Pak for Security
      cloudpakVersion: 1.4.0
      productID: 12ec3ee8aefd4307a5146759dedbe6a4
      productName: Data Explorer
      productVersion: 1.4.0
      productMetric: MANAGED_VIRTUAL_SERVER
      productChargedContainers: All
      productCloudpakRatio: 1:1
{{- end }}

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
