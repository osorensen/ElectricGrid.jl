using ElectricGrid
using BenchmarkTools
using Distributions
using JLD2
using StatsPlots
using Random

Random.seed!(123);



function GetEnv(num_nodes, source_type = "RL")
    """
    Generates an env of source and load nodes for a grid with a given source type
    """   

    env = ElectricGridEnv(  
                num_sources = num_nodes, 
                num_loads = num_nodes, 
                # t_end = 1.0,  #dt = 0.0001
                # verbosity = 0,
                ) 

    for i in 1:num_nodes
        if source_type == "classical"
            env.nc.parameters["source"][i]["mode"] = "Swing"
        end
        env.nc.parameters["source"][i]["source_type"] = source_type
        env.nc.parameters["source"][i]["mode"] = ""
    end

    new_env = ElectricGridEnv(
        CM=env.nc.CM,
        action_delay=0,
        t_end = 1.0, 
        parameters = env.nc.parameters,
        )

    return new_env
end

function GetAgent(RLenv)
    """
    Generates an agent for a given env
    """
    agent = CreateAgentDdpg(na = length(RLenv.action_ids),
                ns = length(RLenv.state_ids),
                use_gpu = false);

    custom_agents = Dict("ddpg" => agent)

    controller = SetupAgents(RLenv, custom_agents);

    return controller
end

function Benchmark(num_nodes, source_type = "RL")
    """
    Runs benchmark for the env for a given number of nodes
    """
    env = GetEnv(num_nodes, source_type)
    controller = GetAgent(env)
    # empty hook || datalogging on / off
    hook = DataHook()
    b = @benchmark Simulate($controller, $env, num_episodes=1, hook=$hook) samples=3 seconds=60

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

# test
# env = GetEnv(27)
# controller = GetAgent(env)
# hook = DataHook()

# b_test = @benchmark Simulate($controller, $env, num_episodes=1, hook=$hook) samples=3

# simulation parameter
max_num_nodes = 15
delta = 1
control_type = "RL"

benchmark_data = []

CollectBenchmarkData(max_num_nodes, delta)

@save "benchmark_$(control_type)_$(delta)_$max_num_nodes.jld2" benchmark_data

# plot benchmark data
times = [(b.times * 1e-9) for b in benchmark_data]
nodes = collect(2:delta:32)

StatsPlots.plot(
            nodes, 
            mean.(times), 
            yerr = [std(b) for b in times], 
            xlabel = "Number of nodes", 
            ylabel = "Averaged over 3 differnt runs (s)", 
            label = "Benchmark for RL", #y axis label
            title = "Benchmark for RL control for 1s (with Δt = 1ms)", 
            legend = :topright)





             