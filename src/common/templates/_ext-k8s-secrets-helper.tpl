{{/*
{{ include "harnesscommon.secrets.hasExtKubernetesSecret" (dict "variableName" "MY_VARIABLE" "extKubernetesSecretCtxs" (list .Values.secrets)) }}
*/}}
{{- define "harnesscommon.secrets.hasExtKubernetesSecret" }}
{{- $hasExtKubernetesSecret := "false" }}
{{- if .variableName }}
  {{- range .extKubernetesSecretCtxs }}
    {{- range . }}
      {{- if and . .secretName .keys }}
        {{- if and (hasKey .keys $.variableName) (get .keys $.variableName) }}
          {{- $hasExtKubernetesSecret = "true" }}
        {{- end }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}
{{- print $hasExtKubernetesSecret }}
{{- end }}

{{/*
{{ include "harnesscommon.secrets.manageExtKubernetesSecretEnv" (dict "ctx" $ "variableName" "MY_VARIABLE" "overrideEnvName" "MY_ENV" "extKubernetesSecretCtxs" (list .Values.secrets)) }}
*/}}
{{- define "harnesscommon.secrets.manageExtKubernetesSecretEnv" }}
{{- $ := .ctx }}
{{- $variableName := .variableName }}
{{- $envVariableName := $variableName }}
{{- if .overrideEnvName }}
  {{- $envVariableName = .overrideEnvName }}
{{- end }}
{{- $secretName := "" }}
{{- $secretKey := "" }}
{{- if $variableName }}
  {{- range .extKubernetesSecretCtxs }}
    {{- range . }}
      {{- if and . .secretName .keys }}
        {{- $currSecretKey := (get .keys $variableName) }}
        {{- if and (hasKey .keys $variableName) $currSecretKey }}
          {{- $secretName = .secretName }}
          {{- $secretKey = $currSecretKey }}
        {{- end }}
      {{- end }}
    {{- end }}
  {{- end }}
  {{- if and $secretName $secretKey }}
- name: {{ print $envVariableName }}
  valueFrom:
    secretKeyRef:
      name: {{ printf "%s" $secretName }}
      key: {{ printf "%s" $secretKey }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
{{ include "harnesscommon.secrets.getExternalKubernetesSecretName" (dict "secretsCtx" .Values.secrets.kubernetesSecrets "globalSecretsCtx" .Values.Global "secret" "MONGO_USER") }}
*/}}
{{- define "harnesscommon.secrets.getExternalKubernetesSecretName" -}}
{{- $secret := .secret -}}
{{- $kubernetesSecretName := "" -}}
{{- if not (empty .secretsCtx) -}}
  {{- range $secretIdx, $kubernetesSecret := .secretsCtx -}}
    {{- if not (empty $kubernetesSecret.secretName) -}}
      {{- with $kubernetesSecret.keys -}}
        {{- if and (hasKey . $secret) (not (empty (get . $secret))) -}}
          {{- $kubernetesSecretName = $kubernetesSecret.secretName -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- if and (eq $kubernetesSecretName "") (not (empty .globalSecretsCtx)) -}}
{{- $kubernetesSecretName = (include "harnesscommon.secrets.hasESOSecrets" (dict "secretsCtx" .globalSecretsCtx "secret" $secret)) -}}
{{- end -}}
{{- print $kubernetesSecretName -}}
{{- end -}}

{{/*
{{ include "harnesscommon.secrets.getExtSecretKey" (dict "secretsCtx" .Values.secrets.kubernetesSecrets "secret" "MONGO_USER") }}
*/}}
{{- define "harnesscommon.secrets.getExtSecretKey" -}}
{{- $secret := .secret -}}
{{- $kubernetesSecretName := "" -}}
  {{- range $secretIdx, $kubernetesSecret := .secretsCtx -}}
    {{- if not (empty $kubernetesSecret.secretName) -}}
      {{- with $kubernetesSecret.keys -}}
        {{- if and (hasKey . $secret) (not (empty (get . $secret))) -}}
          {{- $kubernetesSecretName = (get . $secret) -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
  {{- print $kubernetesSecretName -}}
{{- end -}}