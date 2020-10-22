{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}

{{- define "ibm-isc-car.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "ibm-isc-car.fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "ibm-isc-car.replicas" -}}
{{- if .val.bindings }}
{{- with index .val.bindings .app }}
{{- if .replicas }}
    replicas: {{ .replicas }}
{{- end }}
{{- end }}
{{- end }}
{{- end -}}

{{- define "ibm-isc-car.couch_db_instance" -}}
{{- if .val.bindings }}
{{- if index .val.bindings .app }}
{{- with index .val.bindings .app }}
    instance: couch-{{ .couchdbInstance | default "default" }}
{{- end }}
{{- else }}
    instance: couch-default
{{- end }}
{{- else }}
    instance: couch-default
{{- end }}
{{- end -}}

{{- define "ibm-isc-car.couch_db_opts" -}}
{{- if .val.bindings }}
{{- if index .val.bindings .app }}
{{- with index .val.bindings .app }}
    instanceUser: {{ .couchdbInstanceUser | default "false" }}
{{- end }}
{{- else }}
    instanceUser: false
{{- end }}  
{{- else }}
    instanceUser: false
{{- end }}
{{- end -}}

{{- define "ibm-isc-car.redis_init" }}
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

{{- define "ibm-isc-car.redis_dep" }}
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
