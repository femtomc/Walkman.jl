module Jaynes

using Reexport

import Base.display
import Base: getindex, haskey, iterate, isempty, convert, collect, getindex, setindex!, push!, merge, merge!, get, filter, length, ndims, keys, +, rand, size
import Base: isless
import Base: Pair

# Jaynes implements the abstract GFI from Gen.
import Gen
import Gen: Selection, ChoiceMap, Trace, GenerativeFunction
import Gen: DynamicChoiceMap, EmptySelection
import Gen: get_value, has_value
import Gen: get_values_shallow, get_submaps_shallow
import Gen: get_args, get_retval, get_choices, get_score, get_gen_fn, has_argument_grads, accepts_output_grad, get_params
import Gen: select, choicemap
import Gen: simulate, generate, project, propose, assess, update, regenerate
import Gen: init_param!, accumulate_param_gradients!, choice_gradients, init_update_state, apply_update!

# Gen diff types.
import Gen: Diff, UnknownChange, NoChange
import Gen: SetDiff, DictDiff, VectorDiff, IntDiff, Diffed

# Yarrrr I'm a com-pirate!
using MacroTools
using IRTools
using IRTools: @dynamo, IR, xcall, arguments, insertafter!, recurse!, isexpr, self, argument!, Variable, meta, renumber, Pipe, finish, blocks, predecessors, dominators, block, successors, Block, block!, branches, Branch, branch!, CFG, stmt
using Random
using Mjolnir: inline_consts!, partials!, ssa!, prune!
using InteractiveUtils: subtypes

# Static selektor.
using StaticArrays

@reexport using Distributions
import Distributions: Distribution
import Distributions: logpdf

# Differentiable.
@reexport using Zygote
using ForwardDiff
using ForwardDiff: Dual
using DistributionsAD

# Plotting.
using UnicodePlots: lineplot

# ------------ Toplevel importants ------------ #

const Address = Union{Int, Symbol, Pair}

# This is primarily used when mapping choice maps to arrays.
isless(::Symbol, ::Pair) = true
isless(::Pair, ::Symbol) = false
isless(::Int, ::Symbol) = true
isless(::Symbol, ::Int) = false
isless(::Int, ::Pair) = true
isless(::Pair, ::Int) = false

include("unwrap.jl")
include("kludges.jl")

# Jaynes introduces a new type of generative function.
abstract type TypedGenerativeFunction{N, R, Tr, T} <: GenerativeFunction{R, Tr} end

# ------------ includes ------------ #

include("core.jl")
export trace

include("compiler.jl")
export NoChange, Change, ScalarDiff, IntDiff, DictDiff, SetDiff, VectorDiff, BoolDiff, Diffed
export Δ, _propagate
export prepare_ir!, infer!, @abstract, InterpretationContext
export detect_switches, detect_kernel

include("pipelines.jl")
export NoStatic, DefaultPipeline, StaticWithLints, SpecializerPipeline, AutomaticAddressingPipeline
export record_cached!

include("macros.jl")
export @primitive, @jaynes

# Tracer language features.
export learnable, fillable, factor

# Compiler.
export NoChange, UndefinedChange
export construct_graph, compile_function

# Vectors to dynamic value address map.
export dynamic

# Selections and parameters.
export select, target, static, array, learnables
export anywhere, intersection, union
export compare, update_learnables, merge!, merge

# Gen compat.
include("gen_fn_interface.jl")

export JFunction, JTrace
export get_analysis, get_ir, get_fn
export init_param!, accumulate_param_gradients!, choice_gradients
export choicemap, select
export get_value, has_value
export get_params_grad

# Contexts.
export generate
export simulate
export update
export propose
export regenerate
export assess
export get_learnable_gradients, get_choice_gradients
export get_learnable_gradient, get_choice_gradient

constrain(v::Vector{Pair{T, K}}) where {T <: Tuple, K} = JChoiceMap(target(v))
export constrain

# Typing rules.
include("typing_rules.jl")
export absint

# Utilities.
export display, getindex, haskey, get_score, get_ret, flatten, lineplot

end # module
