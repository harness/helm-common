{{/*
Generates SMTP environment variables

USAGE:
{{ include "harnesscommon.secrets.manageSMTPEnv" (dict "ctx" $) | indent 12 }}
*/}}
{{- define "harnesscommon.secrets.manageSMTPEnv" }}
    {{- $ := .ctx }}
    {{- if $.Values.global.smtpCreateSecret.enabled }}
        {{- $globalSMTPESOSecretIdentifier := include "harnesscommon.secrets.globalESOSecretCtxIdentifier" (dict "ctx" $  "ctxIdentifier" "smtp") }}
        {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "SMTP_USERNAME" "defaultKubernetesSecretName" "smtp-secret" "defaultKubernetesSecretKey" "SMTP_USERNAME" "extKubernetesSecretCtxs" (list $.Values.global.smtpCreateSecret.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalSMTPESOSecretIdentifier "secretCtx" $.Values.global.smtpCreateSecret.secrets.secretManagement.externalSecretsOperator))) }}
        {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "SMTP_PASSWORD" "defaultKubernetesSecretName" "smtp-secret" "defaultKubernetesSecretKey" "SMTP_PASSWORD" "extKubernetesSecretCtxs" (list $.Values.global.smtpCreateSecret.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalSMTPESOSecretIdentifier "secretCtx" $.Values.global.smtpCreateSecret.secrets.secretManagement.externalSecretsOperator))) }}
        {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "SMTP_HOST" "defaultKubernetesSecretName" "smtp-secret" "defaultKubernetesSecretKey" "SMTP_HOST" "extKubernetesSecretCtxs" (list $.Values.global.smtpCreateSecret.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalSMTPESOSecretIdentifier "secretCtx" $.Values.global.smtpCreateSecret.secrets.secretManagement.externalSecretsOperator))) }}
        {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "SMTP_PORT" "defaultKubernetesSecretName" "smtp-secret" "defaultKubernetesSecretKey" "SMTP_PORT" "extKubernetesSecretCtxs" (list $.Values.global.smtpCreateSecret.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalSMTPESOSecretIdentifier "secretCtx" $.Values.global.smtpCreateSecret.secrets.secretManagement.externalSecretsOperator))) }}
        {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "SMTP_USE_SSL" "defaultKubernetesSecretName" "smtp-secret" "defaultKubernetesSecretKey" "SMTP_USE_SSL" "extKubernetesSecretCtxs" (list $.Values.global.smtpCreateSecret.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalSMTPESOSecretIdentifier "secretCtx" $.Values.global.smtpCreateSecret.secrets.secretManagement.externalSecretsOperator))) }}
    {{- end }}
{{- end }}