# Local AI Model Recommendations

These recommendations are based on direct Ollama benchmark runs using Project: Caroline-style conversational prompts. OpenRouter is still the best public beta default when you want the most polished replies with the least host load.

## Quick Picks

| Platform | Recommended local model | Fast fallback | Notes |
| --- | --- | --- | --- |
| Raspberry Pi OS Desktop | `qwen2.5:1.5b` | `qwen2.5:0.5b` | Prefer OpenRouter on Pi when possible. Local AI is experimental on small hardware. |
| Ubuntu Desktop / Server CPU-only | `qwen2.5:1.5b` | `qwen2.5:0.5b` | Validated as the conservative Linux/VM path. Use at least a 50GB disk if testing local Ollama. |
| Steam Deck / SteamOS | `qwen3:1.7b` | `smollm2:1.7b` or `qwen3:0.6b` | Best measured Steam Deck balance. `mistral:7b` is higher quality but too slow for default. |
| Bazzite / RTX 2070 Max-Q | `mistral:7b` | `qwen3:1.7b` | Best 2070 balance from the full popular + Gemma 4 sweep. `gemma4:e4b` matched quality but spills CPU/GPU on 8GB VRAM. |
| Pop!_OS / RTX A2000 laptop | `qwen3:1.7b` | `qwen2.5:1.5b` | `llama3.2:3b` is a decent conversational alternate. |
| Windows desktop / RTX 4070 | `gemma4:e4b` | `mistral:7b` or `qwen2.5:1.5b` | Best quality from the full popular + Gemma 4 sweep. Use `qwen2.5:1.5b` when response speed matters most. |

## Measured Rankings

Ratings are normalized to a 1-5 scale from the direct benchmark score. Average reply time includes cold-load effects, so a first prompt can make a model look slower than warm chat feels.

### Windows Desktop / RTX 4070

Full popular + Gemma 4 direct Ollama benchmark, May 26, 2026.

| Rank | Model | Rating | Avg reply | Notes |
| ---: | --- | ---: | ---: | --- |
| 1 | `gemma4:e4b` | 5.0/5 | 4.33s | Best quality; clean score; slower than the smaller models. |
| 2 | `mistral:7b` | 4.75/5 | 1.14s | Best quality/speed balance on the desktop. |
| 3 | `qwen3:1.7b` | 4.5/5 | 3.31s | Strong Caroline behavior; very high token speed after load. |
| 4 | `qwen2.5:1.5b` | 4.25/5 | 0.43s | Fastest practical fallback. |
| 5 | `llama3.1:8b` | 4.25/5 | 0.88s | Good quality, but identity guard was weaker. |

### Steam Deck / SteamOS

Full direct Ollama benchmark across Qwen, Llama, Gemma, Phi, DeepSeek, Mistral, SmolLM2, and TinyLlama.

| Rank | Model | Rating | Avg reply | Notes |
| ---: | --- | ---: | ---: | --- |
| 1 | `qwen3:1.7b` | 5.0/5 | 2.84s | Best Steam Deck default. |
| 2 | `mistral:7b` | 4.75/5 | 11.03s | Strong answers, too slow for default. |
| 3 | `gemma3:4b` | 4.25/5 | 6.20s | Good quality fallback. |
| 4 | `phi4-mini` | 4.25/5 | 8.03s | Good but heavier than `qwen3:1.7b`. |
| 5 | `smollm2:1.7b` | 4.0/5 | 4.44s | Useful lightweight non-Qwen fallback. |

### Pop!_OS / RTX A2000 Laptop

Direct Ollama benchmark of installed/current model set.

| Rank | Model | Rating | Avg reply | Notes |
| ---: | --- | ---: | ---: | --- |
| 1 | `qwen3:1.7b` | 4.5/5 | 1.14s | Best practical pick. |
| 2 | `qwen2.5:1.5b` | 4.25/5 | 0.49s | Best speed fallback. |
| 3 | `llama3.2:3b` | 4.0/5 | 0.91s | Better conversational alternate than code-focused models. |
| 4 | `gemma3:4b` | 3.75/5 | 1.24s | Coherent but less reliable in Caroline-style prompts. |

### Bazzite / Razer RTX 2070 Max-Q Laptop

Full popular + Gemma 4 direct Ollama benchmark, May 26, 2026. Warm average excludes the first cold-load prompt and better reflects normal chat after the model is loaded.

| Rank | Model | Rating | Warm avg reply | Notes |
| ---: | --- | ---: | ---: | --- |
| 1 | `mistral:7b` | 5.0/5 | 0.87s | Best Bazzite/2070 default; 10/10 coherence and 100% GPU residency. |
| 2 | `gemma4:e4b` | 5.0/5 | 1.38s | Excellent quality mode, but runs about 68% CPU / 32% GPU because it exceeds 8GB VRAM. |
| 3 | `qwen3:1.7b` | 4.5/5 | 0.35s | Best fast fallback; 100% GPU residency. |
| 4 | `gemma3:4b` | 4.5/5 | 0.73s | Good GPU-friendly alternate. |
| 5 | `gemma4:e2b` | 4.25/5 | 0.66s | Fast Gemma 4 option, slightly less reliable in recall/pick-one checks. |

## Practical Guidance

- Use OpenRouter for the public beta default if API use is acceptable.
- Use `qwen3:1.7b` for Steam Deck and low-power Bazzite handheld/laptop-style hosts.
- Use `mistral:7b` for Bazzite or Linux NVIDIA laptops with RTX 2070-class GPUs and 8GB VRAM.
- Use `gemma4:e4b` on RTX 4070-class desktops when quality matters more than first-token delay.
- Use `mistral:7b` on strong GPUs when you want a faster high-quality desktop local model.
- Use `qwen2.5:1.5b` as the fast, safe Linux fallback for VMs, Ubuntu hosts, and desktops where latency matters.
- Avoid `deepseek-r1` as a Caroline default for short companion chat; it underperformed on the conversational guardrails.
