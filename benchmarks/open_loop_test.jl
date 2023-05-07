using BenchmarkPlots, StatsPlots, LinearAlgebra
using ElectricGrid
using BenchmarkTools
using Distributions
using JLD2

# function GeneratePermutationNodes(num_nodes)
#     """
#     Generates a permutation of source and load nodes for the grid
#     """
#     nodes = collect(1:num_nodes)
#     return permutedims(collect(permutations(nodes)))
# end


function GetEnv(num_nodes)
    env = ElectricGridEnv(  
                num_sources = num_nodes, 
                num_loads = num_nodes, 
                t_end = 0.5, 
                verbosity = 0,
                )
    return env
end

benchmark_data = []

function Benchmark(num_nodes)
    """
    Runs benchmark for the env for a given number of nodes
    """
    env = GetEnv(num_nodes)
    agent = SetupAgents(env)
    b = @benchmark Simulate($agent, $env)
    return b
end

function CollectBenchmarkData(max_num_nodes, delta_num_nodes = 1)
    """
    Collects benchmark data for a given number of nodes
    """
    # dummy run
    @info "Dummy run..."
    Benchmark(2)

    for i in 2:delta_num_nodes:max_num_nodes

        @info "Running benchmark for $i nodes..."
        b = Benchmark(i)
        push!(benchmark_data, b)
    end        

end
# N = NodeConstructor(num_sources = 2, num_loads = 2)

CollectBenchmarkData(50, 5)

@save "benchmark_data_2_$max_num_nodes_wo_ps.jld2" benchmark_data

# wo_ps: without processor shielding

times = [(b.times * 1e-9) for b in benchmark_data]
nodes = collect(2:33)
# plot with confidence interval

StatsPlots.plot(nodes, mean.(times), yerr = [std(b) for b in times], 
    xlabel = "Number of nodes", ylabel = "Time (s)", label = "Benchmark", 
    title = "Benchmark for Open Loop Simulation", legend = :topright)


# errorline(nodes, times', 
#     label = "Benchmark", legend = :topright,
#     errorstyle=:plume, linewidth = 2, color = :red, alpha = 0.5,)

savefig("benchmark_2_$max_num_nodes_wo_ps.png")



# env = GetEnv(2)
# agent = SetupAgents(env)
# b = @benchmark Simulate($agent, $env)



# b = @benchmarkable lu(rand(10,10), samples = 100)
# t = run(b)

# StatsPlots.plot(t)
