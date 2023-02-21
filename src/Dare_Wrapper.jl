
"""
    setup_agents(env, hook; num_episodes = 1, return_Agents = false)

# Description
Runs the simulation with the specified parameters.

# Arguments
- `env::SimEnv`: mutable struct containing the environment.

# Keyword Arguments
- `return_Agents::Float`: returns the mutable struct containing the agents.

# Return Values
- `Multi_Agent::MultiAgentGridController`: the struct containing the initialised agents

"""
function setup_agents(env)


    #_______________________________________________________________________________
    # Setting up the Agents

    Agents = Dict()

    #-------------------------------------------------------------------------------
    # Setting up the controls for the Classical Sources

    Animo = NamedPolicy("classic", Classical_Policy(env))

    if !isnothing(Animo.policy)
        num_clas_sources = Animo.policy.Source.num_sources # number of classically controlled sources
    else
        num_clas_sources = 0
    end

    #-------------------------------------------------------------------------------
    # Setting up the controls for the Reinforcement Learning Sources

    num_RL_sources = env.nc.num_sources - num_clas_sources # number of reinforcement learning controlled sources

    #= for s in axes(Source_Indices, 1)

        s_idx = string(Source_Indices[s])

        Source.V_cable_loc[:, s]  = findall(contains(s_idx*"_v_C_cable"), state_ids_classic)
        Source.I_inv_loc[:, s] = findall(contains(s_idx*"_i_L1"), state_ids_classic)

        if Source.filter_type[s] == "LC"

            Source.V_cap_loc[:, s]  = findall(contains(s_idx*"_v_C_filt"), state_ids_classic)
            Source.I_poc_loc[:, s] = findall(contains(s_idx*"_v_C_filt"), state_ids)

        elseif Source.filter_type[s] == "LCL"

            Source.V_cap_loc[:, s]  = findall(contains(s_idx*"_v_C_filt"), state_ids_classic)
            Source.I_poc_loc[:, s] = findall(contains(s_idx*"_i_L2"), state_ids_classic)
        
        elseif Source.filter_type[s] == "L"

            Source.I_poc_loc[:, s] = findall(contains(s_idx*"_v_C_cable"), state_ids)   # TODO check _v_C_??
        end
    end

    letterdict = Dict("a" => 1, "b" => 2, "c" => 3)

    Source.Action_loc = [[findfirst(y -> y == parse(Int64, SubString(split(x, "_")[1], 7)), 
    Source_Indices), letterdict[split(x, "_")[3]]] for x in action_ids_classic] =#

    RL_Source_Indices = Array{Int64, 1}(undef, 0)
    for ns in 1:env.nc.num_sources

        if env.nc.parameters["source"][ns]["control_type"] == "RL"
            RL_Source_Indices = [RL_Source_Indices; Int(ns)]
        end
    end

    ssa = "source".*string.(RL_Source_Indices)
    env.state_ids_RL = filter(x -> !isempty(findall(y -> y == split(x, "_")[1], ssa)), env.state_ids)     
    env.action_ids_RL = filter(x -> !isempty(findall(y -> y == split(x, "_")[1], ssa)), env.action_ids)

    if num_RL_sources > 0

        if num_clas_sources > 0
            na = length(env.action_ids) - length(Animo.policy.action_ids)
        else
            na = length(env.action_ids)
        end

        agent = create_agent_ddpg(na = na, ns = length(state(env,"agent")), use_gpu = false)

        for i in 1:3
            agent.policy.behavior_actor.model.layers[i].weight ./= 100
            agent.policy.behavior_actor.model.layers[i].bias ./= 100
            agent.policy.target_actor.model.layers[i].weight ./= 100
            agent.policy.target_actor.model.layers[i].bias ./= 100
        end

        agent = Agent(policy = NamedPolicy("agent", agent.policy), trajectory = agent.trajectory)

        RL_policy = Dict()
        RL_policy["policy"] = agent
        RL_policy["state_ids"] = env.state_ids_RL
        RL_policy["action_ids"] = env.action_ids_RL

        Agents[nameof(agent)] = RL_policy
    end
    
    #-------------------------------------------------------------------------------
    # Finalising the Control

    num_policies = num_RL_sources + convert(Int64, num_clas_sources > 0)

    if num_clas_sources > 0

        polc = Dict()

        polc["policy"] = Animo
        polc["state_ids"] = Animo.policy.state_ids
        polc["action_ids"] = Animo.policy.action_ids

        Agents[nameof(Animo)] = polc
    end
    
    Multi_Agent = MultiAgentGridController(Agents, env.action_ids)

    #_______________________________________________________________________________
    # Logging

    if env.verbosity > 1

        @info "Time simulation run time: $((env.maxsteps - 1)*env.ts) [s] ~ $(Int(env.maxsteps)) steps"
    end

    #_______________________________________________________________________________
    # returns

    return Multi_Agent
    
end

function run(Multi_Agent, env, num_episodes; hook = nothing)

    if isnothing(hook) # default hook

        Source_Indices = Multi_Agent.agents["classic"]["policy"].policy.Source_Indices

        hook = DataHook(collect_sources  = Source_Indices,
                        vrms             = Source_Indices, 
                        irms             = Source_Indices, 
                        power_pq         = Source_Indices,
                        freq             = Source_Indices,
                        angles           = Source_Indices,
                        i_sat            = Source_Indices,
                        v_sat            = Source_Indices,
                        i_err_t          = Source_Indices,
                        v_err_t          = Source_Indices)
    end

    RLBase.run(Multi_Agent, env, StopAfterEpisode(num_episodes), hook)

    return nothing
end 
