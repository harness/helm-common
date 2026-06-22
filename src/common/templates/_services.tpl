{{/*
Generate K8S Env Spec for Resource Hierarchy Service Secret

USAGE:
{{- include "harnesscommon.services.rhsEnv" (dict "ctx" $ "variableName" "RESOURCE_HIERARCHY_SERVICE_SECRET") | indent 12 }}

PARAMETERS:
REQUIRED:
1. ctx - Helm context ($)

OPTIONAL:
1. variableName - Override the environment variable name (default: "RESOURCE_HIERARCHY_SERVICE_SECRET")

EXAMPLE:
env:
  {{- include "harnesscommon.services.rhsEnv" (dict "ctx" $) | indent 12 }}
*/}}
{{- define "harnesscommon.services.rhsEnv" }}
    {{- $ := .ctx }}
    {{- $variableName := default "RESOURCE_HIERARCHY_SERVICE_SECRET" .variableName }}
    {{- $globalServicesCtx := $.Values.global.services }}
    {{- $rhsCtx := $globalServicesCtx.resourceHierarchy }}

    {{- if and $globalServicesCtx $rhsCtx }}
        {{- $enabled := dig "enabled" true $rhsCtx }}
        {{- if $enabled }}
            {{- $globalESOSecretIdentifier := include "harnesscommon.secrets.globalESOSecretCtxIdentifier" (dict "ctx" $ "ctxIdentifier" "resource-hierarchy-service") }}
            {{- include "harnesscommon.secrets.manageEnv" (dict
                "ctx" $
                "variableName" "RESOURCE_HIERARCHY_SERVICE_SECRET"
                "overrideEnvName" $variableName
                "extKubernetesSecretCtxs" (list $rhsCtx.secrets.kubernetesSecrets)
                "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalESOSecretIdentifier "secretCtx" $rhsCtx.secrets.secretManagement.externalSecretsOperator))
            ) }}
        {{- end }}
    {{- end }}
{{- end }}
