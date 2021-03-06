# ------------ Common support errors, checked statically. ------------ #

abstract type SupportException <: Exception end


# ------------ Mismatch measures across flow of control paths ------------ #

struct MeasureMismatch <: SupportException
    types::Dict
    violations::Set{Symbol}
end
function Base.showerror(io::IO, e::MeasureMismatch)
    println("\u001b[31m(SupportException):\u001b[0m Base measure mismatch.")
    for (k, v) in e.types
        println(io, " $k => $(map(l -> pretty(l), v))")
    end
    println(io, " Violations: $(e.violations)")
    println(io, "\u001b[32mFix: ensure that base measures match for addresses shared across branches in your model.\u001b[0m")
end

# Checks that addresses across flow of control paths share the same base measure. 
# Assumes that the input IR has been inferred (using e.g. the trace type inference).
function check_branch_support(tr)
    types = Dict()
    for (v, st) in tr
        st.expr isa Expr || continue
        st.expr.head == :call || continue
        st.expr.args[1] == trace || continue
        st.expr.args[2] isa QuoteNode || continue
        addr = st.expr.args[2].value
        if haskey(types, addr)
            st.type isa NamedTuple ? push!(types[addr], st.type) : push!(types[addr], supertype(st.type))
        else
            if st.type isa NamedTuple
                Any[_lift(st.type)]
            else
                Any[supertype(_lift(st.type))]
            end
        end
    end
    se = MeasureMismatch(types, Set{Symbol}([]))
    for (addr, supports) in types
        length(supports) == 1 && continue
        foldr(==, supports) || begin
            push!(se.violations, addr)
        end
    end
    se
end

# ------------ Duplicate addresses across flow of control paths ------------ #

struct DuplicateAddresses <: SupportException
    violations::Set{Symbol}
    paths::Set
end
function Base.showerror(io::IO, e::DuplicateAddresses)
    println("\u001b[31m(SupportException):\u001b[0m Duplicate addresses along same flow of control path in model program.")
    println(io, " Violations: $(e.violations)")
    println(io, " On flow of control paths:")
    for p in e.paths
        println(io, " $p")
    end
    println(io, "\u001b[32mFix: ensure that all addresses in any execution path through the program are unique.\u001b[0m")
end

# Checks for duplicate symbols along each flow of control path.
# Expects untyped IR.
function check_duplicate_symbols(ir, paths)
    keys = Set{Symbol}([])
    blks = map(blk -> IRTools.BasicBlock(blk), blocks(ir))
    addresses = Dict( path => Symbol[] for path in paths )
    de = DuplicateAddresses(Set{Symbol}([]), Set([]))
    for (v, st) in ir
        st.expr isa Expr || continue
        st.expr.head == :call || continue
        unwrap(st.expr.args[1]) == :trace || continue
        st.expr.args[2] isa QuoteNode || continue
        addr = st.expr.args[2].value

        # Fix: can be much more efficient.
        relevant = Iterators.filter(Iterators.enumerate(blks)) do (ind, blk)
            st in blk.stmts
        end

        # Filter paths, then check if already seen on path.
        for (ind, blk) in relevant
            for p in filter(p -> ind in p, paths)
                if addr in addresses[p]
                    push!(de.violations, addr)
                    push!(de.paths, p)
                else
                    push!(addresses[p], addr)
                end
            end
        end
    end
    de
end

# ------------ Pipeline ------------ #

function support_checker(absint_ctx::InterpretationContext, fn, arg_types...)
    println("\u001b[34m\e[1m   Method name:\u001b[0m \e[4m$(fn)\u001b[0m")
    println("\u001b[34m\e[1m   Method argument types:\u001b[0m $(arg_types)\u001b[0m\n")
    errs = Exception[]
    ir = lower_to_ir(fn, arg_types...)
    paths = get_control_flow_paths(ir)
    push!(errs, check_duplicate_symbols(ir, paths))
    tr = infer_support_types(absint_ctx, fn, arg_types...)
    tr isa Missing ? println("\u001b[33m ? (SupportChecker): model program could not be traced.\n    The following checks cannot be run:\n\t* Branch support checks\u001b[0m\n") : push!(errs, check_branch_support(tr))
    any(map(errs) do err
            if isempty(err.violations)
                false
            else
                Base.showerror(stdout, err)
                true
            end
        end) ? error("SupportError found.") : println("\u001b[32m ✓ (SupportChecker): no errors detected by static checks.\u001b[0m\n")
    !(tr isa Missing) && begin
        if !control_flow_check(tr)
            println("\u001b[33m ? (SupportChecker): Detected control flow in model IR.\n    Static trace typing requires that control flow be extracted into combinators.\n    Proceeding to compile with \e[1mMissing\u001b[0m \u001b[33mtrace type.\u001b[0m\n")
            return missing
        else
            try
                return trace_type(tr)
            catch e
                println("\u001b[33m ? (SupportChecker): Failed to compute trace type. Caught:\n$e.\n\nProceeding to compile with \e[1mMissing\u001b[0m \u001b[33mtrace type.\u001b[0m")
                return missing
            end
        end
    end
    return missing
end
