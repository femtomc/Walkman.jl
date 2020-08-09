function exchange(addr::T, cl::C, ker) where {K <: UnconstrainedSelection, C <: CallSite, T <: Tuple}
    local target = getindex(cl, addr)
    new, acc = apply_kernel(ker, target)
    sel = selection(addr => get_selection(new))
    ret, new, _ = update(sel, cl)
    new, true
end

function exchange(addr::Tuple{}, cl::C, ker) where {K <: UnconstrainedSelection, C <: CallSite}
    local target = cl
    new, acc = apply_kernel(ker, target)
    sel = get_selection(new)
    ret, new, _ = update(sel, cl)
    new, true
end

apply_kernel(ker, cl::HierarchicalCallSite) = ker(cl)
apply_kernel(ker, cl::VectorizedCallSite) = ker(cl)