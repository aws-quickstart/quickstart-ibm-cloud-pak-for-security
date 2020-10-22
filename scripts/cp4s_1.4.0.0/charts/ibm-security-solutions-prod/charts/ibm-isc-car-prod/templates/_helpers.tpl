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

{{- define "ibm-isc-car-prod-chart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}


{{- define "ibm-isc-car-prod-chart.fullname" -}}
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


{{- define "ibm-isc-car-prod-chart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "ibm-isc-car.podcfg" -}}
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
{{- if index .val.Values.global.images.car .app }}
  {{- with index .val.Values.global.images.car .app }}
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
{{- with index .val.Values.global.resources.car .app }}
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

{{- define "ibm-isc-car-prod.replicas" -}}
{{- if .Values.global.bindings.car }}
{{- with index .Values.global.bindings.car .app }}
{{- if .replicas }}
    replicas: {{ .replicas }}
{{- end }}
{{- end }}
{{- end }}
{{- end -}}

{{- define "isc-car-connector-config-prod.replicas" -}}
{{- if .Values.global.bindings.carConnectorConfig }}
{{- with index .Values.global.bindings.carConnectorConfig .app }}
{{- if .replicas }}
    replicas: {{ .replicas }}
{{- end }}
{{- end }}
{{- end }}
{{- end -}}

{{- define "ibm-isc-car-frontend-ui-prod.replicas" -}}
{{- if .Values.global.bindings.carFrontendUi }}
{{- with index .Values.global.bindings.carFrontendUi .app }}
{{- if .replicas }}
    replicas: {{ .replicas }}
{{- end }}
{{- end }}
{{- end }}
{{- end -}}

{{- define "car.annotations" }}
    annotations:
      productID: 545bf62dce574f99af370899013a4a8a
      productName: Connect Asset and Risk
      productVersion: 1.4.0
      productMetric: MANAGED_VIRTUAL_SERVER
      productChargedContainers: ""
      cloudpakName: IBM Cloud Pak for Security
      cloudpakId: 929bd9017afc410da9dda2dc67c33b75
      cloudpakVersion: 1.4.0
      productCloudpakRatio: ""
{{- end }}

{{- define "arangodb.annotations" }}
  annotations:
    cloudpakId: 8682277514124c6a95335bd792acb2d0
    cloudpakName: IBM Cloud Pak for Security
    cloudpakVersion: 1.4.0
    productID: c110ed5986a54415987bf47b8b2ebd9f
    productName: ArangoDB
    productMetric: MANAGED_VIRTUAL_SERVER
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
