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
    service:
			main:
				ports:
					https:
						enabled: {{ $root.Values.modsecurity.proxy.service.main.ports.https.enabled | default true }}
						port: {{ $root.Values.modsecurity.proxy.service.main.ports.https.port | default 8443 }}
						targetPort: {{ $root.Values.modsecurity.proxy.service.main.ports.https.targetPort | default 8443 }}
						protocol: {{ $root.Values.modsecurity.proxy.service.main.ports.https.protocol | default "TCP" }}
		securityContext:
			container:
				runAsNonRoot: {{ $root.Values.modsecurity.proxy.securityContext.container.runAsNonRoot | default false }}
				readOnlyRootFilesystem: {{ $root.Values.modsecurity.proxy.securityContext.container.readOnlyRootFilesystem | default false }}
				runAsUser: {{ $root.Values.modsecurity.proxy.securityContext.container.runAsUser | default 0 }}
				runAsGroup: {{ $root.Values.modsecurity.proxy.securityContext.container.runAsGroup | default 0 }}
{{- end -}}

{{- define "itl.keycloack.tenants.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{ .Release.Name }}-{{ .Chart.Name }}
{{- else -}}
{{ .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

# {{- define "itl.keycloack.tenants.secretCredentials" -}}
# {{- $keycloack := .Values.keycloak | default dict -}}
# {{- $secretNamespace := $keycloack.secretNamespace | default .Release.Namespace -}}
# {{- $secretName := printf "itl-cnpg-clusters-%s-secret" ($keycloack.name | default "itlcnpg01") -}}
# {{- $secret := lookup "v1" "Secret" $secretNamespace $secretName }}
# {{- if not $secret }}
# {{- fail (printf "Secret %s not found in namespace %s" $secretName $secretNamespace) }}
# {{- end }}
# {{- if $secret }}
# username: {{ $secret.data.username | b64dec }}
# password: {{ $secret.data.password | b64dec }}
# {{- else }}
# username: {{ "error" | b64enc }}
# password: {{ "error" | b64enc }}
# {{- end }}
# {{- end -}}