{{/* vim: set filetype=mustache: */}}

{{/*
  Global Postgres overrides
  global:
    postgres:
      host: <foo>
      port: 1234
      password:
        secret: <password secret name>
        key: <key in secret containing password>
*/}}
{{- define "harnesscommon.database.postgres.host" -}}
{{- coalesce (pluck "host" .Values.global.postgres | first ) (printf "%s.%s.svc" "postgres" $.Release.Namespace) -}}
{{- end -}}

{{- define "harnesscommon.database.postgres.port" -}}
{{- default 5432 (pluck "port" .Values.global.postgres | first) | int -}}
{{- end -}}

{{/*
Return the secret name
Defaults to "postgres' and falls back to .Values.global.postgres.password.secretName
  when using an external PostgreSQL
*/}}
{{- define "harnesscommon.database.postgres.password.secret.name" -}}
{{- default (printf "%s" "postgres") (pluck "secret" $.Values.global.postgres.password | first ) | quote -}}
{{- end -}}

{{- define "harnesscommon.database.postgres.password.secret.key" -}}
{{- default (printf "%s" "postgres-password") (pluck "key" $.Values.global.postgres.password | first ) | quote -}}
{{- end -}}

{{- define "harnesscommon.database.postgres.password" -}}
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ template "harnesscommon.database.postgres.password.secret.name" .}}
      key: {{ template "harnesscommon.database.postgres.password.secret.key" . }}
{{- end -}}

{{- define "harnesscommon.database.postgres" -}}
postgres://postgres:$(DB_PASSWORD){{template "harnesscommon.database.postgres.host" . }}:{{template "harnesscommon.database.postgres.port" . }}
{{- end -}}

{{/*
Create Mongo DB Connection String

Usage:
{{ include "harnesscommon.database.mongo" (dict "database" "database_name" "context" $) }}

Params:
  - database - String - Required. Database to connect to
  - context - Strong  -Required. context scope
*/}}
{{- define "harnesscommon.database.mongo" -}}
{{- $db := .database -}}
{{- $namespace := include "harnesscommon.names.namespace" .context -}}
{{- if .context.Values.global.ha -}}
{{- printf "'mongodb://$(MONGODB_USERNAME):$(MONGODB_PASSWORD)@mongodb-replicaset-chart-0.mongodb-replicaset-chart.%s.svc,mongodb-replicaset-chart-1.mongodb-replicaset-chart.%s.svc,mongodb-replicaset-chart-2.mongodb-replicaset-chart.%s.svc:27017/%s?replicaSet=rs0&authSource=admin'" $namespace $namespace $namespace $db -}}
{{- else -}}
{{- printf "'mongodb://$(MONGODB_USERNAME):$(MONGODB_PASSWORD)@mongodb-replicaset-chart-0.mongodb-replicaset-chart.%s.svc/%s?authSource=admin'" $namespace $db -}}
{{- end -}}

{{- end -}}
