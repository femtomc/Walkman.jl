# Generate.
function trace(fn::Function)
    ctx = disablehooks(TraceCtx(metadata = UnconstrainedGenerateMeta(Trace())))
    ret = Cassette.overdub(ctx, fn)
    ctx.metadata.fn = fn
    ctx.metadata.args = ()
    ctx.metadata.ret = ret
    return ctx, ctx.metadata.tr, ctx.metadata.tr.score
end

function trace(ctx::TraceCtx{M},
               fn::Function) where M <: UnconstrainedGenerateMeta
    ret = Cassette.overdub(ctx, fn)
    ctx.metadata.fn = fn
    ctx.metadata.args = ()
    ctx.metadata.ret = ret
    return ctx, ctx.metadata.tr, ctx.metadata.tr.score
end

function trace(fn::Function, 
               constraints::Dict{Address, T}) where T
    ctx = disablehooks(TraceCtx(metadata = GenerateMeta(Trace(), constraints)))
    ret = Cassette.overdub(ctx, fn)
    ctx.metadata.fn = fn
    ctx.metadata.args = ()
    ctx.metadata.ret = ret
    return ctx, ctx.metadata.tr, ctx.metadata.tr.score
end

function trace(fn::Function, 
               args::Tuple)
    ctx = disablehooks(TraceCtx(metadata = UnconstrainedGenerateMeta(Trace())))
    ret = Cassette.overdub(ctx, fn, args...)
    ctx.metadata.fn = fn
    ctx.metadata.args = args
    ctx.metadata.ret = ret
    return ctx, ctx.metadata.tr, ctx.metadata.tr.score
end

function trace(ctx::TraceCtx{M},
               fn::Function, 
               args::Tuple) where M <: UnconstrainedGenerateMeta
    ret = Cassette.overdub(ctx, fn, args...)
    ctx.metadata.fn = fn
    ctx.metadata.args = args
    ctx.metadata.ret = ret
    return ctx, ctx.metadata.tr, ctx.metadata.tr.score
end

function trace(fn::Function, 
               args::Tuple, 
               constraints::Dict{Address, T}) where T
    ctx = disablehooks(TraceCtx(metadata = GenerateMeta(Trace(), constraints)))
    ret = Cassette.overdub(ctx, fn, args...)
    ctx.metadata.fn = fn
    ctx.metadata.args = args
    ctx.metadata.ret = ret
    return ctx, ctx.metadata.tr, ctx.metadata.tr.score
end

# Regenerate.
function trace(ctx::TraceCtx{M}, 
               fn::Function, 
               args::Tuple) where M <: RegenerateMeta
    ret = Cassette.overdub(ctx, fn, args...)
    ctx.metadata.fn = fn
    ctx.metadata.args = args
    ctx.metadata.ret = ret
   
    # Discard
    discard = Dict{Address, Choice}()
    discard_score = 0.0
    for (k, v) in ctx.metadata.tr.chm
        !(k in ctx.metadata.visited) && begin
            discard_score += ctx.metadata.tr.chm[k].score
            discard[k] = v
            delete!(ctx.metadata.tr.chm, k)
        end
    end
    
    ctx.metadata.tr.score -= discard_score
    return ctx, ctx.metadata.tr, ctx.metadata.tr.score
end

function trace(ctx::TraceCtx{M}, 
               fn::Function) where M <: RegenerateMeta
    ret = Cassette.overdub(ctx, fn)
    ctx.metadata.fn = fn
    ctx.metadata.args = ()
    ctx.metadata.ret = ret
   
    # Discard
    discard = Dict{Address, Choice}()
    discard_score = 0.0
    for (k, v) in ctx.metadata.tr.chm
        !(k in ctx.metadata.visited) && begin
            discard_score += ctx.metadata.tr.chm[k].score
            discard[k] = v
            delete!(ctx.metadata.tr.chm, k)
        end
    end
    
    ctx.metadata.tr.score -= discard_score
    return ctx, ctx.metadata.tr, ctx.metadata.tr.score
end

# Update.
function trace(ctx::TraceCtx{M},
               fn::Function,
               args::Tuple) where M <: UpdateMeta
    ret = Cassette.overdub(ctx, fn, args...)
    ctx.metadata.fn = fn
    ctx.metadata.args = args
    ctx.metadata.ret = ret
    !isempty(ctx.metadata.constraints) && begin
        error("UpdateError: tracing did not visit all addresses in constraints.")
    end

    # Discard.
    discard = typeof(ctx.metadata.tr.chm)()
    discard_score = 0.0
    for (k, v) in ctx.metadata.tr.chm
        !(k in ctx.metadata.visited) && begin
            discard_score += ctx.metadata.tr.chm[k].score
            discard[k] = v
            delete!(ctx.metadata.tr.chm, k)
        end
    end

    ctx.metadata.tr.score -= discard_score
    return ctx, ctx.metadata.tr, ctx.metadata.tr.score, discard
end

function trace(ctx::TraceCtx{M},
               fn::Function) where M <: UpdateMeta
    ret = Cassette.overdub(ctx, fn)
    ctx.metadata.fn = fn
    ctx.metadata.args = ()
    ctx.metadata.ret = ret
    !isempty(ctx.metadata.constraints) && begin
        error("UpdateError: tracing did not visit all addresses in constraints.")
    end

    # Discard. Note - this is clever AF, and I was too stupid to see why this makes sense. Shoutout to Gen + A Lew.
    discard = Dict{Address, Choice}()
    discard_score = 0.0
    for (k, v) in ctx.metadata.tr.chm
        !(k in ctx.metadata.visited) && begin
            discard_score += ctx.metadata.tr.chm[k].score
            discard[k] = v
            delete!(ctx.metadata.tr.chm, k)
        end
    end
    
    ctx.metadata.tr.score -= discard_score
    return ctx, ctx.metadata.tr, ctx.metadata.tr.score, discard
end