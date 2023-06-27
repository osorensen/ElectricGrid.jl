using ElectricGrid
using Graphs

print("\n...........o0o----ooo0§0ooo~~~  START  ~~~ooo0§0ooo----o0o...........\n\n")

#_______________________________________________________________________________
# Network Configuration 

#-------------------------------------------------------------------------------
# Time simulation

Timestep = 100e-6  # time step, seconds ~ 100μs => 10kHz, 50μs => 20kHz, 20μs => 50kHz
t_end    = 0.2     # total run time, seconds
num_eps = 1

#-------------------------------------------------------------------------------
# Connectivity Matrix

num_nodes = 10
num_sources = 5

CM, num_cables  = SmallWorld(num_nodes, p = 0.0, Z = 2, num_sources = num_sources)
#CM, num_cables = Barabasi_Albert(num_nodes)

#-------------------------------------------------------------------------------
# Parameters

parameters = Dict{Any, Any}()

parameters["source"], total_gen = SourceSetup(num_sources, random = 1, mode = 4)
parameters["load"] = LoadSetup(num_nodes - num_sources, total_gen, random = 1)
parameters["cable"] = CableLengthSetup(num_cables, random = 0)
parameters["grid"] = Dict("v_rms" => 230, "ramp_end" => 0.04, "process_start" => 0.05)

#_______________________________________________________________________________
# Defining the environment

env = ElectricGridEnv(ts = Timestep, CM = CM, parameters = parameters, t_end = t_end, verbosity = 2)

#_______________________________________________________________________________
# Setting up data hooks

hook = DataHook(collect_sources  = 1:num_sources,
                v_mag            = 1:num_sources, 
                i_mag            = 1:num_sources, 
                power_pq         = 1:num_sources,
                freq             = 1:num_sources,
                i_sat            = 1:num_sources,
                v_sat            = 1:num_sources,
                i_err            = 1:num_sources,
                v_err            = 1:num_sources,
                )

#_______________________________________________________________________________
# initialising the agents 

Multi_Agent = SetupAgents(env)

#_______________________________________________________________________________
# running the time simulation 

hook = Simulate(Multi_Agent, env, 1, hook = hook)   

#_______________________________________________________________________________
# Plotting

# Spring Layout (Layout = 3) is better for Barabasi-Albert
# Circular Layout (Layout = 1) is better for SmallWolrd
drawGraph(CM, parameters, Layout = 3)

RenderHookResults(hook = hook, 
                    states_to_plot  = [], 
                    actions_to_plot = [],  
                    power_p         = [], 
                    power_q         = [], 
                    v_mag           = 1:num_sources, 
                    i_mag           = [],
                    freq            = [],
                    i_sat           = 1:num_sources,
                    v_sat           = 1:num_sources,
                    i_err           = 1:num_sources,
                    v_err           = 1:num_sources,)

print("\n...........o0o----ooo0§0ooo~~~   END   ~~~ooo0§0ooo----o0o...........\n")
