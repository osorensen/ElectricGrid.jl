module JEG

using Combinatorics
using CSV
using CUDA
using DataStructures
using DataFrames
using ControlSystemsBase
using Distributions
using Flux
using Graphs
using GraphPlot
using IJulia
using IntervalSets
using Ipopt
using JuMP
using LinearAlgebra
using Logging
using PlotlyJS
using Random
using ReinforcementLearning
using StableRNGs
using SpecialFunctions
using StatsBase

#export create_setup, Classical_Policy, CreateAgentDdpg, Source_Initialiser, MultiAgentGridController, data_hook, plot_hook_results, plot_best_results, NodeConstructor, JEG_setup, ElectricGridEnv

include("./power_system_theory.jl")
include("./node_constructor.jl")
include("./custom_control.jl")
include("./solar_module.jl")
include("./electric_grid_env.jl")
include("./agent_ddpg.jl")
include("./Classical_Control.jl")
include("./MultiAgentGridController.jl")
include("./plotting.jl")
include("./data_hook.jl")
include("./logger.jl")

#code to export all, taken from https://discourse.julialang.org/t/exportall/4970/18
for n in names(@__MODULE__; all=true)
    if Base.isidentifier(n) && n ∉ (Symbol(@__MODULE__), :eval, :include)
        @eval export $n
    end
end

end # module