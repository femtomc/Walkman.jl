# --------------- INFERENCE COMPILER --------------- #

struct InferenceCompiler
    spine::Flux.Recur
    decoder_heads::Dict{Address, Chain}
    encoder_heads::Dict{Address, Chain}
    latent_dim::Int
    function InferenceCompiler(latent_dim::Int)
        rnn = RNN(latent_dim, latent_dim)
        decoder_heads = Dict{Address, Dense}()
        encoder_heads = Dict{Address, Dense}()
        rnn.state = rand(Normal(0.0, 1.0), latent_dim)
        new(rnn, decoder_heads, encoder_heads, latent_dim)
    end
end

function generate_decoder_head(ic::InferenceCompiler, addr::Address, args::Array{Float64, N}) where {T, N}
    shape = foldr((x, y) -> x * y, size(args))
    head = Chain(Dense(ic.latent_dim, 128), Dense(128, shape))
    ic.decoder_heads[addr] = head
end

function generate_decoder_head(ic::InferenceCompiler, addr::Address, args::Tuple{Vararg{Float64}})
    shape = length(args)
    head = Chain(Dense(ic.latent_dim, 128), Dense(128, shape))
    ic.decoder_heads[addr] = head
end

function generate_encoder_head(ic::InferenceCompiler, addr::Address, args::Array{Float64, N}) where {T, N}
    shape = foldr((x, y) -> x * y, size(args))
    head = Chain(Dense(shape, 128), Dense(128, ic.latent_dim))
    ic.encoder_heads[addr] = head
end

function generate_encoder_head(ic::InferenceCompiler, addr::Address, args::Tuple{Vararg{Float64}})
    shape = length(args)
    head = Chain(Dense(shape, 128), Dense(128, ic.latent_dim))
    ic.encoder_heads[addr] = head
end

# The assumption here is that the trace has been generated by another context already. So we don't need to error check support, or keep a visited list around.
mutable struct InferenceCompilationMeta{T} <: Meta
    tr::Trace
    stack::Vector{Address}
    opt::T
    compiler::InferenceCompiler
    loss::Float64
    InferenceCompilationMeta(tr::Trace; latent_dim = 5) = new{ADAM}(tr, Address[], ADAM(), InferenceCompiler(latent_dim), 0.0)
end

# Utility bundle.
function logpdf_loss(dist, head, rnn, sample)
    proposal_args = exp.(head(rnn.state))
    return -logpdf(dist(proposal_args...), sample)
end

@inline function Cassette.overdub(ctx::TraceCtx{M}, 
                                  call::typeof(rand), 
                                  addr::T, 
                                  dist::Type,
                                  args) where {M <: InferenceCompilationMeta, 
                                               T <: Address}
    # Check stack.
    !isempty(ctx.metadata.stack) && begin
        push!(ctx.metadata.stack, addr)
        addr = foldr((x, y) -> x => y, ctx.metadata.stack)
        pop!(ctx.metadata.stack)
    end

    # Check if head is defined - otherwise, generate a new one.
    !haskey(ctx.metadata.compiler.decoder_heads, addr) && begin
        generate_decoder_head(ctx.metadata.compiler, addr, args)
    end

    # Get args from inference compiler.
    decoder_head = ctx.metadata.compiler.decoder_heads[addr]
    spine = ctx.metadata.compiler.spine
    params = Flux.params(decoder_head, spine)

    # Get choice from trace choice map.
    choice = ctx.metadata.tr.chm[addr]
    sample = choice.val
    score = choice.score

    # Train.
    ctx.metadata.loss += -logpdf_loss(dist, decoder_head, spine, sample) - score
    Flux.train!(s -> logpdf_loss(dist, decoder_head, spine, s) - score, params, [sample], ctx.metadata.opt)

    # Check if encoder head is available.
    !haskey(ctx.metadata.compiler.encoder_heads, addr) && begin
        generate_encoder_head(ctx.metadata.compiler, addr, [sample...])
    end

    # Transition.
    encoder_head = ctx.metadata.compiler.encoder_heads[addr]
    ctx.metadata.compiler.spine(encoder_head([sample...]))
    return sample
end

function inference_compilation(model::Function, 
                               args::Tuple,
                               observations::Dict{Address, T};
                               batch_size::Int = 256,
                               epochs::Int = 1000) where T
    trs = Vector{Trace}(undef, batch_size)
    model_ctx = disablehooks(TraceCtx(metadata = GenerateMeta(Trace(), observations)))
    inf_comp_ctx = disablehooks(TraceCtx(metadata = InferenceCompilationMeta(Trace())))
    for i in 1:epochs
        for j in 1:batch_size
            # Generate.
            if isempty(args)
                ret = Cassette.overdub(model_ctx, model)
            else
                ret = Cassette.overdub(model_ctx, model, args...)
            end

            # Track.
            trs[j] = model_ctx.metadata.tr
            reset_keep_constraints!(model_ctx)
        end
        
        # Ascent!
        map(trs) do tr
            inf_comp_ctx.metadata.tr = tr
            if isempty(args)
                ret = Cassette.overdub(inf_comp_ctx, model)
            else
                ret = Cassette.overdub(inf_comp_ctx, model, args...)
            end
            inf_comp_ctx.metadata.stack = Vector{Address}[]
        end
        println("Batch loss: $(inf_comp_ctx.metadata.loss/batch_size)")
        inf_comp_ctx.metadata.loss = 0.0
    end
    return inf_comp_ctx
end
