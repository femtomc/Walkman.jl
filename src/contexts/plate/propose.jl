# ------------ Choice sites ------------ #

@inline function (ctx::ProposeContext)(c::typeof(plate), 
                                       addr::T, 
                                       d::Distribution{K},
                                       len::Int) where {T <: Address, K}
    v_ret = Vector{eltype(d)}(undef, len)
    v_cs = Vector{ChoiceSite{eltype(d)}}(undef, len)
    for i in 1:len
        visit!(ctx, addr => i)
        s = rand(d)
        score = logpdf(d, s)
        cs = ChoiceSite(score, s)
        v_ret[i] = s
        v_cs[i] = cs
    end
    sc = sum(map(v_cs) do cs
                 get_score(cs)
             end)
    add_call!(ctx, addr, VectorCallSite{typeof(plate)}(VectorTrace(v_cs), sc, d, len, (), v_ret))
    return v_ret
end

# ------------ Vector call sites ------------ #

@inline function (ctx::ProposeContext)(c::typeof(plate), 
                                       addr::Address, 
                                       call::Function, 
                                       args::Vector)
    visit!(ctx, addr)
    visit!(ctx, addr => 1)
    len = length(args)
    ret, submap, sc = propose(call, args[1]...)
    v_ret = Vector{typeof(ret)}(undef, len)
    v_submap = Vector{typeof(submap)}(undef, len)
    v_ret[1] = ret
    v_submap[1] = submap
    for i in 2:len
        visit!(ctx, addr => i)
        ret, submap, w = propose(call, args[i]...)
        v_ret[i] = ret
        v_submap[i] = submap
        sc += w
    end
    set_sub!(ctx.map, addr, VectorMap{Value}(v_submap))
    ctx.score += sc
    return v_ret
end

# ------------ Convenience ------------ #

function propose(fn::typeof(plate), call::Function, args::Vector)
    ctx = Propose(params)
    addr = gensym()
    ret = ctx(fn, addr, call, args)
    return ret, get_sub(ctx.tr, addr), ctx.score
end

function propose(params, fn::typeof(plate), call::Function, args::Vector)
    ctx = Propose(params)
    addr = gensym()
    ret = ctx(fn, addr, call, args)
    return ret, get_sub(ctx.tr, addr), ctx.score
end

function propose(fn::typeof(plate), d::Distribution{K}, len::Int) where K
    ctx = Propose()
    addr = gensym()
    ret = ctx(fn, addr, d, len)
    return ret, get_sub(ctx.tr, addr), ctx.score
end
