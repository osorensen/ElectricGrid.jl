using BenchmarkPlots, StatsPlots, LinearAlgebra
using ElectricGrid
using BenchmarkTools
using Distributions
using JLD2
using Random
using CUDA
# using ReinforcementLearning
Random.seed!(123);

function GetEnv(num_nodes)

    env = ElectricGridEnv(
        num_sources = num_nodes,
        num_loads = num_nodes,
        t_end = 1.0, 
        verbosity = 0, 
        # use_gpu=true
        )
end

function Run(env, training = false)


        is_stop = false
        while !is_stop
            reset!(env)

            while !is_terminated(env) 
                action = 0.002 * rand.(env.action_space)
                
                action = CuArray(action)
                env(action)

                if env.done
                    is_stop = true
                    break
                end
            end 

        end
    # end
end

benchmark_data = []
max_num_nodes = 25

function Benchmark(num_nodes)
    """
    Runs benchmark for the env for a given number of nodes
    """
    for i in 1:num_nodes
        @info "Running benchmark for $i nodes..."
        env = GetEnv(i)
        b = @benchmark Run($env) samples=3 seconds = 60
        push!(benchmark_data, b)
        
    end 
    return benchmark_data
end

Benchmark(max_num_nodes)

@save "benchmark_open_loop_cpu.jld2" benchmark_data

times = [mean(b.times*1e-9) for b in benchmark_data]
nodes = collect(2:max_num_nodes)
# Plotting
using StatsPlots
StatsPlots.plot(
    # nodes, 
    times,
    xlabel = "Number of nodes",

)




