#!/usr/bin/env python3
"""
Convert Laya PyTorch decision models (ModernBERT 421M / mmBERT 322M) to Core ML (.mlpackage).
Optimized for Apple Neural Engine (ANE) and GPU inference on iOS 27+, macOS 27+, and visionOS 27+.

Usage:
    python convert_laya_to_coreml.py --model convaiinnovations/laya --output LayaModernBERT.mlpackage
    python convert_laya_to_coreml.py --model convaiinnovations/laya-multilingual --output LayaMMBERT.mlpackage --quantize 8bit
"""

import argparse
import json
import os
import shutil
import sys
import torch
import torch.nn as nn
from huggingface_hub import snapshot_download

try:
    import coremltools as ct
    from coremltools.optimize.coreml import (
        OpLinearQuantizerConfig,
        OptimizationConfig,
        linear_quantize_weights,
    )
except ImportError:
    print("coremltools not installed. Please run: pip install coremltools torch transformers safetensors")
    sys.exit(1)


class CoreMLWrapper(nn.Module):
    """Core ML exportable wrapper for Laya's DecisionModel.

    Takes fixed/bounded tensors:
      - input_ids: (1, max_seq_len) int32
      - attention_mask: (1, max_seq_len) int32
      - marker_pos: (1, max_options) int32
      - marker_mask: (1, max_options) float32 (1.0 for valid options, 0.0 for padding)
      - qtype: (1,) int32 (0=choice, 1=score, 2=noul)

    Returns:
      - logits: (1, max_options) float32
      - act_logits: (1, 2) float32
    """

    def __init__(self, model):
        super().__init__()
        self.model = model

    def forward(self, input_ids, attention_mask, marker_pos, marker_mask, qtype):
        input_ids = input_ids.to(torch.long)
        attention_mask = attention_mask.to(torch.long)
        marker_pos = marker_pos.to(torch.long)
        marker_mask = marker_mask.to(torch.bool)
        qtype = qtype.to(torch.long)

        logits, act_logits = self.model(
            input_ids=input_ids,
            attention_mask=attention_mask,
            marker_pos=marker_pos,
            marker_mask=marker_mask,
            qtype=qtype,
        )
        return logits, act_logits


def build_model_from_checkpoint(model_dir: str):
    """Instantiate Laya model architecture and load safetensors weights."""
    from safetensors.torch import load_file
    from transformers import AutoConfig, AutoModel

    cfg_path = os.path.join(model_dir, "rl_agent_config.json")
    with open(cfg_path) as f:
        cfg = json.load(f)

    enc_dir = os.path.join(model_dir, "encoder")
    enc_source = enc_dir if os.path.exists(enc_dir) else cfg.get("encoder", "answerdotai/ModernBERT-large")
    ecfg = AutoConfig.from_pretrained(enc_source)
    enc = AutoModel.from_config(ecfg, attn_implementation="sdpa")

    # Import Laya DecisionModel definition
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from laya.common import DecisionModel

    head_layers = cfg.get("head_layers", 2)
    model = DecisionModel(enc, head_layers=head_layers, n_act=2)

    weights_path = os.path.join(model_dir, "model.safetensors")
    weights = load_file(weights_path)
    model.load_state_dict(weights, strict=False)
    model.eval()
    return model, cfg


def convert_to_coreml(
    model: nn.Module,
    output_path: str,
    max_seq_len: int = 512,
    max_options: int = 32,
    quantize: str = "fp16"
):
    print(f"Tracing PyTorch model (seq_len={max_seq_len}, max_options={max_options})...")
    wrapper = CoreMLWrapper(model)
    wrapper.eval()

    example_input_ids = torch.zeros((1, max_seq_len), dtype=torch.int32)
    example_attention_mask = torch.ones((1, max_seq_len), dtype=torch.int32)
    example_marker_pos = torch.zeros((1, max_options), dtype=torch.int32)
    example_marker_mask = torch.ones((1, max_options), dtype=torch.float32)
    example_qtype = torch.zeros((1,), dtype=torch.int32)

    traced_model = torch.jit.trace(
        wrapper,
        (
            example_input_ids,
            example_attention_mask,
            example_marker_pos,
            example_marker_mask,
            example_qtype,
        ),
    )

    print("Converting to Core ML with MIL...")
    inputs = [
        ct.TensorType(name="input_ids", shape=(1, max_seq_len), dtype=int),
        ct.TensorType(name="attention_mask", shape=(1, max_seq_len), dtype=int),
        ct.TensorType(name="marker_pos", shape=(1, max_options), dtype=int),
        ct.TensorType(name="marker_mask", shape=(1, max_options), dtype=float),
        ct.TensorType(name="qtype", shape=(1,), dtype=int),
    ]
    outputs = [
        ct.TensorType(name="logits", dtype=float),
        ct.TensorType(name="act_logits", dtype=float),
    ]

    mlmodel = ct.convert(
        traced_model,
        inputs=inputs,
        outputs=outputs,
        convert_to="mlprogram",
        compute_precision=ct.precision.FLOAT16,
        minimum_deployment_target=ct.target.macOS15,
    )

    if quantize == "8bit":
        print("Applying 8-bit linear weight quantization...")
        op_config = OpLinearQuantizerConfig(mode="linear_symmetric", weight_threshold=512)
        config = OptimizationConfig(global_config=op_config)
        mlmodel = linear_quantize_weights(mlmodel, config=config)

    print(f"Saving Core ML package to {output_path}...")
    mlmodel.save(output_path)
    print("Core ML conversion completed successfully.")


def main():
    parser = argparse.ArgumentParser(description="Convert Laya PyTorch model to Core ML")
    parser.add_argument("--model", type=str, default="convaiinnovations/laya", help="Hugging Face repo or local path")
    parser.add_argument("--subfolder", type=str, default=None, help="Optional subfolder (e.g. multilingual)")
    parser.add_argument("--output", type=str, default="LayaModel.mlpackage", help="Output .mlpackage path")
    parser.add_argument("--seq-len", type=int, default=512, help="Maximum sequence length")
    parser.add_argument("--max-options", type=int, default=32, help="Maximum number of option markers")
    parser.add_argument("--quantize", choices=["fp16", "8bit"], default="fp16", help="Weight quantization mode")
    args = parser.parse_args()

    model_dir = args.model
    if not os.path.exists(model_dir):
        print(f"Downloading checkpoint from Hugging Face: {args.model}...")
        model_dir = snapshot_download(
            args.model,
            allow_patterns=["*rl_agent_config.json", "*model.safetensors", "*tokenizer/*", "*encoder/*"]
        )

    if args.subfolder:
        model_dir = os.path.join(model_dir, args.subfolder)

    model, cfg = build_model_from_checkpoint(model_dir)
    convert_to_coreml(
        model=model,
        output_path=args.output,
        max_seq_len=args.seq_len,
        max_options=args.max_options,
        quantize=args.quantize,
    )

    # Copy tokenizer.json alongside package if present
    tok_file = os.path.join(model_dir, "tokenizer", "tokenizer.json")
    if os.path.exists(tok_file):
        dest_tok = os.path.join(os.path.dirname(args.output) or ".", "tokenizer.json")
        shutil.copyfile(tok_file, dest_tok)
        print(f"Copied {tok_file} to {dest_tok}")


if __name__ == "__main__":
    main()
