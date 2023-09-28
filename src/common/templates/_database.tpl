{{/* vim: set filetype=mustache: */}}

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
