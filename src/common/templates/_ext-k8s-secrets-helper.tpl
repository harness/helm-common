{{/*
{{ include "harnesscommon.secrets.hasExtKubernetesSecret" (dict "variableName" "MY_VARIABLE" "extKubernetesSecretCtxs" (list .Values.secrets)) }}
*/}}
{{- define "harnesscommon.secrets.hasExtKubernetesSecret" }}
{{- $hasExtKubernetesSecret := "false" }}
{{- if .variableName }}
  {{- range .extKubernetesSecretCtxs }}
    {{- $secretCtx := . }}
    {{- /* secrets.kubernetesSecrets supports two shapes for backward compatibility:
           - legacy list: [{secretName: "...", keys: {...}}, ...]
           - map (keyed by secretName): {"...": {keys: {...}}, ...} -- deep-mergeable by Helm
    */}}
    {{- if eq (kindOf $secretCtx) "map" }}
      {{- range $secretName, $secretVal := $secretCtx }}
        {{- if and $secretName $secretVal $secretVal.keys }}
          {{- if and (hasKey $secretVal.keys $.variableName) (get $secretVal.keys $.variableName) }}
            {{- $hasExtKubernetesSecret = "true" }}
          {{- end }}
        {{- end }}
      {{- end }}
    {{- else }}
      {{- range $secretCtx }}
        {{- if and . .secretName .keys }}
          {{- if and (hasKey .keys $.variableName) (get .keys $.variableName) }}
            {{- $hasExtKubernetesSecret = "true" }}
          {{- end }}
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
    {{- $secretCtx := . }}
    {{- if eq (kindOf $secretCtx) "map" }}
      {{- range $sName, $secretVal := $secretCtx }}
        {{- if and $sName $secretVal $secretVal.keys }}
          {{- $currSecretKey := (get $secretVal.keys $variableName) }}
          {{- if and (hasKey $secretVal.keys $variableName) $currSecretKey }}
            {{- $secretName = $sName }}
            {{- $secretKey = $currSecretKey }}
          {{- end }}
        {{- end }}
      {{- end }}
    {{- else }}
      {{- range $secretCtx }}
        {{- if and . .secretName .keys }}
          {{- $currSecretKey := (get .keys $variableName) }}
          {{- if and (hasKey .keys $variableName) $currSecretKey }}
            {{- $secretName = .secretName }}
            {{- $secretKey = $currSecretKey }}
          {{- end }}
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
  {{- if eq (kindOf .secretsCtx) "map" -}}
    {{- range $sName, $kubernetesSecret := .secretsCtx -}}
      {{- if not (empty $sName) -}}
        {{- with $kubernetesSecret.keys -}}
          {{- if and (hasKey . $secret) (not (empty (get . $secret))) -}}
            {{- $kubernetesSecretName = $sName -}}
          {{- end -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- else -}}
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
{{- if eq (kindOf .secretsCtx) "map" -}}
  {{- range $sName, $kubernetesSecret := .secretsCtx -}}
    {{- if not (empty $sName) -}}
      {{- with $kubernetesSecret.keys -}}
        {{- if and (hasKey . $secret) (not (empty (get . $secret))) -}}
          {{- $kubernetesSecretName = (get . $secret) -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- else -}}
  {{- range $secretIdx, $kubernetesSecret := .secretsCtx -}}
    {{- if not (empty $kubernetesSecret.secretName) -}}
      {{- with $kubernetesSecret.keys -}}
        {{- if and (hasKey . $secret) (not (empty (get . $secret))) -}}
          {{- $kubernetesSecretName = (get . $secret) -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
  {{- print $kubernetesSecretName -}}
{{- end -}}
