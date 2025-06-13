{{/*
Common template helpers for the itl.keycloack.tenants Helm chart.
*/}}

{{- define "itl.keycloack.tenants.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "itl.keycloack.tenants.labels" -}}
app: {{ include "itl.keycloack.tenants.fullname" . }}
release: {{ .Release.Name }}
chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "modsecurity-crs.values" -}}
{{- $root := . -}}
enabled: {{ $root.Values.modsecurity.enabled | default false }}
proxy:
  replicaCount: {{ $root.Values.modsecurity.proxy.replicaCount | default 1 }}
  resources:
    limits:
      cpu: {{ $root.Values.modsecurity.proxy.resources.limits.cpu | default "250m" }}
      memory: {{ $root.Values.modsecurity.proxy.resources.limits.memory | default "256Mi" }}
{{- end -}}

{{- define "itl.keycloack.tenants.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{ .Release.Name }}-{{ .Chart.Name }}
{{- else -}}
{{ .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}
