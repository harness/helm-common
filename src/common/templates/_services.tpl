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
    {{- /* Normalize to a valid lowercase RFC-1123 name (e.g. camelCase service keys like "resourceHierarchy" -> "resource-hierarchy"). */}}
    {{- $ctxIdentifier = $ctxIdentifier | kebabcase }}
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
Resolve the list of global service keys a chart depends on.

The dependency list is sourced (in precedence order) from:
  1. an explicit `services` argument (list), when provided
  2. `.Values.serviceSecretDependencies` (list)

Returns a comma-joined string of service keys (empty when no dependencies are
declared). This is the filter that ensures a workload only receives the
credentials of the services it actually depends on.

USAGE:
{{- include "harnesscommon.services.dependencies" (dict "ctx" $) }}
*/}}
{{- define "harnesscommon.services.dependencies" }}
    {{- $ := .ctx }}
    {{- $dependencies := .services }}
    {{- if not $dependencies }}
        {{- $dependencies = ($.Values.serviceSecretDependencies | default (list)) }}
    {{- end }}
    {{- $dependencies | join "," }}
{{- end }}

{{/*
Validate that every declared dependency exists under global.services.

Fails the template render with a descriptive error if any entry in the
dependency list (from `serviceSecretDependencies` or the `services` argument)
does not have a corresponding key under `global.services`.

USAGE:
{{- include "harnesscommon.services.validateDependencies" (dict "ctx" $) }}
{{- include "harnesscommon.services.validateDependencies" (dict "ctx" $ "services" (list "resourceHierarchy")) }}
*/}}
{{- define "harnesscommon.services.validateDependencies" }}
    {{- $ := .ctx }}
    {{- $globalServicesCtx := dict }}
    {{- if and $.Values.global $.Values.global.services }}
        {{- $globalServicesCtx = $.Values.global.services }}
    {{- end }}
    {{- $dependenciesStr := include "harnesscommon.services.dependencies" (dict "ctx" $ "services" .services) | trim }}
    {{- $dependencies := list }}
    {{- if $dependenciesStr }}
        {{- $dependencies = splitList "," $dependenciesStr }}
    {{- end }}
    {{- range $dep := $dependencies }}
        {{- if not (hasKey $globalServicesCtx $dep) }}
            {{- fail (printf "serviceSecretDependencies: dependency '%s' is not defined under global.services" $dep) }}
        {{- end }}
    {{- end }}
{{- end }}

{{/*
Generic: Render K8S Env Spec for the secrets of the services a chart depends on.

For every dependency declared via `.Values.serviceSecretDependencies` (or the
optional `services` argument), env vars are auto-derived from that service's
declared secret keys (Kubernetes secrets + ESO remoteKeys) and rendered using
the standard secret precedence (ESO > External K8S Secret > Default).

Services NOT listed as a dependency are skipped, so a workload never receives
credentials it does not depend on. When no dependencies are declared, nothing
is rendered.

Each service entry under `global.services` may optionally declare:
  - enabled       (default: true)        whether to render the service secrets
  - ctxIdentifier  (default: <serviceKey>) prefix used for the ESO secret name

VALUES SHAPE:
serviceSecretDependencies:
  - resourceHierarchy
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
{{- include "harnesscommon.services.renderServiceSecretsEnv" (dict "ctx" $ "services" (list "resourceHierarchy")) | indent 12 }}
*/}}
{{- define "harnesscommon.services.renderServiceSecretsEnv" }}
    {{- $ := .ctx }}
    {{- include "harnesscommon.services.validateDependencies" (dict "ctx" $ "services" .services) }}
    {{- $globalServicesCtx := dict }}
    {{- if and $.Values.global $.Values.global.services }}
        {{- $globalServicesCtx = $.Values.global.services }}
    {{- end }}
    {{- $dependenciesStr := include "harnesscommon.services.dependencies" (dict "ctx" $ "services" .services) | trim }}
    {{- $dependencies := list }}
    {{- if $dependenciesStr }}
        {{- $dependencies = splitList "," $dependenciesStr }}
    {{- end }}
    {{- range $serviceKey, $serviceCtx := $globalServicesCtx }}
        {{- if and $serviceCtx (has $serviceKey $dependencies) }}
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
Generic: Generate ESO ExternalSecret CRDs for the services a chart is responsible
for materializing.

Like the env helper, the set of services is filtered by
`.Values.serviceSecretDependencies` (or the optional `services` argument), so a
chart only emits the ExternalSecret CRDs it needs. This prevents multiple charts
in a shared namespace from emitting duplicate ExternalSecret resources with the
same name.

For every filtered, enabled service entry with valid ESO secrets, an
ExternalSecret is generated using the service's ESO secret context identifier as
the name prefix.

USAGE:
{{- include "harnesscommon.services.generateServiceExternalSecrets" (dict "ctx" $) }}
{{- include "harnesscommon.services.generateServiceExternalSecrets" (dict "ctx" $ "services" (list "resourceHierarchy")) }}
*/}}
{{- define "harnesscommon.services.generateServiceExternalSecrets" }}
    {{- $ := .ctx }}
    {{- include "harnesscommon.services.validateDependencies" (dict "ctx" $ "services" .services) }}
    {{- $globalServicesCtx := dict }}
    {{- if and $.Values.global $.Values.global.services }}
        {{- $globalServicesCtx = $.Values.global.services }}
    {{- end }}
    {{- $dependenciesStr := include "harnesscommon.services.dependencies" (dict "ctx" $ "services" .services) | trim }}
    {{- $dependencies := list }}
    {{- if $dependenciesStr }}
        {{- $dependencies = splitList "," $dependenciesStr }}
    {{- end }}
    {{- range $serviceKey, $serviceCtx := $globalServicesCtx }}
        {{- if and $serviceCtx (has $serviceKey $dependencies) }}
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
