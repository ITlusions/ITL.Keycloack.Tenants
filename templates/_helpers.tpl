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

{{- define "itl.keycloack.tenants.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{ .Release.Name }}-{{ .Chart.Name }}
{{- else -}}
{{ .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "itl.keycloack.tenants.secretCredentials" -}}
{{- $secret := lookup "v1" "Secret" .Release.Namespace "my-secret" }}
username: {{ .Values.secret.username | default (ternary ($secret.data.username | b64dec) "error" $secret) }}
password: {{ .Values.secret.password | default (ternary ($secret.data.password | b64dec) "error" $secret) }}
{{- end -}}