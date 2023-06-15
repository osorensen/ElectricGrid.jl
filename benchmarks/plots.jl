# using PlotlyJS
using JLD2
using BenchmarkTools
using Distributions
using StatsPlots

# directory for data and plots
data_dir = pwd() * "/benchmarks/data/"
plotsdir = pwd() * "/benchmarks/plots/"

# benchmark data
# classical_swing_data = load(data_dir * "benchmark_lea_1_15.jld2")["benchmark_data"]
ddpg_data = load(data_dir * "benchmark_lea_RL_1_15.jld2")["benchmark_data"]
# classical_VSG_data = load(data_dir * "benchmark_csvm_Synchronverter_1_15.jld2")["benchmark_data"]

open_loop_cpu = load(data_dir * "benchmark_lea_open_loop_cpu.jld2")["benchmark_data"]
open_loop_gpu = load(data_dir * "benchmark_lea_open_loop_gpu.jld2")["benchmark_data"]

# ddpg_gpu_data = load(data_dir * "benchmark_gpu_RL_1_25.jld2")["benchmark_data"]
ddpg_gpu_data = load(data_dir * "benchmark_lea_gpu_ddpg_env_1_25.jld2")["benchmark_data"]

# plot classical data and ddpg data
nodes = collect(1:1:15)

# times_vsg = [(b.times * 1e-9) for b in classical_VSG_data]

times_open_loop_cpu = [(b.times * 1e-9) for b in open_loop_cpu]
times_open_loop_gpu = [(b.times * 1e-9) for b in open_loop_gpu]

nodes = collect(1:1:25)


StatsPlots.plot!(
    nodes,
    mean.(times_open_loop_cpu),
    ribbon = [std(b) for b in times_open_loop_cpu],
    label="open loop cpu",
    color=:green,
    fillalpha=0.3,
    )

StatsPlots.plot(
    nodes,
    mean.(times_open_loop_gpu[2:26]),
    # ribbon = [std(b) for b in times_open_loop_gpu[1:25]],
    label="open loop gpu",
    color=:red,
    fillalpha=0.3,
    )



times_ddpg_cpu = [(b.times * 1e-9) for b in ddpg_data]
times_ddpg_gpu = [(b.times * 1e-9) for b in ddpg_gpu_data]
nodes_ddpg = collect(1:15)

StatsPlots.plot!(
    nodes_ddpg,
    mean.(times_ddpg_cpu),
    ribbon = [std(b) for b in times_ddpg_cpu],
    label="ddpg cpu",
    color=:blue,
    fillalpha=0.3,
    )

StatsPlots.plot!(
    nodes,
    mean.(times_ddpg_gpu),
    ribbon = [std(b) for b in times_ddpg_gpu],
    label="ddpg gpu",
    color=:orange,
    fillalpha=0.3,
    )

time_swing = [(b.times * 1e-9) for b in classical_swing_data]
times_gpu = [(b.times * 1e-9) for b in ddpg_gpu_data]
# constant time for real time at 1s
real_time = [1 for _ in nodes]
times_ddpg_gpu = [(b.times * 1e-9) for b in ddpg_gpu_data]  

StatsPlots.plot!(
    nodes,
    real_time,
    label="1s baseline",
    linestyle=:dash,
    color=:black,
    title="Benchmark of Simulation for 1s (with Δt = 1ms)", 
    xlabel="Number of nodes [equally distributed sources and loads]", 
    ylabel="Time averaged over 3 benchmarks (s)"
    )

StatsPlots.plot(nodes, 
    mean.(times_classical), 
    ribbon = [std(b) for b in times_classical],
    label="VSG",
    fillalpha=0.3, 
    )


StatsPlots.plot!(
    nodes,
    mean.(time_swing),
    fillalpha=0.3,
    ribbon = [std(b) for b in time_swing],
    # yerr = [std(b) for b in times_ddpg],
    label="RL control",
    color=:red,)
# plot realtime


StatsPlots.plot(
    # nodes,
    mean.(times_ddpg),
    ribbon = [std(b) for b in times_ddpg],
    label="ddpg cpu",
    color=:green,
    fillalpha=0.3,
    )
    
times_gpu_ = times_ddpg_gpu[1:15]

StatsPlots.plot!(
    nodes,
    mean.(times_gpu_),
    ribbon = [std(b) for b in times_gpu_],
    label="ddpg gpu",
    color=:blue,
    fillalpha=0.3,
    )



savefig(plotsdir * "benchmark_csvm_swing_vsg_1_15.png")
# try with plotlyS
# using PlotlyJS

# # plot classical data and ddpg data
# traces = []
# push!(traces, PlotlyJS.scatter(x=nodes, y=mean.(times_classical), mode="lines", name="classical"))
# push!(traces, PlotlyJS.scatter(x=nodes[1:7], y=mean.(times_ddpg), mode="lines", name="ddpg"))
# push!(traces, PlotlyJS.scatter(x=nodes, y=real_time, mode="lines", name="realtime"))

# # plot
# PlotlyBase.Plot(traces,
#     config=PlotConfig(scrollZoom=true))