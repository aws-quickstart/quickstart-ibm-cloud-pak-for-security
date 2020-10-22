{{/* vim: set filetype=mustache: */}}

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

{{- define "ibm-isc-cases.repoUrl" -}}
{{- if eq "entitled" .val.global.repositoryType -}}
  {{ .val.global.repository }}/solutions
{{- else -}}
  {{ .val.global.repository }}
{{- end -}}
{{- end -}}

{{- define "ibm-isc-cases.podcfg" -}}
{{- if index .val.global.images.cases .app }}
  {{- if eq "entitled" .val.global.repositoryType }}
    image: {{ .val.global.repository }}/solutions/{{- with index .val.global.images.cases .app }}{{ .image }}:{{ .tag }}{{- end -}}
  {{- else }}
    image: {{ .val.global.repository }}/{{- with index .val.global.images.cases .app }}{{ .image }}:{{ .tag }}{{- end -}}
  {{- end -}}
 {{- if .val.global.imagePullPolicy }}
    imagePullPolicy: {{ .val.global.imagePullPolicy }}
{{- end -}}
{{- else }}
{{- required "The image not found" .val.nonexist }}
{{- end }}
{{- end -}}

{{- define "ibm-isc-cases-operator-prod.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "ibm-isc-cases-operator-prod.fullname" -}}
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

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "ibm-isc-cases-operator-prod.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "ibm-isc-cases-operator-prod.labels" -}}
app.kubernetes.io/name: {{ include "ibm-isc-cases-operator-prod.name" . }}
helm.sh/chart: {{ include "ibm-isc-cases-operator-prod.chart" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "ibm-isc-cases.storageClassName" -}}
{{ (.val.global.elastic.cases.installOptions.storageClassName | default .val.global.storageClass) | default "" | quote }}
{{- end -}}

{{- define "ibm-isc-cases.dynamicProvisioning" -}}
{{- if kindIs "invalid" .val.global.useDynamicProvisioning -}}
   {{ "true" | quote }}
{{- else -}}
    {{ .val.global.useDynamicProvisioning | quote }}
{{- end -}}
{{- end -}}

{{- define "ibm-isc-cases.pg.primary.storageClassName" -}}
{{ (.val.global.postgres.cases.installOptions.primary.storageClassName | default .val.global.storageClass) | default "" | quote }}
{{- end -}}

{{- define "ibm-isc-cases.pg.backrest.storageClassName" -}}
{{ (.val.global.postgres.cases.installOptions.backrest.storageClassName | default .val.global.storageClass) | default "" | quote }}
{{- end -}}

{{- define "ibm-isc-cases.imagePullSecret" -}}
{{ .val.global.iscPullSecret | default "ibm-isc-pull-secret" }}
{{- end -}}