{{/*
SecurityPolicy template for Envoy Gateway
Handles IP whitelisting, CORS, JWT authentication

USAGE:
{{- include "harnesscommon.v2.renderSecurityPolicy" (dict "ctx" $) }}

Supports hybrid approach (Option C):
- Shared global policies that target multiple HTTPRoutes
- Per-route override policies when needed
*/}}
{{- define "harnesscommon.v2.renderSecurityPolicy" }}
{{- $ := .ctx }}
{{- $ingress := $.Values.ingress }}
{{- if .ingress -}}
    {{- $ingress = .ingress }}
{{- end }}
{{- if and $.Values.global.gatewayAPI.enabled $.Values.global.ingress.enabled -}}

{{- $globalSecurityPolicy := dig "policies" "security" dict $.Values.global.gatewayAPI }}
{{- $hasGlobalPolicy := and $globalSecurityPolicy (dig "enabled" false $globalSecurityPolicy) }}

{{- /* Collect routes that need shared policy vs per-route policy */}}
{{- $sharedPolicyRoutes := list }}
{{- $perRouteOverrides := dict }}

{{- range $index, $object := $ingress.objects }}
  {{- $routeName := dig "name" ((cat (coalesce $ingress.name $.Values.nameOverride $.Chart.Name | trunc 63 | trimSuffix "-") "-" $index) | nospace) $object }}
  {{- $perRoutePolicy := dig "gatewayAPI" "security" dict $object }}

  {{- if $perRoutePolicy }}
    {{- /* This route has an override */}}
    {{- $_ := set $perRouteOverrides $routeName $perRoutePolicy }}
  {{- else if $hasGlobalPolicy }}
    {{- /* This route uses shared global policy */}}
    {{- $sharedPolicyRoutes = append $sharedPolicyRoutes $routeName }}
  {{- end }}
{{- end }}

{{- /* Generate shared global SecurityPolicy if any routes use it */}}
{{- if and $hasGlobalPolicy (gt (len $sharedPolicyRoutes) 0) }}
---
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: SecurityPolicy
metadata:
  name: {{ coalesce $ingress.name $.Values.nameOverride $.Chart.Name | trunc 63 | trimSuffix "-" }}-security-policy
  namespace: {{ $.Release.Namespace }}
  {{- if $.Values.global.commonLabels }}
  labels:
    {{- include "harnesscommon.tplvalues.render" ( dict "value" $.Values.global.commonLabels "context" $ ) | nindent 4 }}
  {{- end }}
  {{- if $.Values.global.commonAnnotations }}
  annotations:
    {{- include "harnesscommon.tplvalues.render" ( dict "value" $.Values.global.commonAnnotations "context" $ ) | nindent 4 }}
  {{- end }}
spec:
  targetRefs:
    {{- range $routeName := $sharedPolicyRoutes }}
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
      name: {{ $routeName }}
    {{- end }}
  {{- if $globalSecurityPolicy.authorization }}
  authorization:
    {{- if $globalSecurityPolicy.authorization.defaultAction }}
    defaultAction: {{ $globalSecurityPolicy.authorization.defaultAction }}
    {{- end }}
    {{- if $globalSecurityPolicy.authorization.rules }}
    rules:
      {{- range $rule := $globalSecurityPolicy.authorization.rules }}
      - action: {{ $rule.action }}
        principal:
          {{- if $rule.principal.clientCIDRs }}
          clientCIDRs:
            {{- range $cidr := $rule.principal.clientCIDRs }}
            - {{ $cidr | quote }}
            {{- end }}
          {{- end }}
      {{- end }}
    {{- end }}
  {{- end }}
  {{- if $globalSecurityPolicy.cors }}
  cors:
    {{- if $globalSecurityPolicy.cors.allowOrigins }}
    allowOrigins:
      {{- range $origin := $globalSecurityPolicy.cors.allowOrigins }}
      - {{ $origin | quote }}
      {{- end }}
    {{- end }}
    {{- if $globalSecurityPolicy.cors.allowMethods }}
    allowMethods:
      {{- range $method := $globalSecurityPolicy.cors.allowMethods }}
      - {{ $method | quote }}
      {{- end }}
    {{- end }}
    {{- if $globalSecurityPolicy.cors.allowHeaders }}
    allowHeaders:
      {{- range $header := $globalSecurityPolicy.cors.allowHeaders }}
      - {{ $header | quote }}
      {{- end }}
    {{- end }}
    {{- if $globalSecurityPolicy.cors.exposeHeaders }}
    exposeHeaders:
      {{- range $header := $globalSecurityPolicy.cors.exposeHeaders }}
      - {{ $header | quote }}
      {{- end }}
    {{- end }}
    {{- if $globalSecurityPolicy.cors.maxAge }}
    maxAge: {{ $globalSecurityPolicy.cors.maxAge }}
    {{- end }}
  {{- end }}
  {{- if $globalSecurityPolicy.jwt }}
  jwt:
    {{- if $globalSecurityPolicy.jwt.providers }}
    providers:
      {{- include "harnesscommon.tplvalues.render" (dict "value" $globalSecurityPolicy.jwt.providers "context" $) | nindent 6 }}
    {{- end }}
  {{- end }}
{{- end }}

{{- /* Generate per-route override SecurityPolicy resources */}}
{{- range $routeName, $policy := $perRouteOverrides }}
---
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: SecurityPolicy
metadata:
  name: {{ $routeName }}-security-policy
  namespace: {{ $.Release.Namespace }}
  {{- if $.Values.global.commonLabels }}
  labels:
    {{- include "harnesscommon.tplvalues.render" ( dict "value" $.Values.global.commonLabels "context" $ ) | nindent 4 }}
  {{- end }}
  annotations:
    helm.sh/policy-type: "per-route-override"
    {{- if $.Values.global.commonAnnotations }}
    {{- include "harnesscommon.tplvalues.render" ( dict "value" $.Values.global.commonAnnotations "context" $ ) | nindent 4 }}
    {{- end }}
spec:
  targetRefs:
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
      name: {{ $routeName }}
  {{- if $policy.authorization }}
  authorization:
    {{- if $policy.authorization.defaultAction }}
    defaultAction: {{ $policy.authorization.defaultAction }}
    {{- end }}
    {{- if $policy.authorization.rules }}
    rules:
      {{- range $rule := $policy.authorization.rules }}
      - action: {{ $rule.action }}
        principal:
          {{- if $rule.principal.clientCIDRs }}
          clientCIDRs:
            {{- range $cidr := $rule.principal.clientCIDRs }}
            - {{ $cidr | quote }}
            {{- end }}
          {{- end }}
      {{- end }}
    {{- end }}
  {{- end }}
  {{- if $policy.cors }}
  cors:
    {{- if $policy.cors.allowOrigins }}
    allowOrigins:
      {{- range $origin := $policy.cors.allowOrigins }}
      - {{ $origin | quote }}
      {{- end }}
    {{- end }}
    {{- if $policy.cors.allowMethods }}
    allowMethods:
      {{- range $method := $policy.cors.allowMethods }}
      - {{ $method | quote }}
      {{- end }}
    {{- end }}
    {{- if $policy.cors.allowHeaders }}
    allowHeaders:
      {{- range $header := $policy.cors.allowHeaders }}
      - {{ $header | quote }}
      {{- end }}
    {{- end }}
    {{- if $policy.cors.exposeHeaders }}
    exposeHeaders:
      {{- range $header := $policy.cors.exposeHeaders }}
      - {{ $header | quote }}
      {{- end }}
    {{- end }}
    {{- if $policy.cors.maxAge }}
    maxAge: {{ $policy.cors.maxAge }}
    {{- end }}
  {{- end }}
  {{- if $policy.jwt }}
  jwt:
    {{- if $policy.jwt.providers }}
    providers:
      {{- include "harnesscommon.tplvalues.render" (dict "value" $policy.jwt.providers "context" $) | nindent 6 }}
    {{- end }}
  {{- end }}
{{- end }}

{{- end }} {{/* if gateway / ingress enabled */}}
{{- end }} {{/* define */}}
