#!/bin/bash
# Run this script locally with: bash create-istio-issues.sh
# Requires: gh auth login (with issue-creation permissions on keithmattix/holmesgpt)
set -euo pipefail

REPO="keithmattix/holmesgpt"

echo "Creating Istio toolset implementation issues in $REPO..."

###############################################################################
# Issue 1: istio/core YAML toolset
###############################################################################
gh issue create --repo "$REPO" \
  --title "[Istio Toolset] Phase 1: Create istio/core YAML toolset" \
  --label "enhancement" \
  --body '## Summary

Create the foundational `istio/core` YAML toolset at `holmes/plugins/toolsets/istio.yaml` following the pattern established by `cilium.yaml` and `argocd.yaml`.

## Scope

### Prerequisites
- `istioctl version --short` (verify `istioctl` is installed)
- `kubectl version --client` (verify `kubectl` is available)

### Tools to implement

| Tool Name | Command | Description |
|-----------|---------|-------------|
| `istioctl_version` | `istioctl version` | Show Istio control plane and client versions |
| `istioctl_analyze_cluster` | `istioctl analyze --all-namespaces` | Analyze entire cluster for Istio configuration issues |
| `istioctl_analyze_namespace` | `istioctl analyze -n {{ namespace }}` | Analyze a specific namespace for Istio configuration issues |
| `istioctl_proxy_status` | `istioctl proxy-status` | Show sync status of all Envoy proxies with the control plane |

### LLM instructions
Write `llm_instructions` that guide the LLM to:
1. Always run `istioctl_analyze_cluster` or `istioctl_analyze_namespace` first to detect config errors
2. Then check `istioctl_proxy_status` to see if proxies are connected and in sync
3. Branch to sidecar or ambient tools based on the cluster mode
4. Encode common footguns:
   - Injection labeling confusion (`istio-injection=enabled` vs revision labels)
   - Control plane revision drift after canary upgrades
   - PeerAuthentication scope precedence (mesh > namespace > workload)
   - DestinationRule TLS mode mismatches causing 503/UF/NR errors
   - VirtualService host/gateway mismatch and export visibility
   - Port naming/protocol detection pitfalls

### Output control
- Add `llm_summarize` transformers on `istioctl_analyze_cluster` and `istioctl_proxy_status` (threshold ~1000 chars)

### Tags
- `cli` (same as Cilium)

## Acceptance criteria
- [ ] `istio.yaml` loads correctly via `load_toolsets_from_file`
- [ ] All prerequisite checks pass when `istioctl` is available
- [ ] All prerequisite checks fail gracefully when `istioctl` is not installed
- [ ] Commands render correctly with provided parameters
- [ ] LLM instructions encode the troubleshooting workflow and common footguns

## References
- Pattern: `holmes/plugins/toolsets/cilium.yaml`, `holmes/plugins/toolsets/argocd.yaml`
- Istio docs: https://istio.io/latest/docs/reference/commands/istioctl/
'

echo "✅ Issue 1 created"

###############################################################################
# Issue 2: istio/sidecar YAML toolset
###############################################################################
gh issue create --repo "$REPO" \
  --title "[Istio Toolset] Phase 1: Create istio/sidecar YAML toolset" \
  --label "enhancement" \
  --body '## Summary

Create the `istio/sidecar` toolset section within `holmes/plugins/toolsets/istio.yaml` for Envoy sidecar proxy inspection.

## Depends on
- istio/core toolset (Issue: Phase 1 — istio/core)

## Scope

### Prerequisites
- Same as `istio/core` (shared YAML file)

### Tools to implement

| Tool Name | Command | Description |
|-----------|---------|-------------|
| `istioctl_pc_clusters` | `istioctl proxy-config clusters {{ pod_name }}.{{ namespace }}` | List upstream clusters known to the Envoy proxy |
| `istioctl_pc_listeners` | `istioctl proxy-config listeners {{ pod_name }}.{{ namespace }}` | List listeners configured in the Envoy proxy |
| `istioctl_pc_routes` | `istioctl proxy-config routes {{ pod_name }}.{{ namespace }}` | List routes configured in the Envoy proxy |
| `istioctl_pc_endpoints` | `istioctl proxy-config endpoints {{ pod_name }}.{{ namespace }}` | List endpoints known to the Envoy proxy |
| `istioctl_pc_bootstrap` | `istioctl proxy-config bootstrap {{ pod_name }}.{{ namespace }}` | Show the Envoy bootstrap configuration |
| `istioctl_pc_log` | `istioctl proxy-config log {{ pod_name }}.{{ namespace }}` | Show current Envoy log levels |

### LLM instructions
Extend the shared LLM instructions to guide sidecar-specific investigation:
1. Check proxy-config clusters/endpoints to verify upstream resolution
2. Check listeners to verify inbound/outbound port binding
3. Check routes for VirtualService routing correctness
4. Use bootstrap only as a last resort (large output)

### Output control
- `llm_summarize` on `istioctl_pc_clusters`, `istioctl_pc_listeners`, `istioctl_pc_routes`, `istioctl_pc_endpoints` (threshold ~2000 chars)
- `llm_summarize` on `istioctl_pc_bootstrap` (threshold ~1000 chars, aggressive summarization)

## Acceptance criteria
- [ ] All proxy-config commands render correctly with pod_name and namespace
- [ ] Pod name format `{{ pod_name }}.{{ namespace }}` is documented in tool descriptions
- [ ] Large outputs are summarized to avoid token overflow
- [ ] Error output includes exact failing command and stderr for LLM self-correction

## References
- `istioctl proxy-config` docs: https://istio.io/latest/docs/reference/commands/istioctl/#istioctl-proxy-config
'

echo "✅ Issue 2 created"

###############################################################################
# Issue 3: istio/ambient YAML toolset
###############################################################################
gh issue create --repo "$REPO" \
  --title "[Istio Toolset] Phase 2: Create istio/ambient YAML toolset" \
  --label "enhancement" \
  --body '## Summary

Create the `istio/ambient` toolset section within `holmes/plugins/toolsets/istio.yaml` for ztunnel and waypoint inspection in Istio ambient mode.

## Depends on
- istio/core toolset (Issue: Phase 1 — istio/core)

## Scope

### Prerequisites
- `istioctl version --short` (same as core)
- Consider version-gating: ambient commands are only available in Istio 1.22+

### Tools to implement

| Tool Name | Command | Description |
|-----------|---------|-------------|
| `istioctl_ztunnel_config_workloads` | `istioctl ztunnel-config workloads` | List workloads known to ztunnel |
| `istioctl_ztunnel_config_services` | `istioctl ztunnel-config services` | List services known to ztunnel |
| `istioctl_ztunnel_config_policies` | `istioctl ztunnel-config policies` | List authorization policies applied by ztunnel |
| `istioctl_waypoint_list` | `istioctl waypoint list -n {{ namespace }}` | List waypoint proxies in a namespace |
| `istioctl_waypoint_status` | `istioctl waypoint status {{ waypoint_name }} -n {{ namespace }}` | Show status of a specific waypoint proxy |

### LLM instructions
Extend instructions for ambient-specific investigation:
1. Verify namespace/workload enrollment in ambient mesh
2. Check ztunnel workloads and services for expected entries
3. For L7 policy/routing issues, verify a waypoint proxy exists
4. Key footguns:
   - Namespace labeled for ambient but workload not behaving as expected
   - Waypoint required for L7 features (AuthorizationPolicy with HTTP rules, VirtualService routing)
   - Mixed sidecar/ambient mode requires checking both Envoy and ztunnel state

### Version awareness
- Use `|| echo "Command not available in this Istio version"` pattern (like Cilium encryption)
- Document that ambient commands require Istio 1.22+

### Output control
- `llm_summarize` on `istioctl_ztunnel_config_workloads` and `istioctl_ztunnel_config_services` (threshold ~2000 chars)

## Acceptance criteria
- [ ] Ambient commands gracefully handle Istio versions that don'\''t support them
- [ ] Waypoint tools correctly parameterize namespace and waypoint name
- [ ] LLM instructions cover the ambient-specific troubleshooting flow
- [ ] Mixed mode (sidecar + ambient) investigation guidance is included

## References
- Istio ambient docs: https://istio.io/latest/docs/ambient/
- ztunnel-config reference: https://istio.io/latest/docs/reference/commands/istioctl/#istioctl-ztunnel-config
'

echo "✅ Issue 3 created"

###############################################################################
# Issue 4: Documentation for Istio toolset
###############################################################################
gh issue create --repo "$REPO" \
  --title "[Istio Toolset] Add documentation page and update index" \
  --label "documentation" \
  --body '## Summary

Add a documentation page for the Istio toolset and update all integration index pages.

## Files to update

### New file: `docs/data-sources/builtin-toolsets/istio.md`
Following the pattern of `docs/data-sources/builtin-toolsets/cilium.md`:
- Prerequisites section
- Configuration section (Holmes CLI + Robusta Helm Chart tabs)
- Tool capability tables for each sub-toolset (core, sidecar, ambient)
- Example prompts section (no explanations of what Holmes will do)

### Update: `docs/data-sources/builtin-toolsets/index.md`
Add Istio card under "Kubernetes & Containers":
```markdown
-   [:simple-istio:{ .lg .middle } **Istio**](istio.md)
```

### Update: `README.md`
Add Istio row to Data Sources table.

### Update: `docs/walkthrough/why-holmesgpt.md`
Add Istio to the categorized integration list.

### Update: `.nav.yml`
Add `istio.md` to the appropriate `.nav.yml` file.

### Logo
Add Istio logo to `images/integration_logos/` if one is available.

## Example prompts for the docs page

```
holmes ask "Why is traffic between the frontend and backend services failing?"
```

```
holmes ask "Are there any Istio configuration issues in the payments namespace?"
```

```
holmes ask "Why are some pods not getting sidecar injection?"
```

```
holmes ask "Check if mTLS is properly configured between service A and service B"
```

```
holmes ask "Why is the waypoint proxy not handling L7 traffic in the default namespace?"
```

## Acceptance criteria
- [ ] New docs page follows existing patterns (tabs, no capability prose, example prompts only)
- [ ] Index page updated with Istio card
- [ ] README updated with Istio in Data Sources
- [ ] Navigation file updated
- [ ] Bold text used for section headings inside tabs (not markdown headers)
- [ ] Blank lines between headers and lists (MkDocs requirement)

## References
- Pattern: `docs/data-sources/builtin-toolsets/cilium.md`
- Style guide: CLAUDE.md MkDocs Formatting Notes section
'

echo "✅ Issue 4 created"

###############################################################################
# Issue 5: Unit tests for Istio toolset
###############################################################################
gh issue create --repo "$REPO" \
  --title "[Istio Toolset] Add unit tests for YAML loading and command rendering" \
  --label "enhancement" \
  --body '## Summary

Add unit tests to verify the Istio toolset YAML loads correctly and commands render with proper parameters.

## Scope

### Test file
`tests/plugins/toolsets/test_istio.py`

### Tests to write

1. **YAML loading**
   - Toolset file loads without errors via `load_toolsets_from_file`
   - All three sub-toolsets are present: `istio/core`, `istio/sidecar`, `istio/ambient`
   - Each toolset has expected number of tools
   - Prerequisites are defined

2. **Command rendering**
   - `istioctl_analyze_namespace` renders correctly with namespace parameter
   - `istioctl_pc_clusters` renders correctly with pod_name and namespace
   - `istioctl_waypoint_list` renders correctly with namespace
   - `istioctl_waypoint_status` renders correctly with waypoint_name and namespace

3. **Error output requirements**
   - Commands include stderr in their output (for LLM self-correction)
   - Failed prerequisite checks report clear error messages

4. **LLM instructions**
   - Instructions are non-empty for each sub-toolset
   - Instructions mention key investigation workflow steps

## Acceptance criteria
- [ ] All tests pass with `poetry run pytest tests/plugins/toolsets/test_istio.py -v`
- [ ] Tests are marked `not llm` (standard unit tests)
- [ ] Tests follow existing patterns in `tests/plugins/toolsets/`

## References
- Pattern: existing tests in `tests/plugins/toolsets/`
'

echo "✅ Issue 5 created"

###############################################################################
# Issue 6: Helm chart CRD permissions for Istio
###############################################################################
gh issue create --repo "$REPO" \
  --title "[Istio Toolset] Verify Helm chart CRD permissions for Istio resources" \
  --label "enhancement" \
  --body '## Summary

Verify that the existing Helm chart CRD permissions for Istio resources are sufficient for the new toolset, and document any additional permissions needed.

## Context

The Helm chart already has an `istio: true` flag in `crdPermissions` (see `docs/data-sources/builtin-toolsets/kubernetes.md`). We need to verify this covers all Istio CRDs that Holmes might need to read when using `istioctl` commands.

## Scope

### Verify existing permissions
Check `helm/holmes/templates/holmesgpt-service-account.yaml` for the Istio CRD permissions granted when `crdPermissions.istio: true`.

### Required Istio CRDs for the toolset
The `istioctl` commands in our toolset primarily talk to istiod'\''s xDS API, but some may need direct CRD read access:

- `networking.istio.io`: VirtualService, DestinationRule, Gateway, ServiceEntry, Sidecar, EnvoyFilter
- `security.istio.io`: PeerAuthentication, AuthorizationPolicy, RequestAuthentication
- `telemetry.istio.io`: Telemetry
- `extensions.istio.io`: WasmPlugin (optional)
- `gateway.networking.k8s.io`: Gateway, HTTPRoute (for Gateway API mode)

### Verification steps
1. Review what the `istio: true` flag currently grants
2. Identify any gaps between granted permissions and what `istioctl analyze` / `proxy-config` need
3. Document any additional permissions needed in the Istio docs page

## Acceptance criteria
- [ ] Existing Istio CRD permissions reviewed
- [ ] Gaps identified and documented (if any)
- [ ] Istio toolset docs page includes notes on required permissions for in-cluster deployments

## References
- Helm values: `helm/holmes/values.yaml`
- Service account template: `helm/holmes/templates/holmesgpt-service-account.yaml`
'

echo "✅ Issue 6 created"

###############################################################################
# Issue 7: LLM eval tests for Istio scenarios
###############################################################################
gh issue create --repo "$REPO" \
  --title "[Istio Toolset] Phase 3: Create LLM eval test fixtures for Istio scenarios" \
  --label "enhancement" \
  --body '## Summary

Create LLM evaluation test fixtures for common Istio troubleshooting scenarios to validate that Holmes can effectively diagnose issues using the Istio toolset.

## Depends on
- All Phase 1 and Phase 2 toolset issues

## Scope

### Eval scenarios to implement

#### Scenario 1: mTLS mismatch (sidecar)
- Deploy two services where DestinationRule TLS mode conflicts with PeerAuthentication
- Expect Holmes to identify the mismatch via `istioctl analyze` + `proxy-config`
- Anti-cheat: use neutral service names, don'\''t hint at TLS in the prompt

#### Scenario 2: Missing waypoint for L7 policy (ambient)
- Deploy ambient-enrolled namespace with an HTTP AuthorizationPolicy but no waypoint
- Expect Holmes to identify the missing waypoint requirement
- Anti-cheat: ask about "authorization failures" not "missing waypoint"

#### Scenario 3: Sidecar injection failure
- Deploy a namespace with wrong injection label (e.g., revision label mismatch)
- Expect Holmes to detect via `analyze` and explain the labeling issue
- Anti-cheat: ask "why doesn'\''t my pod have two containers" not "why isn'\''t sidecar injecting"

#### Scenario 4: Proxy sync failure
- Simulate a scenario where proxies show STALE in `proxy-status`
- Expect Holmes to flag the sync issue and suggest root causes

### Test structure
- Each test gets its own directory under `tests/llm/fixtures/test_ask_holmes/`
- Follow sequential numbering convention
- Include `test_case.yaml`, infrastructure manifests, and `toolsets.yaml`
- Use dedicated namespace per test: `app-<testid>`

## Acceptance criteria
- [ ] Each scenario has a complete `test_case.yaml` with anti-hallucination expected outputs
- [ ] Infrastructure manifests create realistic Istio configurations
- [ ] Tests use `include_tool_calls: true` where output values are too generic
- [ ] Setup verification checks actual Istio mesh state (not just pod readiness)
- [ ] All tests pass with `poetry run pytest -k "test_name" --no-cov`

## References
- Eval guide: CLAUDE.md "Eval Tests" section
- Existing evals: `tests/llm/fixtures/test_ask_holmes/`
'

echo "✅ Issue 7 created"

###############################################################################
# Issue 8: Advanced diagnostics (Phase 3)
###############################################################################
gh issue create --repo "$REPO" \
  --title "[Istio Toolset] Phase 3: Advanced diagnostics and optional debug tools" \
  --label "enhancement" \
  --body '## Summary

Extend the Istio toolset with advanced diagnostic tools for deeper troubleshooting. These are lower-priority, higher-complexity tools.

## Depends on
- Phase 1 and Phase 2 toolset issues

## Scope

### Potential tools to add

| Tool Name | Command | Description | Risk/Notes |
|-----------|---------|-------------|------------|
| `istioctl_bug_report` | `istioctl bug-report` | Collect comprehensive debug info | Very large output, needs strict timeout + summarization |
| `istioctl_pc_secret` | `istioctl proxy-config secret {{ pod }}.{{ namespace }}` | Show mTLS certificate details | Useful for cert expiry debugging |
| `istioctl_experimental_describe` | `istioctl x describe pod {{ pod }} -n {{ namespace }}` | Human-readable pod mesh description | Nice high-level summary |
| `istioctl_experimental_precheck` | `istioctl x precheck` | Pre-upgrade compatibility check | Useful for upgrade troubleshooting |
| `istioctl_remote_clusters` | `istioctl remote-clusters` | List remote clusters in multi-cluster setup | Only for multi-cluster |
| `istioctl_pc_ecds` | `istioctl proxy-config ecds {{ pod }}.{{ namespace }}` | Extension config dump | For WasmPlugin/EnvoyFilter debugging |

### Design considerations
- All tools must be read-only
- Large-output tools need aggressive `llm_summarize` transformers
- Experimental commands should use `|| echo "Command not available"` fallback
- `bug-report` should have a strict timeout (e.g., 120s) and may need to be disabled by default

### Versioned output summarizers
- Tailor summarization prompts per tool (e.g., secret summarizer should focus on cert expiry dates)
- Consider custom summarization for `describe` output

## Acceptance criteria
- [ ] Each new tool has appropriate timeout and output control
- [ ] Experimental commands handle version incompatibility gracefully
- [ ] No mutating commands are included
- [ ] Unit tests cover new tool parameter rendering
- [ ] LLM instructions updated to reference new tools where appropriate

## References
- `istioctl` reference: https://istio.io/latest/docs/reference/commands/istioctl/
- Experimental commands: https://istio.io/latest/docs/reference/commands/istioctl/#istioctl-experimental
'

echo "✅ Issue 8 created"

echo ""
echo "🎉 All 8 issues created successfully!"
