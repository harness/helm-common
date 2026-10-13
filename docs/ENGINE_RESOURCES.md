# Harness Engine resources

`harnesscommon.engine.renderResources` renders Harness Engine custom resources
(`engine.harness.io/v1alpha1`) from your chart's values. The CRD itself is installed by the
`engine-operator` chart; this template only renders CRs.

## Usage

Add `templates/engine-resources.yaml` to your chart:

```yaml
{{- include "harnesscommon.engine.renderResources" (dict "ctx" .) }}
```

Declare resources in values:

```yaml
engineResources:
  schedules:
    nightly-cleanup:            # metadata.name
      enabled: true             # optional; only false skips the entry
      labels: {}                # optional; merged over common labels
      annotations: {}           # optional
      spec:                     # required; copied verbatim, no defaults added
        namespace: pipeline
        cronExpr: "0 3 * * *"
        invocation:
          queue: pipeline
          action: cleanup
```

Every CR is created in the release namespace.

## Per-environment overrides

Resources are a map keyed by name, so an environment values file (for example
`harness-helm-overrides/services/<service>/<service>_<env>.yaml`) can:

```yaml
engineResources:
  schedules:
    nightly-cleanup:
      spec:
        cronExpr: "*/10 * * * *"   # modify
    legacy-sync:
      enabled: false               # disable
    my-env-only:                   # add
      spec: { ... }
```

Use `enabled: false` to remove an inherited entry. `null` is normalized to `{}` by the overrides
merge and then fails with "spec is required".

## Rendering rules

- No defaults are injected. Fields such as `timeZone` or `identifier` appear only if you set them.
- An enabled entry without `spec` (or with `spec: {}`) fails rendering.
- Entries render sorted by name.
- If the cluster does not serve `engine.harness.io/v1alpha1/Schedule`, nothing is rendered. With
  `helm template`, pass `--api-versions engine.harness.io/v1alpha1/Schedule`.
