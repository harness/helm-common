{{/*
Generates env objects for Default Kubernetes Secrets

USAGE:
{{ include "harnesscommon.secrets.manageDefaultKubernetesSecretEnv" (dict "variableName" "MY_VARIABLE" "overrideEnvName" "MY_ENV" "defaultKubernetesSecretName" "MY_GENERATED_SECRET" "defaultKubernetesSecretKey" "GENERATED_SECRET_KEY") }}
*/}}
{{- define "harnesscommon.secrets.manageDefaultKubernetesSecretEnv" }}
    {{- $variableName := .variableName }}
    {{- $envVariableName := $variableName }}
    {{- if .overrideEnvName }}
        {{- $envVariableName = .overrideEnvName }}
    {{- end }}
    {{- $defaultKubernetesSecretName := .defaultKubernetesSecretName }}
    {{- $defaultKubernetesSecretKey := .defaultKubernetesSecretKey }}
    {{- if and (not (empty $variableName)) (not (empty $defaultKubernetesSecretName)) (not (empty $defaultKubernetesSecretKey)) }}
- name: {{ print $envVariableName }}
  valueFrom:
    secretKeyRef:
      name: {{ print $defaultKubernetesSecretName }}
      key: {{ print $defaultKubernetesSecretKey }}
    {{- else }}
        {{- $errMsg := printf "Invalid input: variableName %s, secretName %s , secretKey %s" $variableName $defaultKubernetesSecretName $defaultKubernetesSecretKey }}
        {{- fail $errMsg }}
    {{- end }}
{{- end }}