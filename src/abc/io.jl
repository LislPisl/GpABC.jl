#
# Input types
#
abstract type ABCInput end

abstract type ABCRejectionInput <: ABCInput end

RepetitiveTraining(; rt_iterations::Int64=0, rt_extra_training_points::Int64=1, rt_sample_size::Int64=1000) =
    RepetitiveTraining(rt_iterations, rt_extra_training_points, rt_sample_size)

struct DistanceSimulationInput
    reference_summary_statistic::AbstractArray{Float64,1}
    simulator_function::Function
    summary_statistic::Function
    distance_metric::Function
end

"""
	AbstractEmulatorRetraining

Subtypes of this abstract type control the additional retraining procedure that may or may not be carried out before each iteration of emulation-based ABC. Custom strategies may be implemented by creating new subtypes of this type and new [`abc_retrain_emulator`](@ref) methods for them.

The following implementations are shipped:
- [`IncrementalRetraining`](@ref)
- [`PreviousPopulationRetraining`](@ref)
- [`PreviousPopulationThresholdRetraining`](@ref)
- [`NoopRetraining`](@ref)
"""
abstract type AbstractEmulatorRetraining end

"""
	IncrementalRetraining <: AbstractEmulatorRetraining

This emulator retraining strategy samples extra particles from the previous population, and adds them to the set of design points that were used on the previous iteration. The new design points are filtered according to the threshold. The combined set of design points is used to train the new emulator.

# Fields
- `design_points`: number of design points to add on each iteration
- `max_simulations`: maximum number of simulations to perform during re-trainging on each iteration
"""
struct IncrementalRetraining <: AbstractEmulatorRetraining
    design_points::Int
    max_simulations::Int
end

"""
	PreviousPopulationRetraining <: AbstractEmulatorRetraining

This emulator retraining strategy samples extra particles from the previous population, and uses them to re-train the emulator from scratch. No filtering of the new design points is performed. Design points from the previous iteration are discarded.
"""
struct PreviousPopulationRetraining <: AbstractEmulatorRetraining end

"""
	PreviousPopulationThresholdRetraining <: AbstractEmulatorRetraining

This emulator retraining strategy samples extra particles from the previous population, and uses them to re-train the emulator from scratch. Design points from the previous iteration are discarded. This strategy allows to control how many design points are sampled with distance to the reference data below the threshold.

# Fields:
- `n_design_points`: number of design points
- `n_below_threshold`: number of design points below the threshold
- `max_iter`: maximum number of simulations to perform on each re-training iteration
"""
struct PreviousPopulationThresholdRetraining <: AbstractEmulatorRetraining
    n_design_points::Int
    n_below_threshold::Int
    max_iter::Int
end

"""
	NoopRetraining <: AbstractEmulatorRetraining

A sentinel retraining strategy that does not do anything. When used, the emulator is trained only once before
"""
struct NoopRetraining <: AbstractEmulatorRetraining end

"""
    AbstractEmulatorTraining

Subtypes of this abstract type control how the emulator is trained for emulation-based ABC algorithms (rejection and SMC).
At the moment, only [`DefaultEmulatorTraining`](@ref) is shipped. Custom emulator training procedure
can be implemented by creating new subtypes of this type and overriding [`train_emulator`](@ref) for them.

A typical use case would be trying to control the behaviour of [`gp_train`](@ref) more tightly,
or not using it altogeather (e.g. using another optimisation package).
"""
abstract type AbstractEmulatorTraining end

"""
	DefaultEmulatorTraining <: AbstractEmulatorTraining

# Fields
- `kernel::AbstractGPKernel`: the kernel ([`AbstractGPKernel`](@ref)) that will be used with the Gaussian Process ([`GPModel`](@ref)). Defaults to [`SquaredExponentialArdKernel`](@ref).

[`train_emulator`](@ref) method with this argument type calls [`gp_train`](@ref) with default arguments.
"""
struct DefaultEmulatorTraining{K<:AbstractGPKernel} <: AbstractEmulatorTraining
    kernel::K
end
DefaultEmulatorTraining() = DefaultEmulatorTraining(SquaredExponentialArdKernel())

struct EmulatorTrainingInput{ET<:AbstractEmulatorTraining}
    distance_simulation_input::DistanceSimulationInput
    design_points::Int64
    emulator_training::ET
end
EmulatorTrainingInput(dsi::DistanceSimulationInput) = EmulatorTrainingInput(dsi, DefaultEmulatorTraining())
EmulatorTrainingInput(n_design_points, reference_summary_statistic, simulator_function, summary_statistic, distance_metric, et=DefaultEmulatorTraining()) =
    EmulatorTrainingInput(DistanceSimulationInput(
        reference_summary_statistic, simulator_function,
        build_summary_statistic(summary_statistic), distance_metric),
        n_design_points, et)

"""
	AbstractEmulatedParticleSelection

Subtypes of this type control the criteria that determine what particles are included in the posterior for emulation-based ABC. Custom strategies
can be implemented by creating new subtypes of this type and overriding [`abc_select_emulated_particles`](@ref) for them.

Two implementations are shipped:
- [`MeanEmulatedParticleSelection`](@ref)
- [`MeanVarEmulatedParticleSelection`](@ref)
"""
abstract type AbstractEmulatedParticleSelection end

"""
   MeanEmulatedParticleSelection <: AbstractEmulatedParticleSelection

When this strategy is used, the particles for which only the *mean* value returned by
[`gp_regression`](@ref) is below the ABC threshold are included in the posterior.
Variance is not checked.
"""
struct MeanEmulatedParticleSelection <: AbstractEmulatedParticleSelection end

"""
   MeanVarEmulatedParticleSelection <: AbstractEmulatedParticleSelection

When this strategy is used, the particles for which both *mean and standard deviation* returned by
[`gp_regression`](@ref) is below the ABC threshold are included in the posterior.

# Fields
- `variance_threshold_factor`: scaling factor, by which the ABC threshold is multiplied
before checking the standard deviation. Defaults to 1.0.
"""
struct MeanVarEmulatedParticleSelection <: AbstractEmulatedParticleSelection
    variance_threshold_factor::Float64
end
MeanVarEmulatedParticleSelection() = MeanVarEmulatedParticleSelection(1.0)

struct SimulatedABCRejectionInput <: ABCRejectionInput
    n_params::Int64
    n_particles::Int64
    threshold::Float64
    priors::AbstractArray{ContinuousUnivariateDistribution,1}
    distance_simulation_input::DistanceSimulationInput
    max_iter::Int
end

struct EmulatedABCRejectionInput{CUD<:ContinuousUnivariateDistribution, EPS<:AbstractEmulatedParticleSelection} <: ABCRejectionInput
	n_params::Int64
	n_particles::Int64
	threshold::Float64
	priors::AbstractArray{CUD,1}
	batch_size::Int64
    max_iter::Int64
    emulator_training_input::EmulatorTrainingInput
    selection::EPS
end

abstract type ABCSMCInput <: ABCInput end

struct SimulatedABCSMCInput <: ABCSMCInput
    n_params::Int64
    n_particles::Int64
    threshold_schedule::AbstractArray{Float64,1}
    priors::AbstractArray{ContinuousUnivariateDistribution,1}
    distance_simulation_input::DistanceSimulationInput
    max_iter::Int
end

SimulatedABCRejectionInput(smc_input::SimulatedABCSMCInput) =
    SimulatedABCRejectionInput(smc_input.n_params,
        smc_input.n_particles,
        smc_input.threshold_schedule[1],
        smc_input.priors,
        smc_input.distance_simulation_input,
        smc_input.max_iter)

struct EmulatedABCSMCInput{CUD<:ContinuousUnivariateDistribution,
        ER<:AbstractEmulatorRetraining, EPS<:AbstractEmulatedParticleSelection} <: ABCSMCInput
    n_params::Int64
    n_particles::Int64
    threshold_schedule::AbstractArray{Float64,1}
    priors::AbstractArray{CUD,1}
    batch_size::Int64
    max_iter::Int64
    emulator_training_input::EmulatorTrainingInput
    emulator_retraining::ER
    selection::EPS
end

#
# Tracker types
#
abstract type ABCSMCTracker end

mutable struct SimulatedABCSMCTracker <: ABCSMCTracker
    n_params::Int64
    n_accepted::AbstractArray{Int64,1}
    n_tries::AbstractArray{Int64,1}
    threshold_schedule::AbstractArray{Float64,1}
	can_continue::Bool # we used to return this flag from iterateABCSMC!, but it got broken in julia 1.0 - see https://github.com/JuliaLang/julia/issues/29805
    population::AbstractArray{AbstractArray{Float64,2},1}
    distances::AbstractArray{AbstractArray{Float64,1},1}
    weights::AbstractArray{StatsBase.Weights,1}
    priors::AbstractArray{ContinuousUnivariateDistribution,1}
    distance_simulation_input::DistanceSimulationInput
    max_iter::Int
end

mutable struct EmulatedABCSMCTracker{CUD<:ContinuousUnivariateDistribution, ET,
        ER<:AbstractEmulatorRetraining, EPS<:AbstractEmulatedParticleSelection} <: ABCSMCTracker
    n_params::Int64
    n_accepted::AbstractArray{Int64,1}
    n_tries::AbstractArray{Int64,1}
    threshold_schedule::AbstractArray{Float64,1}
	can_continue::Bool # we used to return this flag from iterateABCSMC!, but it got broken in julia 1.0 - see https://github.com/JuliaLang/julia/issues/29805
    population::AbstractArray{AbstractArray{Float64,2},1}
    distances::AbstractArray{AbstractArray{Float64,1},1}
    weights::AbstractArray{StatsBase.Weights,1}
    priors::AbstractArray{CUD,1}
    emulator_training_input::EmulatorTrainingInput
    emulator_retraining::ER
    selection::EPS
    batch_size::Int64
    max_iter::Int64
    emulators::AbstractArray{ET,1}
end

#
# Output types
#
abstract type ABCOutput end

"""
    ABCRejectionOutput

A container for the output of a rejection-ABC computation.

# Fields
- `n_params::Int64`: The number of parameters to be estimated.
- `n_accepted::Int64`: The number of accepted parameter vectors (particles) in the posterior.
- `n_tries::Int64`: The total number of parameter vectors (particles) that were tried.
- `threshold::Float64`: The maximum distance from the summarised model output to summarised observed data for a parameter vector to be included in the posterior.
- `population::AbstractArray{Float64,2}`: The parameter vectors (particles) in the posterior. Size: (`n_accepted`, `n_params`).
- `distances::AbstractArray{Float64,1}`: The distances for each parameter vector (particle) in the posterior to the observed data in summary statistic space. Size: (`n_accepted`).
- `weights::StatsBase.Weights`: The weight of each parameter vector (particle) in the posterior.
"""
abstract type ABCRejectionOutput <: ABCOutput end

struct EmulatedABCRejectionOutput{ET} <: ABCRejectionOutput
    n_params::Int64
    n_accepted::Int64
    n_tries::Int64
    threshold::Float64
    population::AbstractArray{Float64,2}
    distances::AbstractArray{Float64,1}
    weights::StatsBase.Weights
    emulator::ET
end

struct SimulatedABCRejectionOutput <: ABCRejectionOutput
    n_params::Int64
    n_accepted::Int64
    n_tries::Int64
    threshold::Float64
    population::AbstractArray{Float64,2}
    distances::AbstractArray{Float64,1}
    weights::StatsBase.Weights
end

"""
    ABCSMCOutput

A container for the output of a rejection-ABC computation.

# Fields
- `n_params::Int64`: The number of parameters to be estimated.
- `n_accepted::Int64`: The number of accepted parameter vectors (particles) in the posterior.
- `n_tries::Int64`: The total number of parameter vectors (particles) that were tried.
- `threshold_schedule::AbstractArray{Float64}`: A set of maximum distances from the summarised model output to summarised observed data for a parameter vector to be included in the posterior. Each distance will be used in a single run of the ABC-SMC algorithm.
- `population::AbstractArray{Float64,2}`: The parameter vectors (particles) in the posterior. Size: (`n_accepted`, `n_params`).
- `distances::AbstractArray{Float64,1}`: The distances for each parameter vector (particle) in the posterior to the observed data in summary statistic space. Size: (`n_accepted`).
- `weights::StatsBase.Weights`: The weight of each parameter vector (particle) in the posterior.
"""
abstract type ABCSMCOutput <: ABCOutput end

struct SimulatedABCSMCOutput <: ABCSMCOutput
    n_params::Int64
    n_accepted::AbstractArray{Int64,1}
    n_tries::AbstractArray{Int64,1}
    threshold_schedule::AbstractArray{Float64,1}
    population::AbstractArray{AbstractArray{Float64,2},1}
    distances::AbstractArray{AbstractArray{Float64,1},1}
    weights::AbstractArray{StatsBase.Weights,1}
end

struct EmulatedABCSMCOutput <: ABCSMCOutput
    n_params::Int64
    n_accepted::AbstractArray{Int64,1}
    n_tries::AbstractArray{Int64,1}
    threshold_schedule::AbstractArray{Float64,1}
    population::AbstractArray{AbstractArray{Float64,2},1}
    distances::AbstractArray{AbstractArray{Float64,1},1}
    weights::AbstractArray{StatsBase.Weights,1}
    emulators::AbstractArray{GPModel,1}
end


#
# Read/write functions
#
function write_scalar(
        stream::IO,
        x::Real;
        separator="\n",
        )
    write(stream, string(x), separator)
end


function write_vector(
        stream::IO,
        vector::Vector{R};
        separator=" ",
        finalcharacter="\n"
        ) where {
        R<:Real,
        }
    n = length(vector)
    for i in 1:(n - 1)
        write_scalar(stream, vector[i]; separator=separator)
    end
    write_scalar(stream, vector[n]; separator=finalcharacter)
end


function write_matrix(
        stream::IO,
        matrix::Matrix{R};
        separator=" ",
        newline=true,
        ) where {
        R<:Real,
        }
    n = size(matrix, 2)
    for i in 1:(n - 1)
        write_vector(stream, matrix[:, i]; separator=separator, finalcharacter="\n")
    end
    finalcharacter = newline ? "\n" : ""
    write_vector(stream, matrix[:, n]; separator=separator, finalcharacter=finalcharacter)
end


function Base.write(stream::IO, output::ABCRejectionOutput)
    write_scalar(stream, output.n_params)
    write_scalar(stream, output.n_accepted)
    write_scalar(stream, output.n_tries)
    write_scalar(stream, output.threshold)
    write_matrix(stream, output.population)
    write_vector(stream, output.distances)
    write_vector(stream, output.weights.values)

    flush(stream)
end


function Base.write(stream::IO, output::Union{ABCSMCOutput, ABCSMCTracker})
    write_scalar(stream, output.n_params)
    write_vector(stream, output.n_accepted)
    write_vector(stream, output.n_tries)
    write_vector(stream, output.threshold_schedule)
    for i in 1:length(output.threshold_schedule)
        write(stream, "-----\n")
        write_scalar(stream, output.n_accepted[i])
        write_scalar(stream, output.n_tries[i])
        write_scalar(stream, output.threshold_schedule[i])
        write_matrix(stream, output.population[i])
        write_vector(stream, output.distances[i])
        write_vector(stream, output.weights[i].values)
    end

    flush(stream)
end


function write(stream::IO, output::Union{ABCOutput, ABCSMCTracker})
    return Base.write(stream, output)
end


function read_rejection_output(filepath::AbstractString)
    input_file = open(filepath, "r")

    try
        n_params = parse(Int64, readline(input_file))
        n_accepted = parse(Int64, readline(input_file))
        n_tries = parse(Int64, readline(input_file))
        threshold = parse(Float64, readline(input_file))

        population = zeros(n_params, n_accepted)
        for i in 1:n_accepted
            population[:, i] = parse.(Float64, split(readline(input_file)))
        end

        distances = parse.(Float64, split(readline(input_file)))

        wts = parse.(Float64, split(readline(input_file)))
        weights = StatsBase.Weights(wts)

        return ABCRejectionOutput(n_params,
                                  n_accepted,
                                  n_tries,
                                  threshold,
                                  population,
                                  distances,
                                  weights,
                                  )
    finally
        close(input_file)
    end
end


function read_smc_output(filepath::AbstractString)
    input_file = open(filepath, "r")

    try
        n_params = parse(Int64, readline(input_file))
        n_accepted = parse.(Int64, split(readline(input_file)))
        n_tries = parse.(Int64, split(readline(input_file)))
        threshold_schedule = parse.(Float64, split(readline(input_file)))

        @assert length(n_accepted) == length(n_tries) == length(threshold_schedule)

        population = Matrix{Float64}[]
        distances = Vector{Float64}[]
        weights = StatsBase.Weights[]

        for i in 1:length(threshold_schedule)
            separator = readline(input_file)

            @assert parse(Int64, readline(input_file)) == n_accepted[i]
            @assert parse(Int64, readline(input_file)) == n_tries[i]
            @assert parse(Float64, readline(input_file)) == threshold_schedule[i]

            push!(population, zeros(n_params, n_accepted[i]))
            for j in 1:n_accepted[i]
                particle = parse.(Float64, split(readline(input_file)))
                population[i][:, j] = particle
            end

            push!(distances, parse.(Float64, split(readline(input_file))))

            wts = parse.(Float64, split(readline(input_file)))
            push!(weights, StatsBase.Weights(wts))
        end

        return ABCSMCOutput(n_params,
                            n_accepted,
                            n_tries,
                            threshold_schedule,
                            population,
                            distances,
                            weights,
                            )
    finally
        close(input_file)
    end
end

function checkABCInput(input::ABCInput)
	if input.n_params != length(input.priors)
		throw(ArgumentError("There are $(input.n_params) unknown parameters but $(length(input.priors)) priors were provided"))
	end
end
