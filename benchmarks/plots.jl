# using PlotlyJS
using JLD2
using BenchmarkTools
using Distributions
using StatsPlots

# directory for data and plots
data_dir = pwd() * "/benchmarks/data/"
plotsdir = pwd() * "/benchmarks/plots/"

# benchmark data
classical_swing_data = load(data_dir * "benchmark_lea_1_15.jld2")["benchmark_data"]
ddpg_data = load(data_dir * "benchmark_lea_RL_1_15.jld2")["benchmark_data"]
classical_VSG_data = load(data_dir * "benchmark_csvm_Synchronverter_1_15.jld2")["benchmark_data"]



# plot classical data and ddpg data
nodes = collect(1:1:15)

times_vsg = [(b.times * 1e-9) for b in classical_VSG_data]
times_ddpg = [(b.times * 1e-9) for b in ddpg_data]
time_swing = [(b.times * 1e-9) for b in classical_swing_data]

# constant time for real time at 1s
real_time = [1 for _ in classical_data]


StatsPlots.plot(
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



StatsPlots.plot!(
    nodes,
    mean.(times_ddpg),
    ribbon = [std(b) for b in time_swing],
    label="ddpg",
    color=:green,
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