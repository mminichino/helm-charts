{{- define "redis-database.password" -}}
{{- $secret := lookup "v1" "Secret" .Release.Namespace .Values.name }}
{{- $password := "" }}
{{- if $secret }}
{{- $password = index $secret.data "password" | b64dec }}
{{- else }}
{{- $password = default (randAlphaNum 8) .Values.password }}
{{- end }}
{{- end -}}
