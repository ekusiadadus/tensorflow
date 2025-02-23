/* Copyright 2019 The TensorFlow Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
==============================================================================*/

// This is the quantization definition file for TensorFlow.

#ifdef TF_Quantization
#else
#define TF_Quantization

include "mlir/IR/OpBase.td"
include "mlir/Dialect/Quant/QuantOpsBase.td"

//===----------------------------------------------------------------------===//
// QuantizedType definitions.
//===----------------------------------------------------------------------===//

// The base class of a quantized type.
class QuantizedType<string n, list<int> params, bit signed>
  : Type<And<[CPred<"$_self.isa<mlir::quant::QuantizedType>()">,
              CPred<"$_self.cast<mlir::quant::QuantizedType>()" #
                    ".getStorageTypeIntegralWidth() == " # !head(params)>]>,
    "Q" # !if (signed, "I", "UI") # !head(params) # " type"> {
  string name = n;
  string asTraitArgsStr =
    !interleave(params, ", ") # !if(signed, ", true", ", false");
}

// Uniform quantized types. Two integers "smantissa" and "sexp" are used to
// express the Mantissa and Exponent components of the floating-point scale so
// the scale of the quantized type is "smantissa * 10 ^ sexp".
class UInt8UniformQuantizedType<int zero_pt, int smantissa, int sexp>
    : QuantizedType<"Uniform",
                        [8, zero_pt, smantissa, sexp, 0, 255], 0>;
class Int8UniformQuantizedType<int zero_pt, int smantissa, int sexp>
    : QuantizedType<"Uniform",
                        [8, zero_pt, smantissa, sexp, -128, 127], 1>;

// General uniform quantized types. The definitions can be used to specify
// operand's tensor types.
def QUI8 : QuantizedType<"Uniform", [8], 0>;
def QI8 : QuantizedType<"Uniform", [8], 1>;
def QUI16 : QuantizedType<"Uniform", [16], 0>;
def QI16 : QuantizedType<"Uniform", [16], 1>;
def QUI32 : QuantizedType<"Uniform", [32], 0>;
def QI32 : QuantizedType<"Uniform", [32], 1>;

//===----------------------------------------------------------------------===//
// TFL native op traits (for quantization).
//
// Ops in this link should have those traits specified:
// https://www.tensorflow.org/lite/performance/quantization_spec
//===----------------------------------------------------------------------===//

def FixedOutputRangeInterface : OpInterface<
  "FixedOutputRangeInterface"> {
  let description = [{
    Interface for defining the fixed output range.
  }];

  let methods = [
    InterfaceMethod<
      [{Returns the fixed output range.}],
      "UniformQuantizedType", "GetFixedOutputRange",
      (ins "bool":$sign, "int":$bit_width)
    >,
  ];
}

def AffineQuantizedOpInterface : OpInterface<
  "AffineQuantizedOpInterface"> {
  let description = [{
    Interface for affine quantized ops (conv2d, fully_connected, etc.)
  }];

  let methods = [
    InterfaceMethod<
      [{Returns the affine operand index.}],
      "int", "GetAffineOperandIndex",
      (ins), [{}], [{return 1;}]>,
    InterfaceMethod<
      [{Returns whether narrow range is required for the affine operand.}],
      "bool", "RequiredNarrowRangeAffineOperand",
      (ins), [{}], [{return true;}]>,
    InterfaceMethod<
      [{Returns quantization dim for the affine operand.}],
      "int", "GetQuantizationDimIndex",
      (ins)>,
    InterfaceMethod<
      [{Returns the dimension index of the output channels.}],
      "int", "GetChannelDimIndex", (ins)
    >,
  ];
}

def SameOperandsAndResultsScale : OpInterface<"SameScalesOpInterface"> {
  let description = [{
    Interface for ops potentially have same operands and results scales.
  }];

  let methods = [
    InterfaceMethod<
      [{Returns whether same operands and results scales are required.}],
      "bool", "RequiredSameOperandsAndResultsScale",
      (ins "bool":$sign, "int":$bit_width), [{}], [{return true;}]
    >,
    InterfaceMethod<
      [{Returns whether operands and results must have the same quantized axis.}],
      "bool", "RequiredSameQuantizedAxes",
      (ins), [{}], [{return true;}]
    >,
  ];

  let verify = [{
    return quant::VerifySameScales($_op);
  }];
}

// Specify this trait if the op has a fixed output value range.
class FixedResultScale<QuantizedType qt> : NativeOpTrait<!strconcat(
  "quant::FixedResult", qt.name, "Scale<", qt.asTraitArgsStr, ">::Impl")>;

// Specify this trait if the bias-th input of the op is a bias input, which
// needs a scale based on the scales of op1 and op2.
class AccumulatorUniformScale<int bias, int op1, int op2> : NativeOpTrait<
  !strconcat("quant::AccumulatorUniformScale<",
             !interleave([bias, op1, op2], ", "),
             ">::Impl")>;

// Specify the operand index of the coefficient operand for an affine op
// and also the quantization dimension if per-axis quantization is support.
// If the quantization dimension is -1, per-axis quantization isn't supported.
class AffineOpCoefficient<int dim, int index> : NativeOpTrait<
  !strconcat("quant::AffineOpCoefficient<",
             !interleave([dim, index], ", "),
             ">::Impl")>;

// Specify this trait if the op doesn't have quantizable output. We shouldn't
// apply quantization on this op.
def NoQuantizableResult : NativeOpTrait<"quant::NoQuantizableResult">;

// Specify this trait if the op supports dynamic range quantization.
def DynamicRangeQuantizableOp : NativeOpTrait<"quant::DynamicRangeQuantizableOp">;
#endif // TF_Quantization
