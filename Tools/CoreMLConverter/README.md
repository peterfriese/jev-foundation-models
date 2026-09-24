# Core ML Conversion Pipeline for Laya

Convert Laya System 1 decision models (ModernBERT 421M and mmBERT 322M) into Apple Core ML packages (`.mlpackage`) optimized for the Apple Neural Engine (ANE) and GPU.

## Prerequisites

```bash
pip install -r requirements.txt
```

## Converting Checkpoints

### 1. English Model (`convaiinnovations/laya` — ModernBERT 421M)

```bash
python convert_laya_to_coreml.py \
    --model convaiinnovations/laya \
    --output LayaModernBERT.mlpackage \
    --seq-len 512 \
    --max-options 32 \
    --quantize fp16
```

### 2. Multilingual Model (`convaiinnovations/laya-multilingual` — mmBERT 322M)

```bash
python convert_laya_to_coreml.py \
    --model convaiinnovations/laya \
    --subfolder multilingual \
    --output LayaMultilingual.mlpackage \
    --seq-len 1024 \
    --max-options 32 \
    --quantize 8bit
```

## Compiling for Apple Platforms

Compile the `.mlpackage` into a `.mlmodelc` bundle for embedding into your Xcode app:

```bash
xcrun coremlcompiler compile LayaModernBERT.mlpackage .
```

This generates `LayaModernBERT.mlmodelc`, which can be added directly to your application bundle or dynamically downloaded on device.
