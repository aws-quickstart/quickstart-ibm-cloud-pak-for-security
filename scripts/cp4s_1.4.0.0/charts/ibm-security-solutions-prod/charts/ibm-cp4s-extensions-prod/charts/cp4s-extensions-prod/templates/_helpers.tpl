{{/*
Sanitise and define registries
*/}}
{{- define "image.repository" -}}
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
