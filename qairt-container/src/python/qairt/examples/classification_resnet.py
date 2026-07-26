# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

import cv2
import numpy as np
import qairt
import argparse
import os
import sys
import contextlib

# Parse arguments
parser = argparse.ArgumentParser(description="ResNet Image Classification (QAIRT)")
parser.add_argument("--model", required=True, help="Path to .dlc model file")
parser.add_argument("--image", required=True, help="Path to a single image OR a directory of images")
parser.add_argument("--label", required=True, help="Path to labels file")
parser.add_argument(
    "--mode",
    default="single",
    choices=["single", "stream"],
    help="Inference mode: 'single' (one-shot per image) or 'stream' (QAIRT stream execution)"
)
parser.add_argument("--output", default="results", help="Directory to save annotated output images")
parser.add_argument("--topk", type=int, default=5, help="Number of top predictions to show")
args = parser.parse_args()

MODEL_PATH = args.model
INPUT_PATH = args.image
LABELS_PATH = args.label
BACKEND     = "HTP"
INPUT_SIZE  = (224, 224)  # Target (width, height) to resize input image before inference
TOP_K       = args.topk
OUTPUT_DIR  = args.output
EXEC_MODE   = args.mode

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".bmp", ".tiff"}

def load_labels(path):
    with open(path) as f:
        return [line.strip() for line in f]

def collect_image_paths(input_path):
    """Return a list of image paths from a single file or a directory."""
    if os.path.isfile(input_path):
        return [input_path]
    elif os.path.isdir(input_path):
        paths = sorted([
            os.path.join(input_path, f)
            for f in os.listdir(input_path)
            if os.path.splitext(f)[1].lower() in IMAGE_EXTS
        ])
        if not paths:
            print(f"[WARNING] No supported images found in directory: {input_path}")
        return paths
    else:
        raise FileNotFoundError(f"Input path not found: {input_path}")

def preprocess_image(path):
    image = cv2.imread(path)

    if image is None:
        raise ValueError(f"Could not read image: {path}")

    image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    image = cv2.resize(image, INPUT_SIZE)
    image = image.astype(np.float32) / 255.0   # Normalize to [0, 1]
    return np.expand_dims(image, axis=0)         # Add batch dim → (1, 224, 224, 3)

def softmax(x):
    x = x.flatten()
    e = np.exp(x - np.max(x))
    return e / np.sum(e)

@contextlib.contextmanager
def suppress_output():
    """Suppress C-level and DSP backend console noise during model ops."""
    with open(os.devnull, 'w') as devnull:
        old_stdout = sys.stdout
        old_stderr = sys.stderr

        sys.stdout = devnull
        sys.stderr = devnull

        try:
            yield
        finally:
            sys.stdout = old_stdout
            sys.stderr = old_stderr

def save_annotated_image(image_path, label, confidence, output_dir):
    """Overlay top-1 prediction on the image and save to output_dir."""
    os.makedirs(output_dir, exist_ok=True)

    image = cv2.imread(image_path)

    FONT       = cv2.FONT_HERSHEY_SIMPLEX
    FONT_SCALE = 0.8
    THICKNESS  = 2
    PADDING    = 10
    TEXT_COLOR = (255, 255, 255)  # white text
    BOX_COLOR  = (0, 150, 0)      # dark green background box

    text = f"{label}: {confidence:.2f}%"

    (text_w, text_h), baseline = cv2.getTextSize(text, FONT, FONT_SCALE, THICKNESS)

    x, y = PADDING, PADDING + text_h

    # Filled background rectangle for contrast
    cv2.rectangle(
        image,
        (x - PADDING, y - text_h - PADDING),
        (x + text_w + PADDING, y + baseline),
        BOX_COLOR,
        cv2.FILLED
    )

    # Text on top
    cv2.putText(image, text, (x, y), FONT, FONT_SCALE, TEXT_COLOR, THICKNESS)

    out_path = os.path.join(output_dir, os.path.basename(image_path))
    cv2.imwrite(out_path, image)
    return out_path

def print_results(image_path, probs, labels, top_k):
    top_indices = np.argsort(probs)[::-1][:top_k]

    print(f"\nImage : {os.path.basename(image_path)}")
    print(f"Top-{top_k} Predictions")
    print("-" * 50)

    for rank, idx in enumerate(top_indices, 1):
        print(f"  {rank}. {labels[idx]:<40} {probs[idx] * 100:.2f}%")

    return top_indices[0], probs[top_indices[0]] * 100

def run_single_shot(model, image_paths, labels):
    for image_path in image_paths:
        try:
            input_tensor = preprocess_image(image_path)

            with suppress_output():
                result = model(inputs=input_tensor, backend=BACKEND)
                output_names = [name for name, _ in result]
                raw_output = result[output_names[0]]

            probs = softmax(raw_output)
            top1_idx, top1_conf = print_results(image_path, probs, labels, TOP_K)
            out = save_annotated_image(image_path, labels[top1_idx], top1_conf, OUTPUT_DIR)
            print(f" Annotated image saved {out}")
        except Exception as e:
            print(f"[ERROR] Skipping {image_path}: {e}")

def run_stream(model, image_paths, labels):
    print(f"\nStarting stream execution over {len(image_paths)} image(s)...")

    model.initialize(backend=BACKEND)

    try:
        for image_path in image_paths:
            try:
                input_tensor = preprocess_image(image_path)

                with suppress_output():
                    result = model(inputs=input_tensor)
                    output_names = [name for name, _ in result]
                    raw_output = result[output_names[0]]

                probs = softmax(raw_output)
                top1_idx, top1_conf = print_results(image_path, probs, labels, TOP_K)
                out = save_annotated_image(image_path, labels[top1_idx], top1_conf, OUTPUT_DIR)
                print(f" Annotated image saved  {out}")
            except Exception as e:
                print(f"[ERROR] Skipping {image_path}: {e}")

    finally:
        model.destroy()

def main():
    labels = load_labels(LABELS_PATH)
    image_paths = collect_image_paths(INPUT_PATH)

    if not image_paths:
        print("[ERROR] No images to process. Exiting.")
        return

    print(
        f"\nFound {len(image_paths)} image(s) | "
        f"Mode: {EXEC_MODE.upper()} | Backend: {BACKEND}"
    )

    with suppress_output():
        model = qairt.load(MODEL_PATH)

    if EXEC_MODE == "stream":
        run_stream(model, image_paths, labels)
    else:
        run_single_shot(model, image_paths, labels)

    print(f"\nDone. Annotated images saved in: {OUTPUT_DIR}/")

if __name__ == "__main__":
    main()
