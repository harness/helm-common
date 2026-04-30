{{/*
USAGE:
{{- include "harnesscommon.v2.renderHTTPRoute" (dict "ctx" $) }}
or
{{- include "harnesscommon.v2.renderHTTPRoute" (dict "gateway" .Values.other.gateway "ctx" $) }}
*/}}
{{- define "harnesscommon.v2.renderHTTPRoute" }}
{{- $ := .ctx }}
{{- $ingress := $.Values.ingress }}
{{- if .ingress -}}
    {{- $ingress = .ingress }}
{{- end }}
{{- if and $.Values.global.gatewayAPI.enabled $.Values.global.ingress.enabled -}}
{{- range $index, $object := $ingress.objects }}
{{- $routeName := dig "name" ((cat (coalesce $ingress.name $.Values.nameOverride $.Chart.Name | trunc 63 | trimSuffix "-") "-" $index) | nospace) $object }}
{{- $objectAnnotations := dig "annotations" dict $object }}
{{- /* Print migration suggestions if nginx annotations are detected */}}
{{- if $objectAnnotations }}
{{- include "harnesscommon.v2.printGatewayAPIMigrationSuggestions" (dict "ctx" $ "routeName" $routeName "annotations" $objectAnnotations) }}
{{- end }}
{{- /* Gateway API limits HTTPRoute to 16 rules. Split into chunks. */}}
{{- $maxRules := 16 }}
{{- $paths := $object.paths }}
{{- $numPaths := len $paths }}
{{- $numChunks := add1 (div (sub $numPaths 1) $maxRules) }}
{{- range $chunkIdx := until (int $numChunks) }}
{{- $start := mul $chunkIdx $maxRules }}
{{- $end := min (add $start $maxRules) $numPaths }}
{{- $chunkPaths := slice $paths (int $start) (int $end) }}
{{- $chunkRouteName := $routeName }}
{{- if gt $numChunks 1 }}
{{- $chunkRouteName = printf "%s-part-%d" $routeName $chunkIdx }}
{{- end }}
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {{ $chunkRouteName }}
  namespace: {{ $.Release.Namespace }}
  {{- if $.Values.global.commonLabels }}
  labels:
    {{- include "harnesscommon.tplvalues.render" ( dict "value" $.Values.global.commonLabels "context" $ ) | nindent 4 }}
  {{- end }}
  annotations:
    {{- /* The usual Ingress annotation to influence nginx location rules won't apply here, so we will
    not render $object.annotations in HTTPRoute objects */}}
    {{- if $ingress.annotations }}
    {{- include "harnesscommon.tplvalues.render" (dict "value" $ingress.annotations "context" $) | nindent 4 }}
    {{- end }}
    {{- if $.Values.global.commonAnnotations }}
    {{- include "harnesscommon.tplvalues.render" ( dict "value" $.Values.global.commonAnnotations "context" $ ) | nindent 4 }}
    {{- end }}
    {{- if $.Values.global.ingress.objects.annotations }}
    {{- include "harnesscommon.tplvalues.render" (dict "value" $.Values.global.ingress.objects.annotations "context" $) | nindent 4 }}
    {{- end }}
    {{- range $ca := $object.conditionalAnnotations }}
        {{- $condition := "false" }}
        {{- if hasKey $ca "condition" }}
            {{- $condition = include "harnesscommon.utils.getValueFromKey" (dict "key" $ca.condition "context" $ ) }}
        {{- end }}
        {{- if eq $condition "true" }}
            {{- include "harnesscommon.tplvalues.render" (dict "value" $ca.annotations "context" $) | nindent 4 }}
        {{- end }}
    {{- end }}
spec:
  {{- if $.Values.global.gatewayAPI.parentRef }}
  # Default parentRef from global config
  parentRefs:
    - name: {{ include "harnesscommon.tplvalues.render" ( dict "value" $.Values.global.gatewayAPI.parentRef.name "context" $) }}
      {{- if $.Values.global.gatewayAPI.parentRef.namespace }}
      namespace: {{ include "harnesscommon.tplvalues.render" ( dict "value" $.Values.global.gatewayAPI.parentRef.namespace "context" $) }}
      {{- end }}
      {{- if $.Values.global.gatewayAPI.parentRef.sectionName }}
      sectionName: {{ $.Values.global.gatewayAPI.parentRef.sectionName }}
      {{- end }}
      {{- if $.Values.global.gatewayAPI.parentRef.port }}
      port: {{ $.Values.global.gatewayAPI.parentRef.port }}
      {{- end }}
  {{- end }}
  hostnames:
  {{- if $.Values.global.ingress.disableHostInIngress }}
    - "*"
  {{- else }}
    {{- range $.Values.global.ingress.hosts }}
    - {{ . | quote }}
    {{- end }}
    {{- /* Add additional hostnames from global config */}}
    {{- $globalHttpRoute := dig "httpRoute" dict $.Values.global.gatewayAPI }}
    {{- if $globalHttpRoute.additionalHostnames }}
    {{- range $hostname := $globalHttpRoute.additionalHostnames }}
    - {{ $hostname | quote }}
    {{- end }}
    {{- end }}
    {{- /* Add additional hostnames from per-route config */}}
    {{- $perRouteHttpRoute := dig "gatewayAPI" dict $object }}
    {{- if $perRouteHttpRoute.additionalHostnames }}
    {{- range $hostname := $perRouteHttpRoute.additionalHostnames }}
    - {{ $hostname | quote }}
    {{- end }}
    {{- end }}
  {{- end }}
  rules:
    {{- range $idx := $chunkPaths }}
    {{- $serviceName := dig "backend" "service" "name" $.Chart.Name $idx }}
    {{- $servicePort := dig "backend" "service" "port" $.Values.service.port $idx }}
    {{- $globalHttpRoute := dig "httpRoute" dict $.Values.global.gatewayAPI }}
    {{- $perRouteHttpRoute := dig "gatewayAPI" dict $object }}
    {{- $hasRewriteTarget := and $objectAnnotations (hasKey $objectAnnotations "nginx.ingress.kubernetes.io/rewrite-target") }}
    {{- $hasUpstreamVhost := or $globalHttpRoute.upstreamHostOverride $perRouteHttpRoute.upstreamHostOverride }}
    {{- $hasRequestHeaders := or $globalHttpRoute.requestHeaders $perRouteHttpRoute.requestHeaders }}
    {{- $hasResponseHeaders := or $globalHttpRoute.responseHeaders $perRouteHttpRoute.responseHeaders }}
    {{- $needsFilters := or $hasRewriteTarget $hasUpstreamVhost $hasRequestHeaders $hasResponseHeaders }}
    - matches:
        - path:
            type: RegularExpression
            value: {{ include "harnesscommon.tplvalues.render" ( dict "value" $idx.path "context" $) }}
      {{- if $needsFilters }}
      filters:
        {{- /* Request Header Modifier - handles upstreamHostOverride and custom headers */}}
        {{- $requestHeaderModifier := dict }}
        {{- $hasRequestModifier := false }}
        {{- /* Upstream host override (nginx upstream-vhost equivalent) */}}
        {{- $upstreamHost := "" }}
        {{- if $perRouteHttpRoute.upstreamHostOverride }}
          {{- $upstreamHost = $perRouteHttpRoute.upstreamHostOverride }}
        {{- else if $globalHttpRoute.upstreamHostOverride }}
          {{- $upstreamHost = $globalHttpRoute.upstreamHostOverride }}
        {{- end }}
        {{- if $upstreamHost }}
          {{- $hasRequestModifier = true }}
          {{- $_ := set $requestHeaderModifier "set" (list (dict "name" "Host" "value" $upstreamHost)) }}
        {{- end }}
        {{- /* Custom request headers (set/add/remove) */}}
        {{- $reqHeaders := dict }}
        {{- if $globalHttpRoute.requestHeaders }}
          {{- $reqHeaders = $globalHttpRoute.requestHeaders }}
        {{- end }}
        {{- if $perRouteHttpRoute.requestHeaders }}
          {{- $reqHeaders = $perRouteHttpRoute.requestHeaders }}
        {{- end }}
        {{- if or $reqHeaders.set $reqHeaders.add $reqHeaders.remove }}
          {{- $hasRequestModifier = true }}
          {{- if $reqHeaders.set }}
            {{- if $upstreamHost }}
              {{- /* Merge with existing Host header */}}
              {{- $existingSet := get $requestHeaderModifier "set" }}
              {{- range $header := $reqHeaders.set }}
                {{- $existingSet = append $existingSet $header }}
              {{- end }}
              {{- $_ := set $requestHeaderModifier "set" $existingSet }}
            {{- else }}
              {{- $_ := set $requestHeaderModifier "set" $reqHeaders.set }}
            {{- end }}
          {{- end }}
          {{- if $reqHeaders.add }}
            {{- $_ := set $requestHeaderModifier "add" $reqHeaders.add }}
          {{- end }}
          {{- if $reqHeaders.remove }}
            {{- $_ := set $requestHeaderModifier "remove" $reqHeaders.remove }}
          {{- end }}
        {{- end }}
        {{- if $hasRequestModifier }}
        - type: RequestHeaderModifier
          requestHeaderModifier:
            {{- if $requestHeaderModifier.set }}
            set:
              {{- range $header := $requestHeaderModifier.set }}
              - name: {{ $header.name | quote }}
                value: {{ $header.value | quote }}
              {{- end }}
            {{- end }}
            {{- if $requestHeaderModifier.add }}
            add:
              {{- range $header := $requestHeaderModifier.add }}
              - name: {{ $header.name | quote }}
                value: {{ $header.value | quote }}
              {{- end }}
            {{- end }}
            {{- if $requestHeaderModifier.remove }}
            remove:
              {{- range $headerName := $requestHeaderModifier.remove }}
              - {{ $headerName | quote }}
              {{- end }}
            {{- end }}
        {{- end }}
        {{- /* Response Header Modifier */}}
        {{- $respHeaders := dict }}
        {{- if $globalHttpRoute.responseHeaders }}
          {{- $respHeaders = $globalHttpRoute.responseHeaders }}
        {{- end }}
        {{- if $perRouteHttpRoute.responseHeaders }}
          {{- $respHeaders = $perRouteHttpRoute.responseHeaders }}
        {{- end }}
        {{- if or $respHeaders.set $respHeaders.add $respHeaders.remove }}
        - type: ResponseHeaderModifier
          responseHeaderModifier:
            {{- if $respHeaders.set }}
            set:
              {{- range $header := $respHeaders.set }}
              - name: {{ $header.name | quote }}
                value: {{ $header.value | quote }}
              {{- end }}
            {{- end }}
            {{- if $respHeaders.add }}
            add:
              {{- range $header := $respHeaders.add }}
              - name: {{ $header.name | quote }}
                value: {{ $header.value | quote }}
              {{- end }}
            {{- end }}
            {{- if $respHeaders.remove }}
            remove:
              {{- range $headerName := $respHeaders.remove }}
              - {{ $headerName | quote }}
              {{- end }}
            {{- end }}
        {{- end }}
        {{- /* URL Rewrite filter (existing logic) */}}
        {{- if $hasRewriteTarget }}
        {{- $renderedPath := include "harnesscommon.tplvalues.render" ( dict "value" $idx.path "context" $) }}
        {{- $step1 := $renderedPath | trimPrefix "/" }}
        {{- $step2 := regexReplaceAll "[^a-zA-Z0-9/]" $step1 "" }}
        {{- $step3 := regexReplaceAll "/" $step2 "-" }}
        {{- $step4 := regexReplaceAll "-+" $step3 "-" }}
        {{- $pathSlugFull := $step4 | trimSuffix "-" | lower }}
        {{- $shortHash := sha1sum $renderedPath | trunc 6 }}
        {{- $maxPathLen := sub 253 (add (len $chunkRouteName) 8) | int }}
        {{- $pathSlug := "" }}
        {{- if $pathSlugFull }}
          {{- if gt (len $pathSlugFull) $maxPathLen }}
            {{- $pathSlug = trunc $maxPathLen $pathSlugFull | trimSuffix "-" }}
          {{- else }}
            {{- $pathSlug = $pathSlugFull }}
          {{- end }}
        {{- end }}
        - type: ExtensionRef
          extensionRef:
            group: gateway.envoyproxy.io
            kind: HTTPRouteFilter
            name: {{ if $pathSlug }}{{ cat $chunkRouteName "-" $pathSlug "-" $shortHash | nospace }}{{ else }}{{ cat $chunkRouteName "-" $shortHash | nospace }}{{ end }}
        {{- end }}
      {{- end }}
      # Backend services
      backendRefs:
        - name: {{ $serviceName }}
          port: {{ $servicePort }}
      {{- if and $objectAnnotations (hasKey $objectAnnotations "nginx.ingress.kubernetes.io/proxy-read-timeout") }}
      # Timeouts for this rule
      timeouts:
        {{- /* Add timeouts if the nginx annotation was set. Not ideal, as these settings are not equivalent.
        TODO: Improve? */}}
        backendRequest: {{ printf "%s%s" (get $objectAnnotations "nginx.ingress.kubernetes.io/proxy-read-timeout") "s" }}
      {{- end }}
    {{- end }}
{{- if and $objectAnnotations (hasKey $objectAnnotations "nginx.ingress.kubernetes.io/rewrite-target") }}
{{- range $idx := $chunkPaths }}
{{- $renderedPath := include "harnesscommon.tplvalues.render" ( dict "value" $idx.path "context" $) }}
{{- $step1 := $renderedPath | trimPrefix "/" }}
{{- $step2 := regexReplaceAll "[^a-zA-Z0-9/]" $step1 "" }}
{{- $step3 := regexReplaceAll "/" $step2 "-" }}
{{- $step4 := regexReplaceAll "-+" $step3 "-" }}
{{- $pathSlugFull := $step4 | trimSuffix "-" | lower }}
{{- $shortHash := sha1sum $renderedPath | trunc 6 }}
{{- $maxPathLen := sub 253 (add (len $chunkRouteName) 8) | int }}
{{- $pathSlug := "" }}
{{- if $pathSlugFull }}
  {{- if gt (len $pathSlugFull) $maxPathLen }}
    {{- $pathSlug = trunc $maxPathLen $pathSlugFull | trimSuffix "-" }}
  {{- else }}
    {{- $pathSlug = $pathSlugFull }}
  {{- end }}
{{- end }}
---
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: HTTPRouteFilter
metadata:
  name: {{ if $pathSlug }}{{ cat $chunkRouteName "-" $pathSlug "-" $shortHash | nospace }}{{ else }}{{ cat $chunkRouteName "-" $shortHash | nospace }}{{ end }}
  namespace: {{ $.Release.Namespace }}
  {{- if $.Values.global.commonLabels }}
  labels:
    {{- include "harnesscommon.tplvalues.render" ( dict "value" $.Values.global.commonLabels "context" $ ) | nindent 4 }}
  {{- end }}
  annotations:
    {{- /* The usual Ingress annotation to influence nginx location rules won't apply here, so we will
    not render $object.annotations in HTTPRoute objects */}}
    {{- if $ingress.annotations }}
    {{- include "harnesscommon.tplvalues.render" (dict "value" $ingress.annotations "context" $) | nindent 4 }}
    {{- end }}
    {{- if $.Values.global.commonAnnotations }}
    {{- include "harnesscommon.tplvalues.render" ( dict "value" $.Values.global.commonAnnotations "context" $ ) | nindent 4 }}
    {{- end }}
    {{- if $.Values.global.ingress.objects.annotations }}
    {{- include "harnesscommon.tplvalues.render" (dict "value" $.Values.global.ingress.objects.annotations "context" $) | nindent 4 }}
    {{- end }}
    {{- range $ca := $object.conditionalAnnotations }}
        {{- $condition := "false" }}
        {{- if hasKey $ca "condition" }}
            {{- $condition = include "harnesscommon.utils.getValueFromKey" (dict "key" $ca.condition "context" $ ) }}
        {{- end }}
        {{- if eq $condition "true" }}
            {{- include "harnesscommon.tplvalues.render" (dict "value" $ca.annotations "context" $) | nindent 4 }}
        {{- end }}
    {{- end }}
spec:
  urlRewrite:
    path:
      type: ReplaceRegexMatch
      replaceRegexMatch:
        pattern: {{ include "harnesscommon.tplvalues.render" ( dict "value" $idx.path "context" $) }}
        substitution: {{ include "harnesscommon.tplvalues.render" ( dict "value" ( regexReplaceAll "\\$" (get $objectAnnotations "nginx.ingress.kubernetes.io/rewrite-target") "\\" ) "context" $) }}
{{- end }} {{/* Range over chunk paths */}}
{{- end }} {{/* If to create HTTPRouteFilter */}}
{{- end }} {{/* Range over chunks */}}
{{- end }} {{/* Range over all the ingress keys */}}
{{- end }} {{/* if gateway / ingress enabled */}}
{{- end }} {{/* define */}}
