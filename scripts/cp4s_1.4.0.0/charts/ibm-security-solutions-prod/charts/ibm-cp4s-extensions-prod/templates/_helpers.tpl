{{/* vim: set filetype=mustache: */}}

{{/*
The majority of standard parameters, like name, fullname, etc. are avaiable using the
ibm-sch chart.
*/}}

{{/*
Helper functions which can be used for .Values.arch in PPA Charts
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

{{- define "ibm-cp4s-extensions-prod-chart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}


{{- define "ibm-cp4s-extensions-prod-chart.fullname" -}}
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


{{- define "ibm-cp4s-extensions-prod-chart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "extensions.annotations" }}
    annotations:
      cloudpakId: 929bd9017afc410da9dda2dc67c33b75
      cloudpakName: IBM Cloud Pak for Security
      cloudpakVersion: 1.4.0
      productID: cd92b180d63b45ad9cecfa4a559d202e
      productName: Connector Factory
      productVersion: 1.4.0
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
