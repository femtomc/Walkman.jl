function LinearGaussian(μ::Float64, σ::Float64)
    α = 5.0
    x = rand(:x, Normal(μ, σ))
    y = rand(:y, Normal(α * x, 1.0))
    return y
end

function LinearGaussianProposal()
    α = 10.0
    x = rand(:x, Normal(α * 3.0, 3.0))
end

@testset "Importance sampling" begin
    sel = Jaynes.selection(:x)
    cl = trace(LinearGaussian, 0.0, 1.0)

    @testset "Linear Gaussian model" begin
        tr, discard = Jaynes.metropolis_hastings(cl, sel)
    end

    @testset "Linear Gaussian proposal" begin
    end
end

