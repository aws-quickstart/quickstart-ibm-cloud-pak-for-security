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

{{- define "ibm-isc-tis.replicas" -}}
{{- if .Values.global.bindings }}
{{- with index .Values.global.bindings .app }}
{{- if .replicas }}
    replicas: {{ .replicas }}
{{- end }}
{{- end }}
{{- end }}
{{- end -}}


{{- define "ibm-isc-tis.podcfg" -}}
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
{{- if index .val.Values.global.images.tis .app }}
  {{- with index .val.Values.global.images.tis .app }}
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
{{- with index .val.Values.global.resources.tis .app }}
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

{{- define "ibm-isc-tis.couch_db_instance" -}}
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

{{- define "ibm-isc-tis.couch_db_opts" -}}
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

{{- define "ibm-isc-platform.redis_init" }}
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

{{- define "ibm-isc-platform.redis_dep" }}
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

{{- define "tis.annotations" }}
    annotations:
      productID: 2153d1f2927140648da4bcf44ba38e9e
      productName: Threat Intelligence Service
      productVersion: 1.4.0
      productMetric: MANAGED_VIRTUAL_SERVER
      cloudpakName: IBM Cloud Pak for Security
      cloudpakId: 929bd9017afc410da9dda2dc67c33b75
      cloudpakVersion: 1.4.0
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
