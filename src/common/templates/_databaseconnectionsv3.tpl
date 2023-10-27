{{/*
Generates MongoDB environment variables
USAGE:
{{ include "harnesscommon.dbconnectionv2.manageMongoEnv" (dict "ctx" $ "localDBCtx" "userVariableName" "" "passwordVariableName" "" .Values.mongo "globalDBCtx" .Values.global.database.mongo) | indent 12 }}

INPUT ARGUMENTS:
REQUIRED:
1. ctx
2. instanceName

OPTIONAL:
1. localDBCtx
   Default: $.Values.mongo
2. globalDBCtx
   Default: $.Values.global.database.mongo
3. userVariableName
   Default: MONGO_USER
4. passwordVariableName
   Default: MONGO_PASSWORD

*/}}
{{- define "harnesscommon.dbconnectionv3.mongoEnv" }}
    {{- $ := .ctx }}
    {{- $instanceName := .instanceName }}
    {{- if empty $instanceName }}
        {{- fail "missing input argument: instanceName" }}
    {{- end }}
    {{- $localDBCtx := get $.Values.mongo $instanceName }}
    {{- $globalDBCtx := $.Values.global.database.mongo }}
    {{- $type := "mongo" }}
    {{- $dbType := $type | upper}}
    {{- $enabled := $localDBCtx.enabled }}
    {{- $userVariableName := .userVariableName }}
    {{- $passwordVariableName := .passwordVariableName }}
    {{- if and $ $localDBCtx $globalDBCtx }}
        {{- $installed := false }}
        {{- if eq $globalDBCtx.installed true }}
            {{- $installed = $globalDBCtx.installed }}
        {{- end }}
        {{- $userVariableName := default (printf "%s_%s_USER" ($instanceName | upper) $dbType) .userVariableName }}
        {{- $passwordVariableName := default (printf "%s_%s_PASSWORD" ($instanceName | upper) $dbType) .passwordVariableName }}
        {{- $localMongoESOSecretCtxIdentifier := (include "harnesscommon.secrets.localESOSecretCtxIdentifier" (dict "ctx" $ "additionalCtxIdentifier" (printf "%s-%s" $instanceName "mongo") )) }}
        {{- $globalMongoESOSecretIdentifier := (include "harnesscommon.secrets.globalESOSecretCtxIdentifier" (dict "ctx" $ "ctxIdentifier" "mongo" )) }}
        {{- if $installed }}
            {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "MONGO_USER"  "overrideEnvName" $userVariableName "defaultKubernetesSecretName" "harness-secrets" "defaultKubernetesSecretKey" "mongodbUsername" "extKubernetesSecretCtxs" (list $globalDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalMongoESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "MONGO_PASSWORD" "overrideEnvName" $passwordVariableName "defaultKubernetesSecretName" "mongodb-replicaset-chart" "defaultKubernetesSecretKey" "mongodb-root-password" "extKubernetesSecretCtxs" (list $globalDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalMongoESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
        {{- else }}
            {{- if $enabled }}
                {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "MONGO_USER"  "overrideEnvName" $userVariableName "extKubernetesSecretCtxs" (list $localDBCtx.secrets.kubernetesSecrets) "extKubernetesSecretCtxs" (list $localDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $localMongoESOSecretCtxIdentifier "secretCtx" $localDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
                {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "MONGO_PASSWORD" "overrideEnvName" $passwordVariableName "extKubernetesSecretCtxs" (list $localDBCtx.secrets.kubernetesSecrets) "extKubernetesSecretCtxs" (list $localDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $localMongoESOSecretCtxIdentifier "secretCtx" $localDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- else }}
                {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "MONGO_USER"  "overrideEnvName" $userVariableName "defaultKubernetesSecretName" $globalDBCtx.secretName "defaultKubernetesSecretKey" $globalDBCtx.userKey "extKubernetesSecretCtxs" (list $globalDBCtx.secrets.kubernetesSecrets $localDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalMongoESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
                {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "MONGO_PASSWORD" "overrideEnvName" $passwordVariableName "defaultKubernetesSecretName" $globalDBCtx.secretName "defaultKubernetesSecretKey" $globalDBCtx.passwordKey "extKubernetesSecretCtxs" (list $globalDBCtx.secrets.kubernetesSecrets $localDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalMongoESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- end }}
        {{- end }}
    {{- else }}
        {{- fail (printf "invalid input") }}
    {{- end }}
{{- end }}

{{/*
Generates MongoDB environment variables
USAGE:
{{ include "harnesscommon.dbconnectionv2.manageMongoEnv" (dict "ctx" $ "localDBCtx" "userVariableName" "" "passwordVariableName" "" .Values.mongo "globalDBCtx" .Values.global.database.mongo) | indent 12 }}

INPUT ARGUMENTS:
REQUIRED:
1. ctx

OPTIONAL:
1. localDBCtx
   Default: $.Values.mongo
2. globalDBCtx
   Default: $.Values.global.database.mongo
3. userVariableName
   Default: MONGO_USER
4. passwordVariableName
   Default: MONGO_PASSWORD

*/}}
{{- define "harnesscommon.dbconnectionv3.manageMongoEnvs" }}
    {{- $ := .ctx }}
    {{- range $instanceName, $instanceConfig := $.Values.mongo }}
        {{- include "harnesscommon.dbconnectionv3.mongoEnv" (dict "ctx" $ "instanceName" $instanceName)}}
    {{- end }}
{{- end }}

{{- define "harnesscommon.dbconnectionv3.mongoConnection" }}
{{- $ := .ctx }}
{{- $instanceName := .instanceName }}
{{- if empty $instanceName }}
    {{- fail "missing input argument: instanceName" }}
{{- end }}
 {{- $localDBCtx := get $.Values.mongo $instanceName }}
{{- $installed := true }}
{{- if eq $.Values.global.database.mongo.installed false }}
    {{- $installed = false }}
{{- end }}
{{- $userVariableName := printf "%s_MONGO_USER" ($instanceName | upper) }}
{{- $passwordVariableName := printf "%s_MONGO_PASSWORD" ($instanceName | upper) }}
{{- $mongoURI := "" }}
{{- if $installed }}
    {{- $namespace := $.Release.Namespace }}
    {{- if $.Values.global.ha }}
        {{- $mongoURI = printf "'mongodb://$(%s):$(%s)@mongodb-replicaset-chart-0.mongodb-replicaset-chart.%s.svc,mongodb-replicaset-chart-1.mongodb-replicaset-chart.%s.svc,mongodb-replicaset-chart-2.mongodb-replicaset-chart.%s.svc:27017/%s?replicaSet=rs0&authSource=admin'" $userVariableName $passwordVariableName $namespace $namespace $namespace .database }}
    {{- else }}
        {{- $mongoURI = printf "'mongodb://$(%s):$(%s)@mongodb-replicaset-chart-0.mongodb-replicaset-chart.%s.svc/%s?authSource=admin'" $userVariableName $passwordVariableName $namespace $key }}
    {{- end }}
{{- else }}
    {{- $hosts := list }}
    {{- $protocol := "" }}
    {{- $extraArgs := "" }}
    {{- if $value.enabled }}
        {{- $hosts = $localDBCtx.hosts }}
        {{- $protocol = $localDBCtx.protocol }}
        {{- $extraArgs = $localDBCtx.extraArgs }}
    {{- else }}
        {{- $hosts = $.Values.global.database.mongo.hosts }}
        {{- $protocol = $.Values.global.database.mongo.protocol }}
        {{- $extraArgs = $.Values.global.database.mongo.extraArgs }}
    {{- end }}
    {{- $args := (printf "/%s?%s" $key $extraArgs ) -}}
    {{- $mongoURI = include "harnesscommon.dbconnection.connection" (dict "type" "mongo" "hosts" $hosts "protocol" $protocol "extraArgs" $args "userVariableName" $userVariableName "passwordVariableName" $passwordVariableName)}}
{{- end }}
- name: {{printf "%s" $value.connEnvVarName }}
  value: {{printf "%s" $mongoURI }}
{{- end }}

{{- define "harnesscommon.dbconnectionv3.manageMongoConnections" }}
    {{- $ := .ctx }}
    {{- range $instanceName, $instanceConfig := $.Values.mongo }}
        {{- include "harnesscommon.dbconnectionv3.mongoConnection" (dict "ctx" $ "instanceName" $instanceName)}}
    {{- end }}
{{- end }}


{{- define "harnesscommon.dbconnectionv3.manageMongo" }}
    {{- $ := .ctx }}
    {{ include "harnesscommon.dbconnectionv3.manageMongoEnv" (dict "ctx" $ ) }}
    {{ include "harnesscommon.dbconnectionv3.manageMongoEnv" (dict "ctx" $ ) }}
{{- end }}
