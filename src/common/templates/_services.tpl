{{/*
Resolve the ESO Secret Context Identifier for a global service entry.

Uses the explicit `ctxIdentifier` field on the service entry when present,
otherwise falls back to the service key from `global.services`.

USAGE:
{{- include "harnesscommon.services.esoSecretCtxIdentifier" (dict "ctx" $ "serviceKey" "resourceHierarchy" "serviceCtx" $serviceCtx) }}
*/}}
{{- define "harnesscommon.services.esoSecretCtxIdentifier" }}
    {{- $ := .ctx }}
    {{- $ctxIdentifier := default .serviceKey (dig "ctxIdentifier" "" .serviceCtx) }}
    {{- include "harnesscommon.secrets.globalESOSecretCtxIdentifier" (dict "ctx" $ "ctxIdentifier" $ctxIdentifier) | trim }}
{{- end }}

{{/*
Collect the unique secret keys declared for a service secrets context.

Inspects both `kubernetesSecrets[].keys` and
`secretManagement.externalSecretsOperator[].remoteKeys`.

USAGE:
{{- include "harnesscommon.services.secretKeys" (dict "secretsCtx" $serviceSecretsCtx) }}
*/}}
{{- define "harnesscommon.services.secretKeys" }}
    {{- $secretKeys := list }}
    {{- $secretsCtx := .secretsCtx }}
    {{- range (dig "kubernetesSecrets" (list) $secretsCtx) }}
        {{- range $key, $value := (dig "keys" (dict) .) }}
            {{- $secretKeys = append $secretKeys $key }}
        {{- end }}
    {{- end }}
    {{- range (dig "secretManagement" "externalSecretsOperator" (list) $secretsCtx) }}
        {{- range $key, $value := (dig "remoteKeys" (dict) .) }}
            {{- $secretKeys = append $secretKeys $key }}
        {{- end }}
    {{- end }}
    {{- $secretKeys | uniq | join "," }}
{{- end }}

{{/*
Generic: Render K8S Env Spec for all secrets declared by services under
`.Values.global.services`.

For every enabled service entry, env vars are auto-derived from the declared
secret keys (Kubernetes secrets + ESO remoteKeys) and rendered using the
standard secret precedence (ESO > External K8S Secret > Default).

Each service entry may optionally declare:
  - enabled       (default: true)        whether to render the service secrets
  - ctxIdentifier  (default: <serviceKey>) prefix used for the ESO secret name

VALUES SHAPE:
global:
  services:
    resourceHierarchy:
      ctxIdentifier: resource-hierarchy-service
      secrets:
        kubernetesSecrets: []
        secretManagement:
          externalSecretsOperator: []

USAGE:
{{- include "harnesscommon.services.renderServiceSecretsEnv" (dict "ctx" $) | indent 12 }}
*/}}
{{- define "harnesscommon.services.renderServiceSecretsEnv" }}
    {{- $ := .ctx }}
    {{- $globalServicesCtx := dict }}
    {{- if and $.Values.global $.Values.global.services }}
        {{- $globalServicesCtx = $.Values.global.services }}
    {{- end }}
    {{- range $serviceKey, $serviceCtx := $globalServicesCtx }}
        {{- if $serviceCtx }}
            {{- $enabled := dig "enabled" true $serviceCtx }}
            {{- $serviceSecretsCtx := dig "secrets" (dict) $serviceCtx }}
            {{- if and $enabled $serviceSecretsCtx }}
                {{- $globalESOSecretIdentifier := include "harnesscommon.services.esoSecretCtxIdentifier" (dict "ctx" $ "serviceKey" $serviceKey "serviceCtx" $serviceCtx) }}
                {{- $extKubernetesSecretsCtx := dig "kubernetesSecrets" (list) $serviceSecretsCtx }}
                {{- $esoSecretsCtx := dig "secretManagement" "externalSecretsOperator" (list) $serviceSecretsCtx }}
                {{- $secretKeysStr := include "harnesscommon.services.secretKeys" (dict "secretsCtx" $serviceSecretsCtx) | trim }}
                {{- if $secretKeysStr }}
                    {{- range $variableName := (splitList "," $secretKeysStr) }}
                        {{- include "harnesscommon.secrets.manageEnv" (dict
                            "ctx" $
                            "variableName" $variableName
                            "extKubernetesSecretCtxs" (list $extKubernetesSecretsCtx)
                            "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalESOSecretIdentifier "secretCtx" $esoSecretsCtx))
                        ) }}
                    {{- end }}
                {{- end }}
            {{- end }}
        {{- end }}
    {{- end }}
{{- end }}

{{/*
Generic: Generate ESO ExternalSecret CRDs for all services declared under
`.Values.global.services`.

For every enabled service entry with valid ESO secrets, an ExternalSecret is
generated using the service's ESO secret context identifier as the name prefix.

USAGE:
{{- include "harnesscommon.services.generateServiceExternalSecrets" (dict "ctx" $) }}
*/}}
{{- define "harnesscommon.services.generateServiceExternalSecrets" }}
    {{- $ := .ctx }}
    {{- $globalServicesCtx := dict }}
    {{- if and $.Values.global $.Values.global.services }}
        {{- $globalServicesCtx = $.Values.global.services }}
    {{- end }}
    {{- range $serviceKey, $serviceCtx := $globalServicesCtx }}
        {{- if $serviceCtx }}
            {{- $enabled := dig "enabled" true $serviceCtx }}
            {{- $serviceSecretsCtx := dig "secrets" (dict) $serviceCtx }}
            {{- if and $enabled (eq (include "harnesscommon.secrets.hasESOSecrets" (dict "secretsCtx" $serviceSecretsCtx)) "true") }}
                {{- $globalESOSecretIdentifier := include "harnesscommon.services.esoSecretCtxIdentifier" (dict "ctx" $ "serviceKey" $serviceKey "serviceCtx" $serviceCtx) }}
                {{- include "harnesscommon.secrets.generateExternalSecret" (dict "secretsCtx" $serviceSecretsCtx "secretNamePrefix" $globalESOSecretIdentifier) }}
                {{- print "\n---" }}
            {{- end }}
        {{- end }}
    {{- end }}
{{- end }}
