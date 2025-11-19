{{- define "postgres.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "postgres.labels" -}}
helm.sh/chart: {{ include "postgres.chart" . }}
{{ include "postgres.selectorLabels" . -}}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "postgres.selectorLabels" -}}
app.kubernetes.io/name: {{ .Values.name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "postgres.password" -}}
{{- $secret := lookup "v1" "Secret" (.Values.namespace | default .Release.Namespace) .Values.name -}}
{{- $password := "" -}}
{{- if $secret -}}
{{- $password = index $secret.data "password" | b64dec -}}
{{- else if .Values.postgres.auth.password -}}
{{- $password = .Values.postgres.auth.password -}}
{{- else -}}
{{- $password = randAlphaNum 16 -}}
{{- end -}}
{{- $password -}}
{{- end }}
