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
        use_gpu=true)
end

function Run(env, training = false)
    CUDA.@sync begin

        # hook(PRE_EXPERIMENT_STAGE, policy, env, training)
        # policy(PRE_EXPERIMENT_STAGE, env, training)

        is_stop = false
        while !is_stop
            reset!(env)

            # ResetPolicy(policy)

            # policy(PRE_EPISODE_STAGE, env, training)
            # hook(PRE_EPISODE_STAGE, policy, env, training)

            while !is_terminated(env) # one episode
                action = 0.002 * rand.(env.action_space)
                    
                # policy(PRE_ACT_STAGE, env, action, training)
                # hook(PRE_ACT_STAGE, policy, env, action, training)
                
                action = CuArray(action)
                env(action)

                # policy(POST_ACT_STAGE, env, training)
                # hook(POST_ACT_STAGE, policy, env, training)

                if env.done
                    is_stop = true
                    break
                end
            end # end of an episode

            # if is_terminated(env)
            #     # policy(POST_EPISODE_STAGE, env, training)  # let the policy see the last observation
            #     # hook(POST_EPISODE_STAGE, policy, env, training)
            # end
        end
    end
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

@save "benchmark_open_loop_gpu.jld2" benchmark_data




