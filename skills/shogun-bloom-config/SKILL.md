---
name: shogun-bloom-config
description: >
  Interactive configurator: answer 2 questions about your subscriptions,
  get a ready-to-paste capability_tiers YAML for config/settings.yaml.
  Also outputs optimal fixed agent model assignments (shogun/karo/gunshi).
  Trigger: "capability_tiers", "bloom config", "routing setup", "set up model routing",
  "ルーティング設定", "capability_tiers設定", "モデル設定", "サブスク設定"
---

# /shogun-bloom-config — Bloom Routing Configurator

## Overview

Asks 2 questions about your active subscriptions, then outputs:
1. **Fixed agent model assignments** — Shogun, Karo, Gunshi recommended models
2. **`capability_tiers` YAML** — paste into `config/settings.yaml`
3. **`available_cost_groups`** — declare your active subscriptions
4. **Gap warnings** — if your subscription can't cover a Bloom level

## When to Use

- First-time setup of `config/settings.yaml`
- You added or changed a subscription plan
- "What should my capability_tiers be?"
- After running `/shogun-model-list` to understand the landscape

---

## Instructions

### Step 1: Ask the user 2 questions

```
Q1: What is your Claude (Anthropic) plan?
    → Free / Pro ($20) / Max 5x ($100) / Max 20x ($200) / None

Q2: What is your ChatGPT (OpenAI) plan?
    → None / Plus ($20) / Pro ($200)
```

### Step 2: Map to pattern

| Claude Plan | ChatGPT Plan | Pattern |
|-------------|-------------|---------|
| None | None | — (cannot run Shogun) |
| Free | None | A-Free |
| Pro / Max 5x / Max 20x | None | A |
| None | Plus | B |
| None | Pro | C |
| Pro / Max | Plus | D |
| Pro / Max | Pro | E (Full Power) |

### Step 3: Output the configuration

Use the pattern tables below to output ONLY the matching configuration.

---

## Pattern A — Claude Pro/Max only ($20–$200/mo)

*(Also applies to Claude Free, but without Opus — see gap warning below)*

### Fixed Agent Assignments

| Agent | Model | Why |
|-------|-------|-----|
| Shogun | `claude-opus-4-6` | L6 strategic decisions |
| Karo | `claude-sonnet-4-6` | L4-L5 orchestration; Opus is overkill |
| Gunshi | `claude-opus-4-6` | L5-L6 deep review |

> **Claude Free users**: Opus 4.6 is not available. Use Sonnet 4.6 for Shogun and Gunshi.
> This creates a gap: L6 tasks (novel architecture, strategy) will be handled at L5 quality.

### `config/settings.yaml` snippet

```yaml
available_cost_groups:
  - claude_max

capability_tiers:
  claude-haiku-4-5-20251001:
    max_bloom: 2
    cost_group: claude_max
  claude-sonnet-4-6:
    max_bloom: 4
    cost_group: claude_max
  claude-opus-4-6:
    max_bloom: 6
    cost_group: claude_max
```

### Bloom Coverage

| Bloom | Model | Notes |
|-------|-------|-------|
| L1–L2 | Haiku 4.5 | Fast, low-cost worker tasks |
| L3–L4 | Sonnet 4.6 | Standard implementation and analysis |
| L5–L6 | Opus 4.6 | Architecture and design |

---

## Pattern B — ChatGPT Plus only ($20/mo)

*(No Claude subscription)*

### Fixed Agent Assignments

> Without Claude subscription, Shogun/Karo/Gunshi must use Codex models.
> Codex has an L6 gap — complex creative design is not reliable.

| Agent | Model | Why |
|-------|-------|-----|
| Shogun | `gpt-5.1-codex-max` | Highest available Codex model |
| Karo | `gpt-5.3-codex` | Orchestration, analysis |
| Gunshi | `gpt-5.1-codex-max` | Best available for review |

### `config/settings.yaml` snippet

```yaml
available_cost_groups:
  - chatgpt_plus

capability_tiers:
  gpt-5-codex-mini:
    max_bloom: 2
    cost_group: chatgpt_plus
  gpt-5.3-codex:
    max_bloom: 4
    cost_group: chatgpt_plus
  gpt-5.1-codex-max:
    max_bloom: 5
    cost_group: chatgpt_plus
```

### Bloom Coverage

| Bloom | Model | Notes |
|-------|-------|-------|
| L1–L2 | codex-mini | Quota-efficient for trivial tasks |
| L3–L4 | gpt-5.3-codex | Standard implementation and debugging |
| L5 | codex-max | Design evaluation |
| **L6** | ⚠️ **GAP** | Codex models are unreliable for novel creative design |

---

## Pattern C — ChatGPT Pro only ($200/mo)

*(No Claude subscription)*

### Fixed Agent Assignments

| Agent | Model | Why |
|-------|-------|-----|
| Shogun | `gpt-5.1-codex-max` | Highest available |
| Karo | `gpt-5.3-codex` | Orchestration |
| Gunshi | `gpt-5.1-codex-max` | Review |

### `config/settings.yaml` snippet

```yaml
available_cost_groups:
  - chatgpt_pro

capability_tiers:
  gpt-5.3-codex-spark:
    max_bloom: 3
    cost_group: chatgpt_pro
  gpt-5.3-codex:
    max_bloom: 4
    cost_group: chatgpt_pro
  gpt-5.1-codex-max:
    max_bloom: 5
    cost_group: chatgpt_pro
```

### Bloom Coverage

| Bloom | Model | Notes |
|-------|-------|-------|
| L1–L3 | **Spark** | 1000+ tok/sec; separate quota from gpt-5.3 |
| L4 | gpt-5.3-codex | Analysis and review |
| L5 | codex-max | Design evaluation |
| **L6** | ⚠️ **GAP** | L6 requires Claude Opus |

---

## Pattern D — Claude Pro/Max + ChatGPT Plus ($40–$220/mo)

### Fixed Agent Assignments

| Agent | Model | Why |
|-------|-------|-----|
| Shogun | `claude-opus-4-6` | L6 strategic decisions |
| Karo | `claude-sonnet-4-6` | L4-L5 orchestration |
| Gunshi | `claude-opus-4-6` | L5-L6 deep review |

### `config/settings.yaml` snippet

```yaml
available_cost_groups:
  - claude_max
  - chatgpt_plus

capability_tiers:
  gpt-5-codex-mini:
    max_bloom: 2
    cost_group: chatgpt_plus
  gpt-5.3-codex:
    max_bloom: 3
    cost_group: chatgpt_plus
  claude-sonnet-4-6:
    max_bloom: 5
    cost_group: claude_max
  claude-opus-4-6:
    max_bloom: 6
    cost_group: claude_max
```

### Bloom Coverage

| Bloom | Model | Notes |
|-------|-------|-------|
| L1–L2 | codex-mini | Saves Codex quota on trivial tasks |
| L3 | gpt-5.3-codex | Implementation tasks |
| L4–L5 | Sonnet 4.6 | Analysis, design review (Claude quality) |
| L6 | Opus 4.6 | Creative design and strategy |

---

## Pattern E — Claude Pro/Max + ChatGPT Pro ($220–$400/mo) — Full Power

*(Recommended for maximum throughput and capability)*

### Fixed Agent Assignments

| Agent | Model | Why |
|-------|-------|-----|
| Shogun | `claude-opus-4-6` | L6 strategic decisions |
| Karo | `claude-sonnet-4-6` | L4-L5 orchestration |
| Gunshi | `claude-opus-4-6` | L5-L6 deep review |

### `config/settings.yaml` snippet

```yaml
available_cost_groups:
  - claude_max
  - chatgpt_pro

capability_tiers:
  gpt-5.3-codex-spark:
    max_bloom: 3
    cost_group: chatgpt_pro
  gpt-5.3-codex:
    max_bloom: 4
    cost_group: chatgpt_pro
  claude-sonnet-4-6:
    max_bloom: 5
    cost_group: claude_max
  claude-opus-4-6:
    max_bloom: 6
    cost_group: claude_max
```

### Bloom Coverage

| Bloom | Model | Notes |
|-------|-------|-------|
| L1–L3 | **Spark** | Blazing fast; separate quota from gpt-5.3 — use freely |
| L4 | gpt-5.3-codex | Analysis and debugging |
| L5 | Sonnet 4.6 | Design review with Claude quality |
| L6 | Opus 4.6 | Novel architecture, strategy |

> Spark and gpt-5.3-codex run on separate quota pools — both can be maxed out simultaneously.

---

## Step 4: Apply the configuration

1. Open `config/settings.yaml`
2. Paste the `available_cost_groups` and `capability_tiers` blocks
3. For fixed agents (Shogun/Karo/Gunshi), update the `cli.agents` section:

```yaml
cli:
  agents:
    karo:
      type: claude
      model: claude-sonnet-4-6       # ← Karo uses Sonnet
    gunshi:
      type: claude
      model: opus                    # ← Gunshi uses Opus
    ashigaru1:
      type: codex                    # ← Ashigaru use Codex (Pattern D/E)
      model: gpt-5.3-codex-spark    #   actual model selected by capability_tiers
```

4. Shogun (you) is always Claude Code Opus — no config needed.

5. Enable routing (optional — currently off by default):

```yaml
bloom_routing: "off"   # Change to "auto" when ready to activate dynamic routing
```

> **Note**: `bloom_routing: "auto"` is a future feature (Issue #53). Leave as "off" for now.
> `capability_tiers` defines the routing table; the activation switch will be wired in a future release.

---

## Quick Decision Guide

```
Do you have Claude Pro or higher?
  Yes → Fixed agents (Shogun/Karo/Gunshi) use Claude models ✓
  No  → Fixed agents must use Codex — L6 gap exists ⚠️

Do you have ChatGPT Pro ($200)?
  Yes → Ashigaru get Spark (L1-L3, ultra-fast) + gpt-5.3 (L4) ✓
  No, Plus ($20) → Ashigaru get codex-mini (L1-L2) + gpt-5.3 (L3-L4), no Spark
  No ChatGPT at all → Ashigaru use Claude models only (Pattern A)
```
