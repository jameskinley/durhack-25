import numpy as np
import torch
from transformers import AutoTokenizer, AutoModelForCausalLM
import coremltools as ct

model_name = "microsoft/phi-3-mini-4k-instruct"
tokenizer = AutoTokenizer.from_pretrained(model_name)
model = AutoModelForCausalLM.from_pretrained(model_name,
                                             torch_dtype=torch.float16).eval()

class WrappedModel(torch.nn.Module):
    def __init__(self, model): super().__init__(); self.model = model
    def forward(self, input_ids): return self.model(input_ids).logits

wrapped = WrappedModel(model)
example = tokenizer("Hello", return_tensors="pt")
input_ids = example["input_ids"].to(torch.int32)

print("Tracing…")
traced = torch.jit.trace(wrapped, input_ids)

print("Converting to Core ML…")
mlmodel = ct.convert(
    traced,
    convert_to="mlprogram",
    inputs=[ct.TensorType(name="input_ids",
                          shape=input_ids.shape,
                          dtype=np.int32)],
    compute_units=ct.ComputeUnit.ALL,
)

mlmodel.save("LocalSummarizer.mlpackage")
print("✅ Conversion complete.")
