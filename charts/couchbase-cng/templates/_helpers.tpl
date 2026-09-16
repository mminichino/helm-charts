{{- define "couchbase-cng.name" -}}
{{- default .Chart.Name .Values.name | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "couchbase-cng.fullname" -}}
{{- .Values.name | default .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "couchbase-cng.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "couchbase-cng.labels" -}}
helm.sh/chart: {{ include "couchbase-cng.chart" . }}
{{ include "couchbase-cng.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "couchbase-cng.selectorLabels" -}}
app.kubernetes.io/name: {{ include "couchbase-cng.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "couchbase-cng.secretName" -}}
{{- printf "%s-credentials" (include "couchbase-cng.fullname" .) -}}
{{- end }}

{{- define "couchbase-cng.clusterCaSecretName" -}}
{{- printf "%s-cluster-ca" (include "couchbase-cng.fullname" .) -}}
{{- end }}

{{- define "couchbase-cng.clusterCaMountPath" -}}
/certs/cluster-ca.crt
{{- end }}

{{- define "couchbase-cng.namespace" -}}
{{- .Values.namespace | default .Release.Namespace -}}
{{- end }}
