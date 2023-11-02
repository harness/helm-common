{{/*
Generate Mongo ESO Context Identifier 

USAGE:
{{- include "harnesscommon.dbv3.mongoESOSecretCtxIdentifier" (dict "ctx" $ "scope" "" "instanceName" "") }}

PARAMETERS:
- ctx: Context
- scope: Scope of ESO Secret Context Identifier. Allowed Values: "local", "global"
- instanceName: Name of the Mongo DB Instance. Required only when "scope" if "local"

*/}}
{{- define "harnesscommon.dbv3.mongoESOSecretCtxIdentifier" }}
    {{- $ := .ctx }}
    {{- $scope := .scope -}}
    {{- $mongoESOSecretCtxIdentifier := "" }}
    {{- if eq $scope "local" }}
        {{- $instanceName := .instanceName }}
        {{- if empty $instanceName }}
            {{- fail "ERROR: missing input argument - instanceName" }}
        {{- end }}
        {{- $instanceName =  lower $instanceName }}
        {{- $mongoESOSecretCtxIdentifier = (include "harnesscommon.secrets.localESOSecretCtxIdentifier" (dict "ctx" $ "additionalCtxIdentifier" (printf "%s-%s" $instanceName "mongo") )) }}
    {{- else if eq $scope "global" }}
        {{- $mongoESOSecretCtxIdentifier = (include "harnesscommon.secrets.globalESOSecretCtxIdentifier" (dict "ctx" $ "ctxIdentifier" "mongo" )) }}
    {{- else }}
        {{- $errMsg := printf "ERROR: invalid value %s for input argument scope" $scope }}
        {{- fail $errMsg }}
    {{- end }}
    {{- printf "%s" $mongoESOSecretCtxIdentifier }}
{{- end }}

{{/*
Generate K8S Env Spec for MongoDB Environment Variables

USAGE:
{{- include "harnesscommon.dbv3.mongoEnv" (dict "ctx" $ "instanceName" "harness") | indent 12 }}

PARAMETERS:
REQUIRED:
1. ctx
2. instanceName

*/}}
{{- define "harnesscommon.dbv3.mongoEnv" }}
    {{- $ := .ctx }}
    {{- $instanceName := .instanceName }}
    {{- if empty $instanceName }}
        {{- fail "ERROR: missing input argument - instanceName" }}
    {{- end }}
    {{- $localDBCtx := get $.Values.mongo $instanceName }}
    {{- $globalDBCtx := $.Values.global.database.mongo }}
    {{- if and $ $localDBCtx $globalDBCtx }}
        {{- $userNameEnvName := dig "envConfig" "username" "envName" "" $localDBCtx }}
        {{- $passwordEnvName := dig "envConfig" "password" "envName" "" $localDBCtx }}
        {{- $localEnabled := dig "enabled" false $localDBCtx }}
        {{- $installed := dig "installed" true $globalDBCtx }}
        {{- $globalMongoESOSecretIdentifier := include "harnesscommon.dbv3.mongoESOSecretCtxIdentifier" (dict "ctx" $ "scope" "global") }}
        {{- $localMongoESOSecretCtxIdentifier := include "harnesscommon.dbv3.mongoESOSecretCtxIdentifier" (dict "ctx" $ "scope" "local" "instanceName" $instanceName) }}
        {{- if $userNameEnvName }}
            {{- if $localEnabled }}
                {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "MONGO_USER"  "overrideEnvName" $userNameEnvName "extKubernetesSecretCtxs" (list $localDBCtx.secrets.kubernetesSecrets) "extKubernetesSecretCtxs" (list $localDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $localMongoESOSecretCtxIdentifier "secretCtx" $localDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- else if $installed }}
                {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "MONGO_USER"  "overrideEnvName" $userNameEnvName "defaultKubernetesSecretName" "harness-secrets" "defaultKubernetesSecretKey" "mongodbUsername" "extKubernetesSecretCtxs" (list $globalDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalMongoESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- else }}
                {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "MONGO_USER"  "overrideEnvName" $userNameEnvName "defaultKubernetesSecretName" $globalDBCtx.secretName "defaultKubernetesSecretKey" $globalDBCtx.userKey "extKubernetesSecretCtxs" (list $globalDBCtx.secrets.kubernetesSecrets $localDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalMongoESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- end }}
        {{- end }}
        {{- if $passwordEnvName }}
            {{- if $localEnabled }}
                {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "MONGO_PASSWORD" "overrideEnvName" $passwordEnvName "extKubernetesSecretCtxs" (list $localDBCtx.secrets.kubernetesSecrets) "extKubernetesSecretCtxs" (list $localDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $localMongoESOSecretCtxIdentifier "secretCtx" $localDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- else if $installed }}
                {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "MONGO_PASSWORD" "overrideEnvName" $passwordEnvName "defaultKubernetesSecretName" "mongodb-replicaset-chart" "defaultKubernetesSecretKey" "mongodb-root-password" "extKubernetesSecretCtxs" (list $globalDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalMongoESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- else }}
                {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "MONGO_PASSWORD" "overrideEnvName" $passwordEnvName "defaultKubernetesSecretName" $globalDBCtx.secretName "defaultKubernetesSecretKey" $globalDBCtx.passwordKey "extKubernetesSecretCtxs" (list $globalDBCtx.secrets.kubernetesSecrets $localDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalMongoESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
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
2. instanceName

*/}}
{{- define "harnesscommon.dbv3.mongoConnectionEnv" }}
    {{- $ := .ctx }}
    {{- $instanceName := .instanceName }}
    {{- if empty $instanceName }}
        {{- fail "ERROR: missing input argument - instanceName" }}
    {{- end }}
    {{- $localDBCtx := get $.Values.mongo $instanceName }}
    {{- $globalDBCtx := $.Values.global.database.mongo }}
    {{- $database := dig "database" "" $localDBCtx }}
    {{- if and $ $localDBCtx $globalDBCtx $database }}
        {{- $userNameEnvName := dig "envConfig" "username" "envName" "" $localDBCtx }}
        {{- $passwordEnvName := dig "envConfig" "password" "envName" "" $localDBCtx }}
        {{- $connectionURIEnvName := dig "envConfig" "connectionURI" "envName" "" $localDBCtx }}
        {{- $localEnabled := dig "enabled" false $localDBCtx }}
        {{- $installed := dig "installed" true $globalDBCtx }}
        {{- $connectionURI := "" }}
        {{- if $connectionURIEnvName }}
            {{- if not $installed }}
                {{- $hosts := list }}
                {{- $protocol := "" }}
                {{- $extraArgs := "" }}
                {{- if $localEnabled }}
                    {{- $hosts = $localDBCtx.hosts }}
                    {{- $protocol = $localDBCtx.protocol }}
                    {{- $extraArgs = $localDBCtx.extraArgs }}
                {{- else }}
                    {{- $hosts = $globalDBCtx.hosts }}
                    {{- $protocol = $globalDBCtx.protocol }}
                    {{- $extraArgs = $globalDBCtx.extraArgs }}
                {{- end }}
                {{- $args := (printf "/%s?%s" $database $extraArgs ) -}}
                {{- $connectionURI = include "harnesscommon.dbconnection.connection" (dict "type" "mongo" "hosts" $hosts "protocol" $protocol "extraArgs" $args "userVariableName" $userNameEnvName "passwordVariableName" $passwordEnvName)}}
            {{- else }}
                {{- $namespace := $.Release.Namespace }}
                {{- if $.Values.global.ha }}
                    {{- $connectionURI = printf "'mongodb://$(%s):$(%s)@mongodb-replicaset-chart-0.mongodb-replicaset-chart.%s.svc,mongodb-replicaset-chart-1.mongodb-replicaset-chart.%s.svc,mongodb-replicaset-chart-2.mongodb-replicaset-chart.%s.svc:27017/%s?replicaSet=rs0&authSource=admin'" $userNameEnvName $passwordEnvName $namespace $namespace $namespace $database }}
                {{- else }}
                    {{- $connectionURI = printf "'mongodb://$(%s):$(%s)@mongodb-replicaset-chart-0.mongodb-replicaset-chart.%s.svc/%s?authSource=admin'" $userNameEnvName $passwordEnvName $namespace $database }}
                {{- end }}
            {{- end }}
- name: {{ printf "%s" $connectionURIEnvName }}
  value: {{ printf "%s" $connectionURI }}
        {{- end }}
    {{- else }}
        {{- fail (printf "ERROR: invalid contexts") }}
    {{- end }}
{{- end }}

{{/*
Generate K8S Env Spec for all MongoDB Environment Variables

USAGE:
{{- include "harnesscommon.dbv3.manageMongoEnvs" (dict "ctx" $) | indent 12 }}

PARAMETERS:
REQUIRED:
1. ctx

*/}}
{{- define "harnesscommon.dbv3.manageMongoEnvs" }}
    {{- $ := .ctx }}
    {{- range $instanceName, $instance := $.Values.mongo }}
        {{- include "harnesscommon.dbv3.mongoEnv" (dict "ctx" $ "instanceName" $instanceName)}}
        {{- include "harnesscommon.dbv3.mongoConnectionEnv" (dict "ctx" $ "instanceName" $instanceName)}}
    {{- end }}
{{- end }}

{{/*
Generate K8S Env Spec for all DB related Environment Variables

USAGE:
{{- include "harnesscommon.dbv3.manageEnvs" (dict "ctx" $) | indent 12 }}

PARAMETERS:
REQUIRED:
1. ctx

*/}}
{{- define "harnesscommon.dbv3.manageEnvs" }}
    {{- $ := .ctx }}
    {{- include "harnesscommon.dbv3.manageMongoEnvs" (dict "ctx" $) }}
{{- end }}
