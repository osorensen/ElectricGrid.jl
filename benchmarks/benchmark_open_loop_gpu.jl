using BenchmarkPlots, StatsPlots, LinearAlgebra
using ElectricGrid
using BenchmarkTools
using Distributions
using JLD2
using Random

Random.seed!(123);


# function GeneratePermutationNodes(num_nodes)
#     """
#     Generates a permutation of source and load nodes for the grid
#     """
#     nodes = collect(1:num_nodes)
#     return permutedims(collect(permutations(nodes)))
# end


function GetEnv(num_nodes, source_mode = "Swing")
    nc = NodeConstructor(  
                num_sources = num_nodes, 
                num_loads = num_nodes, 
                ) 

    # change source mode to Swing
    for i in 1:num_nodes
        nc.parameters["source"][i]["mode"] = source_mode
    end
    env = ElectricGridEnv(
        CM=nc.CM,
        action_delay=0,
        t_end = 1.0, 
        parameters = nc.parameters,
        use_gpu = true,
        )
    return env
end

# just try with "my_ddpg" for now
# learning (with)


function Benchmark(num_nodes)
    """
    Runs benchmark for the env for a given number of nodes
    """
    env = GetEnv(num_nodes)
    agent = SetupAgents(env)

    b = @benchmark Simulate($agent, $env) samples=4 seconds=60
    return b
end

function CollectBenchmarkData(max_num_nodes, delta_num_nodes = 1)
    """
    Collects benchmark data for a given number of nodes
    """
    # dummy run
    @info "Dummy run..."
    Benchmark(2)

    for i in 1:delta_num_nodes:max_num_nodes

        @info "Running benchmark for $i nodes..."
        b = Benchmark(i)
        push!(benchmark_data, b)
    end        

end
# N = NodeConstructor(num_sources = 2, num_loads = 2)

max_num_nodes = 15
delta = 1
benchmark_data = []

CollectBenchmarkData(max_num_nodes, delta)


@save "benchmark_lea_$(delta)_$max_num_nodes.jld2" benchmark_data

# wo_ps: without processor shielding

times = [(b.times * 1e-9) for b in benchmark_data]
nodes = collect(1:delta:max_num_nodes)
# plot with confidence interval

StatsPlots.plot(nodes, 
            mean.(times), 
            yerr = [std(b) for b in times], 
            xlabel = "Number of nodes", 
            ylabel = "Averaged over (s)", 
            label = "Benchmark", #y axis label
            title = "Benchmark for Open Loop Simulation for 1s (with Δt = 1ms)", 
            legend = :topright)

# realtime line 

# errorline(nodes, times', 
#     label = "Benchmark", legend = :topright,
#     errorstyle=:plume, linewidth = 2, color = :red, alpha = 0.5,)

savefig("benchmark_$(delta)_$max_num_nodes.png")



env = GetEnv(2)
# agent = SetupAgents(env)
# b = @benchmark Simulate($agent, $env)

i = Benchmark(1)

# b = @benchmarkable lu(rand(10,10), samples = 100)
# t = run(b)

# StatsPlots.plot(t)
