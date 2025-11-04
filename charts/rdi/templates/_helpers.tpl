{{- define "rdi.securityContext" }}
securityContext:
  {{- toYaml .Values.global.securityContext | nindent 2 }}
{{- end }}

{{- define "rdi.cert.paths.cert" -}}
/etc/certificates/rdi_db/cert
{{- end -}}

{{- define "rdi.cert.paths.key" -}}
/etc/certificates/rdi_db/key
{{- end -}}

{{- define "rdi.cert.paths.cacert" -}}
/etc/certificates/rdi_db/cacert
{{- end -}}
