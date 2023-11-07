{{/*
Generate InstanceName from database

USAGE:
{{- include "harnesscommon.dbv3.generateInstanceName" (dict "database" "") }}

PARAMETERS:
REQUIRED:
- database: database name

*/}}

{{- define "harnesscommon.dbv3.generateInstanceName" }}
    {{- $database := .database }}
    {{- $instanceName := $database | lower | replace "-" "" }}
    {{- print $instanceName }}
{{- end }}

{{/*
Generate DB Env prefix from instanceName

USAGE:
{{- include "harnesscommon.dbv3.generateDBEnvName" (dict "name" "" "dbType" "" "instanceName" "") }}

PARAMETERS:
REQUIRED:
- instanceName: instance name
- dbType: DB Type

*/}}

{{- define "harnesscommon.dbv3.generateDBEnvName" }}
    {{- $name := .name }}
    {{- if empty $name }}
        {{- fail "ERROR: missing input argument - name" }}
    {{- end }}
    {{- $dbType := .dbType }}
    {{- if empty $dbType }}
        {{- fail "ERROR: missing input argument - dbType" }}
    {{- end }}
    {{- $instanceName := .instanceName }}
    {{- if empty $instanceName }}
        {{- fail "ERROR: missing input argument - instanceName" }}
    {{- end }}
    {{- printf "%s_%s_%s" (upper $instanceName) (upper $dbType) (upper $name) }}
{{- end }}

{{/*
Generate DB ESO Context Identifier 

USAGE:
{{- include "harnesscommon.dbv3.esoSecretCtxIdentifier" (dict "ctx" $ "dbType" "mongo" "scope" "" "instanceName" "") }}

PARAMETERS:
- ctx: Context
- dbType: DB Type. Allowed values: mongo, timescaledb
- scope: Scope of ESO Secret Context Identifier. Allowed Values: "local", "global"
- instanceName: Name of the DB Instance. Required only when "scope" if "local"

*/}}
{{- define "harnesscommon.dbv3.esoSecretCtxIdentifier" }}
    {{- $ := .ctx }}
    {{- $dbTypeAllowedValues := dict "mongo" "" "timescaledb" "" }}
    {{- $dbType := .dbType }}
    {{- if not (hasKey $dbTypeAllowedValues $dbType) }}
        {{- $errMsg := printf "ERROR: invalid value %s for input argument dbType" $dbType }}
        {{- fail $errMsg }}
    {{- end }}
    {{- $scope := .scope -}}
    {{- $esoSecretCtxIdentifier := "" }}
    {{- if eq $scope "local" }}
        {{- $instanceName := .instanceName }}
        {{- if empty $instanceName }}
            {{- fail "ERROR: missing input argument - instanceName" }}
        {{- end }}
        {{- $instanceName =  lower $instanceName }}
        {{- $esoSecretCtxIdentifier = (include "harnesscommon.secrets.localESOSecretCtxIdentifier" (dict "ctx" $ "additionalCtxIdentifier" (printf "%s-%s" $instanceName $dbType) )) }}
    {{- else if eq $scope "global" }}
        {{- $esoSecretCtxIdentifier = (include "harnesscommon.secrets.globalESOSecretCtxIdentifier" (dict "ctx" $ "ctxIdentifier" $dbType )) }}
    {{- else }}
        {{- $errMsg := printf "ERROR: invalid value %s for input argument scope" $scope }}
        {{- fail $errMsg }}
    {{- end }}
    {{- printf "%s" $esoSecretCtxIdentifier }}
{{- end }}

{{/*
Generate K8S Env Spec for MongoDB Environment Variables

USAGE:
{{- include "harnesscommon.dbv3.mongoEnv" (dict "ctx" $ "database" "harness") | indent 12 }}

PARAMETERS:
REQUIRED:
1. ctx
2. database

OPTIONAL:
1. userVariableName
2. passwordVariableName

*/}}
{{- define "harnesscommon.dbv3.mongoEnv" }}
    {{- $ := .ctx }}
    {{- $dbType := "mongo" }}
    {{- $database := .database }}
    {{- if empty $database }}
        {{- fail "ERROR: missing input argument - database" }}
    {{- end }}
    {{- $instanceName := include "harnesscommon.dbv3.generateInstanceName" (dict "database" $database) }}
    {{- if empty $instanceName }}
        {{- fail "ERROR: invalid instanceName value" }}
    {{- end }}
    {{- $localDBCtx := get $.Values.mongo $instanceName }}
    {{- $globalDBCtx := $.Values.global.database.mongo }}
    {{- if and $ $localDBCtx $globalDBCtx }}
        {{- $userNameEnvName := default (include "harnesscommon.dbv3.generateDBEnvName" (dict "name" "USER" "dbType" $dbType "instanceName" $instanceName)) .userVariableName }}
        {{- $passwordEnvName := default (include "harnesscommon.dbv3.generateDBEnvName" (dict "name" "PASSWORD" "dbType" $dbType "instanceName" $instanceName)) .passwordVariableName }}
        {{- $localEnabled := dig "enabled" false $localDBCtx }}
        {{- $installed := dig "installed" true $globalDBCtx }}
        {{- $globalDBESOSecretIdentifier := include "harnesscommon.dbv3.esoSecretCtxIdentifier" (dict "ctx" $ "dbType" $dbType "scope" "global") }}
        {{- $localDBESOSecretCtxIdentifier := include "harnesscommon.dbv3.esoSecretCtxIdentifier" (dict "ctx" $ "dbType" $dbType "scope" "local" "instanceName" $instanceName) }}
        {{- if $userNameEnvName }}
            {{- if $localEnabled }}
                {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "MONGO_USER"  "overrideEnvName" $userNameEnvName "extKubernetesSecretCtxs" (list $localDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $localDBESOSecretCtxIdentifier "secretCtx" $localDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- else if $installed }}
                {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "MONGO_USER"  "overrideEnvName" $userNameEnvName "defaultKubernetesSecretName" "harness-secrets" "defaultKubernetesSecretKey" "mongodbUsername" "extKubernetesSecretCtxs" (list $globalDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalDBESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- else }}
                {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "MONGO_USER"  "overrideEnvName" $userNameEnvName "defaultKubernetesSecretName" $globalDBCtx.secretName "defaultKubernetesSecretKey" $globalDBCtx.userKey "extKubernetesSecretCtxs" (list $globalDBCtx.secrets.kubernetesSecrets $localDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalDBESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- end }}
        {{- end }}
        {{- if $passwordEnvName }}
            {{- if $localEnabled }}
                {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "MONGO_PASSWORD" "overrideEnvName" $passwordEnvName "extKubernetesSecretCtxs" (list $localDBCtx.secrets.kubernetesSecrets) "extKubernetesSecretCtxs" (list $localDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $localDBESOSecretCtxIdentifier "secretCtx" $localDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- else if $installed }}
                {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "MONGO_PASSWORD" "overrideEnvName" $passwordEnvName "defaultKubernetesSecretName" "mongodb-replicaset-chart" "defaultKubernetesSecretKey" "mongodb-root-password" "extKubernetesSecretCtxs" (list $globalDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalDBESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- else }}
                {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "MONGO_PASSWORD" "overrideEnvName" $passwordEnvName "defaultKubernetesSecretName" $globalDBCtx.secretName "defaultKubernetesSecretKey" $globalDBCtx.passwordKey "extKubernetesSecretCtxs" (list $globalDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalDBESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- end }}
        {{- end }}
    {{- else }}
        {{- fail (printf "ERROR: invalid contexts") }}
    {{- end }}
{{- end }}

{{/*
Generate K8S Env Spec for MongoDB Connection Environment Variables

USAGE:
{{ include "harnesscommon.dbv3.mongoConnectionEnv" (dict "ctx" $ "instanceName" "harness") | indent 12 }}

PARAMETERS:
REQUIRED:
1. ctx
2. database

OPTIONAL:
1. userVariableName
2. passwordVariableName
3. connectionURIVariableName

*/}}
{{- define "harnesscommon.dbv3.mongoConnectionEnv" }}
    {{- $ := .ctx }}
    {{- $database := .database }}
    {{- if empty $database }}
        {{- fail "ERROR: missing input argument - database" }}
    {{- end }}
    {{- $instanceName := include "harnesscommon.dbv3.generateInstanceName" (dict "database" $database) }}
    {{- if empty $instanceName }}
        {{- fail "ERROR: invalid instanceName value" }}
    {{- end }}
    {{- $localDBCtx := get $.Values.mongo $instanceName }}
    {{- $globalDBCtx := $.Values.global.database.mongo }}
    {{- if and $ $localDBCtx $globalDBCtx }}
        {{- $userNameEnvName := default (include "harnesscommon.dbv3.generateDBEnvName" (dict "name" "USER" "dbType" "mongo" "instanceName" $instanceName)) .userVariableName }}
        {{- $passwordEnvName := default (include "harnesscommon.dbv3.generateDBEnvName" (dict "name" "PASSWORD" "dbType" "mongo" "instanceName" $instanceName)) .passwordVariableName }}
        {{- $connectionURIEnvName := default (include "harnesscommon.dbv3.generateDBEnvName" (dict "name" "URI" "dbType" "mongo" "instanceName" $instanceName)) .connectionURIVariableName }}
        {{- $localEnabled := dig "enabled" false $localDBCtx }}
        {{- $installed := dig "installed" true $globalDBCtx }}
        {{- $connectionURI := "" }}
        {{- if $connectionURIEnvName }}
            {{- if $localEnabled }}
                {{- $hosts := $localDBCtx.hosts }}
                {{- $protocol := $localDBCtx.protocol }}
                {{- $extraArgs := $localDBCtx.extraArgs }}
                {{- $args := (printf "/%s?%s" $database $extraArgs ) -}}
                {{- $connectionURI = include "harnesscommon.dbconnection.connection" (dict "type" "mongo" "hosts" $hosts "protocol" $protocol "extraArgs" $args "userVariableName" $userNameEnvName "passwordVariableName" $passwordEnvName)}}
            {{- else if $installed }}
                {{- $namespace := $.Release.Namespace }}
                {{- if $.Values.global.ha }}
                    {{- $connectionURI = printf "'mongodb://$(%s):$(%s)@mongodb-replicaset-chart-0.mongodb-replicaset-chart.%s.svc,mongodb-replicaset-chart-1.mongodb-replicaset-chart.%s.svc,mongodb-replicaset-chart-2.mongodb-replicaset-chart.%s.svc:27017/%s?replicaSet=rs0&authSource=admin'" $userNameEnvName $passwordEnvName $namespace $namespace $namespace $database }}
                {{- else }}
                    {{- $connectionURI = printf "'mongodb://$(%s):$(%s)@mongodb-replicaset-chart-0.mongodb-replicaset-chart.%s.svc/%s?authSource=admin'" $userNameEnvName $passwordEnvName $namespace $database }}
                {{- end }}
            {{- else }}
                {{- $hosts := $globalDBCtx.hosts }}
                {{- $protocol := $globalDBCtx.protocol }}
                {{- $extraArgs := $globalDBCtx.extraArgs }}
                {{- $args := (printf "/%s?%s" $database $extraArgs ) -}}
                {{- $connectionURI = include "harnesscommon.dbconnection.connection" (dict "type" "mongo" "hosts" $hosts "protocol" $protocol "extraArgs" $args "userVariableName" $userNameEnvName "passwordVariableName" $passwordEnvName)}}
            {{- end }}
- name: {{ printf "%s" $connectionURIEnvName }}
  value: {{ printf "%s" $connectionURI }}
        {{- end }}
    {{- else }}
        {{- fail (printf "ERROR: invalid contexts") }}
    {{- end }}
{{- end }}

{{/*
Generate K8S Env Spec for MongoDB

USAGE:
{{- include "harnesscommon.dbv3.manageMongoEnv" (dict "ctx" $ "database" "") | indent 12 }}

PARAMETERS:
REQUIRED:
1. ctx
2. database

*/}}
{{- define "harnesscommon.dbv3.manageMongoEnv" }}
    {{- $ := .ctx }}
    {{- $params := (dict "ctx" $ "database" .database "userVariableName" .userVariableName "passwordVariableName" .passwordVariableName "connectionURIVariableName" .connectionURIVariableName) }}
    {{- include "harnesscommon.dbv3.mongoEnv" $params }}
    {{- include "harnesscommon.dbv3.mongoConnectionEnv" $params }}
{{- end }}

{{/*
Generate External Secret CRDs for Mongo DBs

USAGE:
{{- include "harnesscommon.dbv3.manageMongoExternalSecret" (dict "ctx" $) | indent 12 }}

PARAMETERS:
REQUIRED:
1. ctx

*/}}
{{- define "harnesscommon.dbv3.generateLocalMongoExternalSecret" }}
    {{- $ := .ctx }}
    {{- range $instanceName, $instance := $.Values.mongo }}
        {{- $localDBCtx := get $.Values.mongo $instanceName }}
        {{- $localEnabled := dig "enabled" false $localDBCtx }}
        {{- if and $localEnabled (eq (include "harnesscommon.secrets.hasESOSecrets" (dict "secretsCtx" $localDBCtx.secrets)) "true") }}
            {{- $localMongoESOSecretCtxIdentifier := include "harnesscommon.dbv3.mongoESOSecretCtxIdentifier" (dict "ctx" $ "scope" "local" "instanceName" $instanceName) }}
            {{- include "harnesscommon.secrets.generateExternalSecret" (dict "secretsCtx" $localDBCtx.secrets "secretNamePrefix" $localMongoESOSecretCtxIdentifier) }}
            {{- print "\n---" }}
        {{- end }}
    {{- end }}
{{- end }}

{{/*
Generate K8S Env Spec for TimescaleDB Environment Variables

USAGE:
{{- include "harnesscommon.dbv3.timescaleEnv" (dict "ctx" $ "instanceName" "harness") | indent 12 }}

PARAMETERS:
REQUIRED:
1. ctx
2. database

OPTIONAL:
- userVariableName
- passwordVariableName
- sslModeVariableName
- sslModeValue
- handleSSLModeDisable
- certVariableName 
- certPathVariableName
- certPathValue

*/}}
{{- define "harnesscommon.dbv3.timescaleEnv" }}
    {{- $ := .ctx }}
    {{- $dbType := "timescaledb" }}
    {{- $database := .database }}
    {{- if empty $database }}
        {{- fail "ERROR: missing input argument - database" }}
    {{- end }}
    {{- $instanceName := include "harnesscommon.dbv3.generateInstanceName" (dict "database" $database) }}
    {{- if empty $instanceName }}
        {{- fail "ERROR: invalid instanceName value" }}
    {{- end }}
    {{- $localDBCtx := get $.Values.timescaledb $instanceName }}
    {{- $globalDBCtx := $.Values.global.database.timescaledb }}
    {{- if and $ $localDBCtx $globalDBCtx }}
        {{- $userNameEnvName := default (include "harnesscommon.dbv3.generateDBEnvName" (dict "name" "USERNAME" "dbType" $dbType "instanceName" $instanceName)) .userVariableName }}
        {{- $passwordEnvName := default (include "harnesscommon.dbv3.generateDBEnvName" (dict "name" "PASSWORD" "dbType" $dbType "instanceName" $instanceName)) .passwordVariableName }}
        {{- $certEnvName := default (include "harnesscommon.dbv3.generateDBEnvName" (dict "name" "SSL_ROOT_CERT" "dbType" $dbType "instanceName" $instanceName)) .certVariableName }}
        {{- $enableSSLEnvName := default "" .enableSslVariableName }}
        {{- $sslModeEnvName := default (include "harnesscommon.dbv3.generateDBEnvName" (dict "name" "SSL_MODE" "dbType" $dbType "instanceName" $instanceName)) .sslModeVariableName }}
        {{- $handleSSLModeDisable := default false .handleSSLModeDisable }}
        {{- $certPathEnvName := default (include "harnesscommon.dbv3.generateDBEnvName" (dict "name" "SSL_CERT_PATH" "dbType" $dbType "instanceName" $instanceName)) .certPathVariableName }}
        {{- $localEnabled := dig "enabled" false $localDBCtx }}
        {{- $installed := dig "installed" true $globalDBCtx }}
        {{- $globalDBESOSecretIdentifier := include "harnesscommon.dbv3.esoSecretCtxIdentifier" (dict "ctx" $ "dbType" $dbType "scope" "global") }}
        {{- $localDBESOSecretCtxIdentifier := include "harnesscommon.dbv3.esoSecretCtxIdentifier" (dict "ctx" $ "dbType" $dbType "scope" "local" "instanceName" $instanceName) }}
        {{- $sslEnabled := false }}
        {{- $certEnv := "" }}
        {{- if $localEnabled }}
            {{- if $userNameEnvName }}
                {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "TIMESCALEDB_USERNAME"  "overrideEnvName" $userNameEnvName "extKubernetesSecretCtxs" (list $localDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $localDBESOSecretCtxIdentifier "secretCtx" $localDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- end }}
            {{- if $passwordEnvName }}
                {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "TIMESCALEDB_PASSWORD" "overrideEnvName" $passwordEnvName "extKubernetesSecretCtxs" (list $localDBCtx.secrets.kubernetesSecrets) "extKubernetesSecretCtxs" (list $localDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $localDBESOSecretCtxIdentifier "secretCtx" $localDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- end }}
            {{- $sslEnabled = dig "sslEnabled" false $localDBCtx }}
            {{- if $sslEnabled }}
                {{- if $certEnvName }}
                    {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "TIMESCALEDB_SSL_ROOT_CERT" "overrideEnvName" $certEnvName "extKubernetesSecretCtxs" (list $localDBCtx.secrets.kubernetesSecrets) "extKubernetesSecretCtxs" (list $localDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $localDBESOSecretCtxIdentifier "secretCtx" $localDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
                {{- end }}
            {{- end }}
        {{- else if $installed }}
            {{- if $userNameEnvName }}
                {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "TIMESCALEDB_USERNAME" "overrideEnvName" $userNameEnvName "defaultValue" "postgres" "extKubernetesSecretCtxs" (list $globalDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalDBESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- end }}
            {{- if $passwordEnvName }}
                {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "TIMESCALEDB_PASSWORD" "overrideEnvName" $passwordEnvName "defaultKubernetesSecretName" "harness-secrets" "defaultKubernetesSecretKey" "timescaledbPostgresPassword" "extKubernetesSecretCtxs" (list $globalDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalDBESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- end }}
            {{- $sslEnabled = dig "sslEnabled" false $globalDBCtx }}
            {{- if $sslEnabled }}
                {{- if $certEnvName }}
                    {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "TIMESCALEDB_SSL_ROOT_CERT" "overrideEnvName" $certEnvName "extKubernetesSecretCtxs" (list $globalDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalDBESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
                {{- end }}
            {{- end }}
        {{- else }}
            {{- if $userNameEnvName }}
                {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "TIMESCALEDB_USERNAME" "overrideEnvName" $userNameEnvName "defaultKubernetesSecretName" $globalDBCtx.secretName "defaultKubernetesSecretKey" $globalDBCtx.userKey "extKubernetesSecretCtxs" (list $globalDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalDBESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- end }}
            {{- if $passwordEnvName }}
                {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "TIMESCALEDB_PASSWORD" "overrideEnvName" $passwordEnvName "defaultKubernetesSecretName" $globalDBCtx.secretName "defaultKubernetesSecretKey" $globalDBCtx.passwordKey "extKubernetesSecretCtxs" (list $globalDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalDBESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- end }}
            {{- $sslEnabled = dig "sslEnabled" false $globalDBCtx }}
            {{- if $sslEnabled }}
                {{- if $certEnvName }}
                    {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "TIMESCALEDB_SSL_ROOT_CERT" "overrideEnvName" $certEnvName "defaultKubernetesSecretName" $globalDBCtx.certName "defaultKubernetesSecretKey" $globalDBCtx.certKey "extKubernetesSecretCtxs" (list $globalDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalDBESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
                {{- end }}
            {{- end }}
        {{- end }}
        {{- if $enableSSLEnvName }}
            {{- if $sslEnabled }}
- name: {{ print $enableSSLEnvName }}
  value: "true"
            {{- end }}
        {{- end }}
        {{- if $sslModeEnvName }}
            {{- $sslModeValue := "" }}
            {{- if $sslEnabled }}
                {{- $sslModeValue = default "require" .sslModeValue }}
            {{- else if $handleSSLModeDisable }}
                {{- $sslModeValue = "disable" }}
            {{- end }}
            {{- if $sslModeValue }}
- name: {{ print $sslModeEnvName }}
  value: {{ print $sslModeValue }}
            {{- end }}
        {{- end }}
        {{- if $certPathEnvName }}
            {{- $certPathValue := default "" .certPathValue }}
            {{- if $certPathValue }}
- name: {{ print $certPathEnvName }}
  value: {{ print $certPathValue }}
            {{- end }}
        {{- end }}
    {{- else }}
        {{- fail (printf "ERROR: invalid contexts") }}
    {{- end }}
{{- end }}

{{/*
Generate TimescaleDB Host

USAGE:
{{- include "harnesscommon.dbv3.timescaleHost" (dict "ctx" $ "database" "") | indent 12 }}

PARAMETERS:
REQUIRED:
1. ctx
2. database

*/}}
{{- define "harnesscommon.dbv3.timescaleHost" }}
    {{- $ := .ctx }}
    {{- $dbType := "timescaledb" }}
    {{- $database := .database }}
    {{- if empty $database }}
        {{- fail "ERROR: missing input argument - database" }}
    {{- end }}
    {{- $instanceName := include "harnesscommon.dbv3.generateInstanceName" (dict "database" $database) }}
    {{- if empty $instanceName }}
        {{- fail "ERROR: invalid instanceName value" }}
    {{- end }}
    {{- $localDBCtx := get $.Values.timescaledb $instanceName }}
    {{- $globalDBCtx := $.Values.global.database.timescaledb }}
    {{- if and $ $localDBCtx $globalDBCtx }}
        {{- $localEnabled := dig "enabled" false $localDBCtx }}
        {{- $installed := dig "installed" true $globalDBCtx }}
        {{- if $localEnabled }}
            {{- $hosts := dig "hosts" list $localDBCtx }}
            {{- printf "%s"  (split ":" (index $hosts 0))._0 }}
        {{- else if $installed }}
            {{- printf "%s.%s" "timescaledb-single-chart" $.Release.Namespace }}
        {{- else }}
            {{- $hosts := dig "hosts" list $globalDBCtx }}
            {{- printf "%s"  (split ":" (index $hosts 0))._0 }}
        {{- end }}
    {{- else }}
        {{- fail (printf "ERROR: invalid contexts") }}
    {{- end }}
{{- end }}

{{/*
Generate TimescaleDB Port

USAGE:
{{- include "harnesscommon.dbv3.timescalePort" (dict "ctx" $ "database" "") | indent 12 }}

PARAMETERS:
REQUIRED:
1. ctx
2. database

*/}}
{{- define "harnesscommon.dbv3.timescalePort" }}
    {{- $ := .ctx }}
    {{- $dbType := "timescaledb" }}
    {{- $database := .database }}
    {{- if empty $database }}
        {{- fail "ERROR: missing input argument - database" }}
    {{- end }}
    {{- $instanceName := include "harnesscommon.dbv3.generateInstanceName" (dict "database" $database) }}
    {{- if empty $instanceName }}
        {{- fail "ERROR: invalid instanceName value" }}
    {{- end }}
    {{- $localDBCtx := get $.Values.timescaledb $instanceName }}
    {{- $globalDBCtx := $.Values.global.database.timescaledb }}
    {{- if and $ $localDBCtx $globalDBCtx }}
        {{- $localEnabled := dig "enabled" false $localDBCtx }}
        {{- $installed := dig "installed" true $globalDBCtx }}
        {{- if $localEnabled }}
            {{- $hosts := dig "hosts" list $localDBCtx }}
            {{- printf "%s"  (split ":" (index $hosts 0))._1 }}
        {{- else if $installed }}
            {{- printf "%s" "5432" }}
        {{- else }}
            {{- $hosts := dig "hosts" list $localDBCtx }}
            {{- printf "%s"  (split ":" (index $hosts 0))._1 }}
        {{- end }}
    {{- else }}
        {{- fail (printf "ERROR: invalid contexts") }}
    {{- end }}
{{- end }}

{{/*
Generate K8S Env Spec for TimescaleDB Connection Environment Variables

USAGE:
{{ include "harnesscommon.dbv3.timescaleConnectionEnv" (dict "ctx" $ "database" "foo" "args" "bar" "addSSLModeArg" false) }}

PARAMETERS:
REQUIRED:
- ctx
- database

OPTIONAL:
- protocol
- userVariableName
- passwordVariableName
- connectionURIVariableName
- args
- addSSLModeArg

*/}}
{{- define "harnesscommon.dbv3.timescaleConnectionEnv" }}
    {{- $ := .ctx }}
    {{- $dbType := "timescaledb" }}
    {{- $database := .database }}
    {{- if empty $database }}
        {{- fail "ERROR: missing input argument - database" }}
    {{- end }}
    {{- $instanceName := include "harnesscommon.dbv3.generateInstanceName" (dict "database" $database) }}
    {{- if empty $instanceName }}
        {{- fail "ERROR: invalid instanceName value" }}
    {{- end }}
    {{- $localDBCtx := get $.Values.timescaledb $instanceName }}
    {{- $globalDBCtx := $.Values.global.database.timescaledb }}
    {{- if and $ $localDBCtx $globalDBCtx }}
        {{- $connectionString := "" }}
        {{- $host := include "harnesscommon.dbv3.timescaleHost" (dict "ctx" .ctx "database" $database) }}
        {{- $port := include "harnesscommon.dbv3.timescalePort" (dict "ctx" .ctx "database" $database) }}
        {{- $localEnabled := dig "enabled" false $localDBCtx }}
        {{- $installed := dig "installed" true $globalDBCtx }}
        {{- $connectionURIEnvName := default (include "harnesscommon.dbv3.generateDBEnvName" (dict "name" "URI" "dbType" $dbType "instanceName" $instanceName)) .connectionURIVariableName }}
        {{- $sslEnabled := false }}
        {{- $protocol := default "" .protocol }}
        {{- $addSSLModeArg := default false .addSSLModeArg }}
        {{- if $localEnabled }}
            {{- $sslEnabled = dig "sslEnabled" false $localDBCtx }}
        {{- else if $installed }}
            {{- $sslEnabled = dig "sslEnabled" false $globalDBCtx }}
        {{- else }}
            {{- $sslEnabled = dig "sslEnabled" false $globalDBCtx }}
        {{- end }}
        {{- if not (empty $protocol) }}
            {{- $protocol = (printf "%s://" $protocol) }}
        {{- end }}
        {{- $userAndPassField := "" }}
        {{- if and (.userVariableName) (.passwordVariableName) }}
            {{- $userAndPassField = (printf "$(%s):$(%s)@" .userVariableName .passwordVariableName) }}
        {{- end }}
        {{- $connectionString = (printf "%s%s%s:%s/%s" $protocol $userAndPassField  $host $port  $database) }}
        {{- if .args }}
            {{- if $addSSLModeArg }}
                {{- if $sslEnabled }}
                    {{- $connectionString = (printf "%s?%s&%s" $connectionString .args "sslmode=require") }}
                {{- else }}
                    {{- $connectionString = (printf "%s?%s&%s" $connectionString .args "sslmode=disable") }}
                {{- end }}
            {{- else }}    
                {{- $connectionString = (printf "%s?%s" $connectionString .args) }}
            {{- end }}
        {{- else }}
            {{- if $addSSLModeArg }}
                {{- if $sslEnabled }}
                    {{- $connectionString = (printf "%s?%s" $connectionString "sslmode=require") }}
                {{- else }}
                    {{- $connectionString = (printf "%s?%s" $connectionString "sslmode=disable") }}
                {{- end }}
            {{- end }}
        {{- end }}
        {{- if $connectionString }}
- name: {{ $connectionURIEnvName }}
  value: {{ printf "%s" $connectionString }}
        {{- end }}
    {{- else }}
        {{- fail (printf "ERROR: invalid contexts") }}
    {{- end }}
{{- end }}

{{/*
Generate K8S Env Spec for all TimescaleDB Environment Variables

USAGE:
{{- include "harnesscommon.dbv3.manageTimescaleDBEnv" (dict "ctx" $) | indent 12 }}

PARAMETERS:
REQUIRED:
1. ctx

*/}}
{{- define "harnesscommon.dbv3.manageTimescaleDBEnv" }}
    {{- $ := .ctx }}
    {{- $params := (dict "ctx" $ "database" .database "userVariableName" .userVariableName "passwordVariableName" .passwordVariableName "sslModeVariableName" .sslModeVariableName "sslModeValue" .sslModeValue "handleSSLModeDisable" .handleSSLModeDisable "certVariableName" .certVariableName "certPathVariableName" .certPathVariableName "certPathValue" .certPathValue "connectionURIVariableName" .connectionURIVariableName "protocol" .protocol "args" .args "addSSLModeArg" .addSSLModeArg) }}
    {{- include "harnesscommon.dbv3.timescaleEnv" $params }}
    {{- include "harnesscommon.dbv3.timescaleConnectionEnv" $params }}
{{- end }}
