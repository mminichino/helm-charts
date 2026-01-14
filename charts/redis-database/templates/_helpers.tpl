{{- define "redis-database.password" -}}
{{- .Values.password | default (randAlphaNum 16) -}}
{{- end -}}
