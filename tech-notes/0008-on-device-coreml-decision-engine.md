# 0008 — On-Device Decision Models via Core ML, Apple Neural Engine, and Native Tokenization

- **Date**: 2026-09-24
- **Author**: Peter Friese
- **Framework**: `CoreML`, `FoundationModels` (iOS 27.0+, macOS 27.0+), `LayaOnDevice`
- **Upstream**: NandhaKishorM/laya (ModernBERT 421M, mmBERT 322M)

---

## Context

While cloud and self-hosted decision APIs (`JevFoundationModels`, `LayaFoundationModels`) achieve sub-100ms response times, privacy-sensitive mobile applications (financial transactions, healthcare records, edge device telemetry) require zero outbound network access and guaranteed offline availability.

Laya models (`convaiinnovations/laya` and `convaiinnovations/laya-multilingual`) are non-autoregressive transformer architectures with parameter footprints of **322M** (mmBERT-base backbone) and **421M** (ModernBERT-large backbone). Because they evaluate decisions in a single forward pass without autoregressive token-by-token generation loops, they are uniquely suited for execution on the **Apple Neural Engine (ANE)** and **Apple Silicon GPU**.

This tech note documents the architecture of the `LayaOnDevice` engine, the Core ML conversion pipeline, marker position gathering, native Swift tokenization, and temperature calibration.

---

## Findings

### 1. Non-Autoregressive Decision Architecture & Marker Gathering
Unlike generative language models that autoregressively append tokens, Laya formulates decision evaluation as parallel scoring over option marker tokens:
1. **Sequence Format**:
   ```
   [CLS] <type> question: <instructions> [SEP] [MASK] opt0 [MASK] opt1 ... [SEP] state [SEP]
   ```
2. **Backbone Encoder**: The token sequence passes through the bidirectional transformer backbone (ModernBERT or mmBERT).
3. **Type Embedding & Decision Head**:
   - `type_emb`: An `Embedding(3, d)` mapping question type (0 = choice, 1 = score, 2 = noul) is added to hidden states: $h = h + \text{type\_emb}[\text{qtype}]$.
   - A 2-layer `TransformerEncoder` head refines representations across options and state.
4. **Gathering at Marker Positions**:
   - The token indices corresponding to each `[MASK]` token are tracked in `marker_pos: [1, max_options]`.
   - Hidden vectors at these positions are gathered: $m = h[:, \text{marker\_pos}, :]$.
   - The gathered vectors pass through a linear projection (`scorer`), yielding raw scalar logits per candidate option.

### 2. Native Core ML MIL Compilation
Converting this architecture with `coremltools` into Core ML's Model Intermediate Language (MIL) enables hardware-native execution:
- **Inputs**:
  - `input_ids`: `[1, max_seq_len]` (Int32)
  - `attention_mask`: `[1, max_seq_len]` (Int32)
  - `marker_pos`: `[1, max_options]` (Int32)
  - `marker_mask`: `[1, max_options]` (Float32, where 1.0 indicates a valid option and 0.0 indicates padding)
  - `qtype`: `[1]` (Int32)
- **Outputs**:
  - `logits`: `[1, max_options]` (Float32)
  - `act_logits`: `[1, 2]` (Float32)
- **ANE Shape Bucketing**:
  The Apple Neural Engine compiles ahead of time and performs with peak efficiency when sequence dimensions are bounded. Constraining sequence lengths to discrete buckets (e.g. 512 context, 32 options) avoids dynamic shape recompilation overhead at runtime.

### 3. Precision, Memory Footprint & Quantization
- In uncompressed FP32, ModernBERT-large (421M) occupies ~1.68 GB, which is too heavy for standard mobile memory budgets.
- Compiling to **FP16** halves the footprint to **~840 MB** for ModernBERT and **~644 MB** for mmBERT-base, which executes natively on the ANE.
- Utilizing `coremltools.optimize.coreml` 8-bit linear symmetric weight quantization (`OpLinearQuantizerConfig`) compresses weights to **~210 MB** (ModernBERT) and **~160 MB** (mmBERT) with $< 0.01$ loss in Brier score and accuracy, making on-device execution practical even on memory-constrained iOS devices.

### 4. Zero-Dependency Native Swift Tokenization
In production Apple apps, linking Python runtimes or heavy C++ tokenizers introduces significant binary bloat and build fragility. `LayaOnDevice` implements tokenization in pure Swift:
- **`ModernBERTTokenizer`**: Native Byte-level BPE / WordPiece tokenizer supporting `[CLS]` (50281), `[SEP]` (50282), `[PAD]` (50283), `[MASK]` (50284).
- **`MMBERTTokenizer`**: Native SentencePiece / BPE parser supporting mmBERT's 256k vocabulary with `<bos>` (2), `<eos>` (1), `<pad>` (0), `<mask_1>` (4).
- **`LayaSequenceBuilder`**: Port of Python's `build_sequence`, ensuring that option tokens, budgets, marker positions, and state truncation match upstream Python evaluation byte-for-byte.

### 5. Temperature Calibration
Decision probabilities from raw logits are calibrated using strictly proper scoring rules (RLCD):
- Temperature scaling parameters are indexed by question type and option count:
  - `tempBucket(qtype, k)`: e.g. `choice:2`, `choice:3-5`, `choice:6-10`, `choice:11+`, `noul:2`.
- Clamped between $[0.5, 5.0]$: values below 0.5 overly sharpen uncertainty, while values above 5.0 overly flatten probabilities.
- Softmax over scaled logits produces probabilities from which calibrated answer confidence (`max(p)`) is derived.

---

## Implications

1. **Sub-35ms Offline Latency**:
   Running on the Apple Neural Engine bypasses network latency entirely, returning decisions in 15–35 ms on Apple Silicon hardware (M-series / A-series).
2. **Absolute Data Privacy**:
   Sensitive PII, health information, or internal telemetry never leaves the device.
3. **Pluggable Foundation Models Ergonomics**:
   `LayaOnDeviceLanguageModel` conforms strictly to Apple's `LanguageModel`, allowing developers to switch between cloud, local HTTP server, and on-device Core ML simply by swapping the model instance passed to `LanguageModelSession`.

---

## Sources & References

- Apple Developer: [Core ML Model Intermediate Language (MIL) Overview](https://apple.github.io/coremltools/docs-guides/source/milcommunityops.html)
- GitHub: [NandhaKishorM/laya Repository](https://github.com/NandhaKishorM/laya)
- Tech Note 0001: [Bridging Decision Models into Apple Foundation Models via Channel Synthesis](0001-afm-decision-model-bridging.md)
- Tech Note 0006: [Pluggable System One Backends & Wire Compatibility with Laya HTTP Serving](0006-pluggable-system-one-backends-and-laya-serve.md)
