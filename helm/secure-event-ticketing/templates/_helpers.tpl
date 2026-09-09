{{/* Pomocni helperi - Autor: Lovro Siprak */}}
{{- define "ticketing.image" -}}
{{- printf "%s/%s/ticketing-%s:%s" .root.Values.image.registry .root.Values.image.owner .name .root.Values.image.tag -}}
{{- end -}}

{{- define "ticketing.labels" -}}
app.kubernetes.io/part-of: secure-event-ticketing
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}
