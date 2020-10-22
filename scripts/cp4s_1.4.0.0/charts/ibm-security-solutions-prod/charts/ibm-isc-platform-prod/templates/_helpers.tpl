{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "ibm-isc-platform.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "ibm-isc-platform.appName" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "ibm-isc-platform.podcfg" }}
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
{{- if index .val.Values.global.images.platform .app }}
  {{- with index .val.Values.global.images.platform .app }}
    image:
      repository: {{ .image }}
      tag: {{ .tag }}
      {{- if .pullSecret }}
      pullSecret: {{ .pullSecret }}
      {{- end }}
  {{- end }}
{{- if .val.Values.global.imagePullPolicy }}
      pullPolicy: {{ .val.Values.global.imagePullPolicy }}
{{- end }}
{{- else }}
{{- required "The image not found" .val.nonexist }}
{{- end }}
{{- with index .val.Values.global.resources.platform .app }}
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

{{- define "ibm-isc-platform.couch_db_instance" -}}
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

{{- define "ibm-isc-platform.couch_db_opts" -}}
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

{{- define "ibm-isc-platform.etcd_init" }}
    - name: init etcd for {{ .app }}
      operation: etcd
      dependencies:
{{- if .val.global.bindings }}
{{- if index .val.global.bindings .app }}
{{- with index .val.global.bindings .app }}
      - etcd-{{ .etcd | default "default" }}
{{- end }}
{{- else }}
      - etcd-default
{{- end }}
{{- else }}
      - etcd-default
{{- end }}
{{- end }}

{{- define "ibm-isc-platform.etcd_dep" }}
{{- if .val.global.bindings }}
{{- if index .val.global.bindings .app }}
{{- with index .val.global.bindings .app }}
      - etcd-{{ .etcd | default "default" }}
{{- end }}
{{- else }}
      - etcd-default
{{- end }}
{{- else }}
      - etcd-default
{{- end }}
{{- end }}

{{- define "ibm-isc-platform.storage" }}
{{- if not .val.global.useDynamicProvisioning }}
    storageClass: "-"
{{- else }}
{{- if .inst.installOptions.storageClass }}
    storageClass: {{ .inst.installOptions.storageClass }}
{{- end }}
{{- end }}
{{- end }}

{{- define "ibm-isc-platform.storageDefault" }}
{{- if not .Values.global.useDynamicProvisioning }}
    storageClass: "-"
{{- end }}
{{- end }}

{{- define "platform.annotate" }}
    annotations:
      productID: 0da6423dbe774a44bb34266c525d3809
      productName: Platform
      productVersion: 1.4.0
      productMetric: MANAGED_VIRTUAL_SERVER
      productChargedContainers: ""
      cloudpakName: IBM Cloud Pak for Security
      cloudpakId: 929bd9017afc410da9dda2dc67c33b75
      cloudpakVersion: 1.4.0
      productCloudpakRatio: ""
{{- end }}

{{- define "aitk.annotate" }}
    annotations:
      productID: c05e4910c294498eb1bfd1f8aa0ea189
      productName: AI Toolkit
      productVersion: 1.4.0
      productMetric: MANAGED_VIRTUAL_SERVER
      productChargedContainers: ""
      cloudpakName: IBM Cloud Pak for Security
      cloudpakId: 929bd9017afc410da9dda2dc67c33b75
      cloudpakVersion: 1.4.0
      productCloudpakRatio: ""
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
