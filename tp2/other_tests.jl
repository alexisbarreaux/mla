using JuMP
using CPLEX

include("./instances/exemple-lecture-graphe.jl")

"""
include("./tp2/other_tests.jl")
withoutBenders("benders4", bnd=3)
"""

function boundDijkstra(inputFile::String="benders-graphe-hexagone"; bnd::Int64=1, showResult::Bool=false,
    timeLimit::Float64=-1.0)::Any
    start = time()
    readGraph("./tp2/instances/" * inputFile * ".txt")

    y = [[0 for j in 1:n] for j in 1:n]

    # Build graph
    graph = Graph(n)

    for i in 1:n
        for j in (i+1):n
            if adj[i, j] > 0.0
                add_edge!(graph, i, j)
            end
        end
    end
    # Get shortests paths
    source_paths = dijkstra_shortest_paths(graph, 1)
    paths = enumerate_paths(source_paths)

    lbound = ceil(sum([demande[i] * (length(paths[i]) - 1) for i in 2:n]) / bnd)

    for p in 1:n
        for i in 2:length(paths[p])
            y[paths[p][i-1]][paths[p][i]] += demande[p]
        end
    end

    ubound = 0
    for i in 1:n
        for j in i+1:n
            ubound += ceil((y[i][j] + y[j][i]) / bnd)
        end
    end
    return lbound, ubound
end

function lowerBound(inputFile::String="benders-graphe-hexagone"; bnd::Int64=1, showResult::Bool=false,
    timeLimit::Float64=-1.0)::Any
    start = time()
    readGraph("./tp2/instances/" * inputFile * ".txt")

    # Build graph
    graph = Graph(n)

    for i in 1:n
        for j in (i+1):n
            if adj[i, j] > 0.0
                add_edge!(graph, i, j)
            end
        end
    end
    # Get shortests paths
    source_paths = dijkstra_shortest_paths(graph, 1)
    paths = enumerate_paths(source_paths)

    return ceil(sum([demande[i] * (length(paths[i]) - 1) for i in 2:n]) / bnd), time() - start
end

function withoutBenders(inputFile::String="benders-graphe-hexagone"; showResult::Bool=false,
    timeLimit::Float64=-1.0, bnd::Int64=1)::Any
    start = time()
    readGraph("./tp2/instances/" * inputFile * ".txt")
    # Creating the model
    model = Model(CPLEX.Optimizer)
    set_silent(model)

    ##### Variables #####
    @variable(model, y[i in 1:n, j in 1:n] >= 0.0, Int)
    @variable(model, x[i in 1:n, j in 1:n] >= 0.0)

    ##### Objective #####
    @objective(model, Min, sum(y[i, j] for i in 1:n for j in 1:n if adj[i, j] > 0.0 && i < j))

    ##### Constraints #####
    for i in 2:n
        @constraint(model, sum(x[j, i] for j in 1:n if adj[i, j] > 0.0) - sum(x[i, j] for j in 1:n if adj[i, j] > 0.0) >= demande[i])
    end

    for i in 1:n
        for j in i+1:n
            @constraint(model, bnd * y[i, j] - x[i, j] - x[j, i] >= 0)
        end
    end

    optimize!(model)

    feasibleSolutionFound = primal_status(model) == MOI.FEASIBLE_POINT
    if !(feasibleSolutionFound)
        println("No solution found")
        return
    end
    isOptimal = termination_status(model) == MOI.OPTIMAL
    return isOptimal, JuMP.objective_value(model), time() - start
end


function automaticBenders(inputFile::String="benders-graphe-hexagone"; showResult::Bool=false,
    timeLimit::Float64=-1.0, bnd::Int64=1)::Any
    start = time()
    readGraph("./tp2/instances/" * inputFile * ".txt")
    # Creating the model
    model = Model(CPLEX.Optimizer)
    set_silent(model)

    ##### Variables #####
    @variable(model, y[i in 1:n, j in 1:n] >= 0.0, Int)
    @variable(model, x[i in 1:n, j in 1:n] >= 0.0)

    ##### Objective #####
    @objective(model, Min, sum(y[i, j] for i in 1:n for j in 1:n if adj[i, j] > 0.0 && i < j))

    ##### Constraints #####
    for i in 2:n
        @constraint(model, sum(x[j, i] for j in 1:n if adj[i, j] > 0.0) - sum(x[i, j] for j in 1:n if adj[i, j] > 0.0) >= demande[i])
    end

    for i in 1:n
        for j in i+1:n
            @constraint(model, bnd * y[i, j] - x[i, j] - x[j, i] >= 0)
        end
    end

    set_optimizer_attribute(model, "CPXPARAM_Benders_Strategy", 3)

    optimize!(model)

    feasibleSolutionFound = primal_status(model) == MOI.FEASIBLE_POINT
    if !(feasibleSolutionFound)
        println("No solution found")
        return
    end
    isOptimal = termination_status(model) == MOI.OPTIMAL
    return isOptimal, JuMP.objective_value(model), time() - start
end