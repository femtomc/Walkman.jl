# ------------ Core ------------ #

Base.iterate(s::Symbol) = s

# Special calls with fallbacks.
function rand(addr::A, d::Distribution{T}) where {A <: Address, T}
    @info "(rand) call with address $addr evaluated outside of a context tracer.\nThis normally occurs because you're not matching dispatch correctly, or you've forgotten to tell a context tracer to recurse into a call site (wrap it with rand)."
    return rand(d)
end
function rand(addr::A, fn::Function, args...) where A <: Address
    @info "(rand) call with address $addr evaluated outside of a context tracer.\nThis normally occurs because you're not matching dispatch correctly, or you've forgotten to tell a context tracer to recurse into a call site (wrap it with rand)."
    return fn(args...)
end

# Special features - must be evaluated by context tracer.
learnable(addr::A) where {A <: Address} = error("(learnable) call with address $addr evaluated outside of a context tracer.\nThis normally occurs because you're not matching dispatch correctly.")
fillable(addr::A) where {A <: Address} = error("(fillable) call with address $addr evaluated outside of a context tracer.\nThis normally occurs because you're not matching dispatch correctly.")
plate(addr::A, args...) where A <: Address = error("(plate) call with address $addr evaluated outside of a context tracer.\nThis normally occurs because you're not matching dispatch correctly.")
markov(addr::A, args...) where A <: Address = error("(markov) call with address $addr evaluated outside of a context tracer.\nThis normally occurs because you're not matching dispatch correctly.")
cond(addr::A, args...) where A <: Address = error("(cond) call with address $addr evaluated outside of a context tracer.\nThis normally occurs because you're not matching dispatch correctly.")
factor(args...) = args

# ------------ Call sites ------------ #

abstract type CallSite <: AddressMap{Choice} end

@inline has_value(cs::C, addr) where C <: CallSite = has_value(cs.trace, addr)
@inline get_value(cs::C, addr) where C <: CallSite = get_value(get_sub(cs.trace, addr))
@inline get_sub(cs::C, addr::A) where {C <: CallSite, A <: Address} = get_sub(cs.trace, addr)
@inline get_sub(cs::C, addr::Tuple{}) where {C <: CallSite, A <: Address} = get_sub(cs.trace, addr)
@inline get_sub(cs::C, addr::Tuple{A}) where {C <: CallSite, A <: Address} = get_sub(cs.trace, addr)
@inline get_sub(cs::C, addr::Tuple) where C <: CallSite = get_sub(cs.trace, addr::Tuple)
@inline get_score(cs::C) where C <: CallSite = cs.score
@inline get_ret(cs::C) where C <: CallSite = cs.ret
@inline get_args(cs::C) where C <: CallSite = cs.args
@inline get_trace(cs::C) where C <: CallSite = cs.trace
@inline haskey(cs::C, addr) where C <: CallSite = haskey(cs.trace, addr)
@inline getindex(cs::C, addrs...) where C <: CallSite = getindex(cs.trace, addrs...)
@inline shallow_iterator(cs::C) where C <: CallSite = shallow_iterator(cs.trace)

@inline collect!(par::T, addrs::Vector, chd::Dict, cl::C, meta) where {T <: Tuple, C <: CallSite} = collect!(par, addrs, chd, get_trace(cl), meta)

function Base.display(call::C; 
                      fields::Array{Symbol, 1} = [:val],
                      show_full = false) where C <: CallSite
    println("  __________________________________\n")
    println("               Playback\n")
    println(" type : $C\n")
    map(fieldnames(C)) do f
        val = getfield(call, f)
        typeof(val) <: Real && begin
            println(" $(f) : $(val)\n")
            return
        end
        println(" $(f) : $(typeof(val))\n")
    end
    println("  __________________________________\n")
end

# ------------ includes ------------ #

include("traces/dynamic.jl")
include("traces/vector.jl")
include("traces/conditional.jl")

# ------------ Documentation ------------ #

@doc(
"""
```julia
rand(addr::A, d::Distribution{T}) where {A <: Address, T}
rand(addr::A, fn::Function, args...) where A <: Address
```

A `rand` call with a first argument which is a subtype of `Address` informs the context context tracers that this call should be intercepted and recorded. If the call includes a distribution as final argument, a context tracer will create a `ChoiceSite` representation and reason about the call accordingly. If the call includes a function and a set of arguments, a context tracer will create a `HierarchicalCallSite` representation and recurse into the call.
""", rand)

@doc(
"""
```julia
struct ChoiceSite{T} <: RecordSite
    score::Float64
    val::T
end
```
A record of a random sample at an addressed `rand` call with a `Distribution` instance. Keeps the value of the random sample and the `logpdf` score.
""", ChoiceSite)

@doc(
"""
```julia
abstract type CallSite <: RecordSite end
```
Abstract base type of all call sites.
""", CallSite)

@doc(
"""
```julia
abstract type Trace end
```
Abstract base type of all traces.
""", Trace)

@doc(
"""
```julia
struct HierarchicalTrace <: Trace
    calls::Dict{Address, CallSite}
    choices::Dict{Address, ChoiceSite}
    params::Dict{Address, LearnableSite}
    end
end
```
Execution trace which allows the tracking of randomness metadata in a function call.
""", HierarchicalTrace)

@doc(
"""
```julia
struct VectorizedTrace{C <: RecordSite} <: Trace
    subrecords::Vector{C}
    params::Dict{Address, LearnableSite}
end

```
Structured execution trace for `markov` and `plate` calls. The dependency structure interpretation of the `subrecords` vector depends on the call. For `markov`, the structure is Markovian. For `plate`, each element is drawn IID from the program or distribution provided to `plate`.
""", VectorizedTrace)

@doc(
"""
```julia
struct HierarchicalCallSite{J, K} <: CallSite
    trace::HierarchicalTrace
    score::Float64
    fn::Function
    args::J
    ret::K
end
```
A record of a black-box call (e.g. no special context tracer language features). Records the `fn` and `args` for the call, as well as the `ret` return value.
""", HierarchicalCallSite)

@doc(
"""
```julia
struct VectorizedCallSite{F <: Function, C <: RecordSite, J, K} <: CallSite
    trace::VectorizedTrace{C}
    score::Float64
    fn::Function
    args::J
    ret::Vector{K}
end
```
A record of a call site using the special `plate` and `markov` context tracer language features. Informs a context tracer that the call conforms to a special pattern of randomness dependency, which allows the storing of `Trace` instances sequentially in a vector.
""", VectorizedCallSite)
