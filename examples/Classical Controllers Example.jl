# activate .
# instantiate
# add OrdinaryDiffEq@5.71.2 SciMLBase@1.47.0 DiffEqBase@6.84.0 ReinforcementLearning@0.10.1

#= To do list
    reset Classical control as well (integrators)
    single phase PLL tuning
    Self-synchronverter
    Single phase controllers
=#

using DrWatson
@quickactivate ("dare")

using ControlSystems
#using Plots
using ReinforcementLearning
using LinearAlgebra
using FFTW
using IntervalSets
using CUDA

include(srcdir("Classical_Control.jl"))
include(srcdir("Power_System_Theory.jl"))

include(srcdir("data_hook.jl"))
include(srcdir("nodeconstructor.jl"))
include(srcdir("env.jl"))

include(srcdir("Classical_Control_Plots.jl"))

print("\n...........o0o----ooo0o0ooo~~~  START  ~~~ooo0o0ooo----o0o...........\n")

#_______________________________________________________________________________
# Parameters - Time simulation
Timestep = 100 #time step in μs ~ 100μs => 10kHz, 50μs => 20kHz, 20μs => 50kHz
t_final = 1 #time in seconds, total simulation run time

ts = Timestep*1e-6
t = 0:ts:t_final # time

fs = 1/ts # Hz, Sampling frequency of controller ~ 15 kHz < fs < 50kHz

#_______________________________________________________________________________
# State space representation

#-------------------------------------------------------------------------------
# Connectivity Matrix

#= CM = [ 0. 0. 0. 1.
        0. 0. 0. 2.
        0. 0. 0. 3.
        -1. -2. -3. 0.] =#

CM = [ 0. 0. 1.
        0. 0. 2
        -1. -2. 0.]

#= CM = [0. 1.
   -1. 0.] =#

#-------------------------------------------------------------------------------
# Sources

source_list = []
source = Dict()

source["pwr"] = 200e3
source["vdc"] = 800
source["fltr"] = "LCL"
Lf, Cf, _ = Filter_Design(source["pwr"], fs)
source["R1"] = 0.4
source["R_C"] = 0.0006
source["L1"] = Lf/2
source["C"] = Cf
source["L2"] = Lf/2
source["R2"] = 0.4

push!(source_list, source)

source = Dict()

source["pwr"] = 100e3
source["vdc"] = 800
source["fltr"] = "LCL"
Lf, Cf, _ = Filter_Design(source["pwr"], fs)
source["R1"] = 0.4
source["R_C"] = 0.0006
source["L1"] = Lf/2
source["C"] = Cf
source["L2"] = Lf/2
source["R2"] = 0.4

push!(source_list, source)

#= source = Dict()

source["pwr"] = 150e3
source["vdc"] = 800
source["fltr"] = "LC"
Lf, Cf, _ = Filter_Design(source["pwr"], fs)
source["R1"] = 0.4
source["R_C"] = 0.0006
source["L1"] = Lf
source["C"] = Cf

push!(source_list, source) =#

#-------------------------------------------------------------------------------
# Loads

load_list = []
load = Dict()

R1_load, L_load, _, _ = Load_Impedance_2(50e3, 0.999, 230)
#R2_load, C_load, _, _ = Load_Impedance_2(150e3, -0.8, 230)

load["impedance"] = "RL"
load["R"] = R1_load# + R2_load # 
load["L"] = L_load
#load["C"] = C_load

push!(load_list, load)

#-------------------------------------------------------------------------------
# Cables

cable_list = []

# Network Cable Impedances
l = 0.01 # length in km
cable = Dict()
cable["R"] = 0.208*l # Ω, line resistance
cable["L"] = 0.00025*l # H, line inductance
cable["C"] = 0.4e-6*l # F, line capacitance

#push!(cable_list, cable, cable, cable)

push!(cable_list, cable, cable)

#push!(cable_list, cable)

#-------------------------------------------------------------------------------
# Amalgamation

parameters = Dict()

parameters["source"] = source_list
parameters["cable"] = cable_list
parameters["load"] = load_list
parameters["grid"] = Dict("fs" => fs, "phase" => 3, "v_rms" => 230)

# Define the environment

num_sources = length(source_list)
num_loads = length(load_list)

env = SimEnv(reward_function = reward,  v_dc = 800, ts = ts, use_gpu = false, 
CM = CM, num_sources = num_sources, num_loads = num_loads, 
parameters = parameters, maxsteps = length(t))

#_______________________________________________________________________________
# Setting up the Sources

Animo = Classical_Policy(action_space = action_space(env), t_final = t_final, 
fs = env.nc.parameters["grid"]["fs"], num_sources = num_sources)

Modes = [4, 2]

#=
    1 -> "Voltage Control Mode" - voltage source with controller dynamics
    2 -> "PQ Control Mode" - grid following controllable load
    3 -> "Droop Control Mode" - grid forming with power balancing
    4 -> "Synchronverter Mode" - grid forming with power balancing via virtual motor
    5 -> "Swing Mode" - voltage source without dynamics
=#

Source_Initialiser(env, Animo, Modes)

Animo.Source.τv = 0.02 # time constant of the voltage loop
Animo.Source.τf = 0.02 # time constant of the frequency loop

Animo.Source.pq0_set[2, 1] = 100e3 # W, Real Power
Animo.Source.pq0_set[2, 2] = 20e3 # VAi, Imaginary Power

#_______________________________________________________________________________
#%% Starting time simulation

println("\nHere we go.\n")
#reset!(env)

@time begin

    println("Progress : 0.0 %")

    for i in 1:env.maxsteps

        # Progress Bar
        if i > 1 && floor((10*t[i]/t_final)) != floor((10*t[i - 1]/t_final))
            flush(stdout)
            println("Progress : ", 10*floor((10*t[i]/t_final)), " %")
        end

        # Control System _______________________________________________________

        if t[i] > t_final/2
            nm_src = 2 # changing the power set points of the 2nd source
            Animo.policy.Source.pq0_set[nm_src, 1] = 100e3 # W, Real Power
            Animo.policy.Source.pq0_set[nm_src, 2] = 20e3 # VAi, Imaginary Power
        end

        action = Animo(env)

        # System Dynamics ______________________________________________________

        env(action)
    end

    println("Progress : 100.0 %\n")
end

#_______________________________________________________________________________
#%% Plots

#Plot_I_dq0(0, 5000, Animo.Source, num_source = 2)

#Plot_V_dq0(0, 5000, Animo.Source, num_source = 2)

#Inst_Vout_Vref(0, 10, Animo.Source, env, num_source = 1)
#Inst_Vout_Vref(0, 10, Animo.Source, env, num_source = 2)

#Inst_Iout_Iref(0, 10, Animo.Source, env, num_source = 1)
#Inst_Iout_Iref(0, 10, Animo.Source, env, num_source = 2)

#Plot_PLL(0, 500, Animo.Source, env, num_source = 2, ph = 1)

#Plot_Irms(0, 5000, Animo.Source, num_source = 1)
#Plot_Irms(0, 5000, Animo.Source, num_source = 2)

Plot_Vrms(5, 5000, Animo.Source, num_source = 1)
Plot_Vrms(5, 5000, Animo.Source, num_source = 2)

Plot_Real_Imag_Active_Reactive(0, 5000, Animo.Source, num_source = 1)
Plot_Real_Imag_Active_Reactive(0, 5000, Animo.Source, num_source = 2)

print("\n...........o0o----ooo0o0ooo~~~  END  ~~~ooo0o0ooo----o0o...........\n")