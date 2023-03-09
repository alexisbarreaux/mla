using JuMP
using CPLEX
using Graphs

include("./instances/exemple-lecture-graphe.jl")
"""
include("./tp2/exercice3.jl")
readGraph("./tp2/instances/benders-graphe-hexagone.txt")
linksBendersDijkstra("benders-graphe-hexagone")
"""

function subProblem(y_val::Matrix{Float64}, bnd::Int64)::Any
    # Creating the model
    sub_model = Model(CPLEX.Optimizer)
    set_silent(sub_model)

    ##### Variables #####
    @variable(sub_model, v_ij[i in 1:n, j in 1:n] >= 0.)
    @variable(sub_model, v[i in 1:n] >= 0.)

    ##### Objective #####
    @objective(sub_model, Max, - bnd*sum(y_val[i,j] * v_ij[i,j] for i in 1:n for j in 1:n if adj[i,j] > 0.0 && i < j ) + 
                sum(demande[i] * v[i] for i in 1:n))
    
    ##### Constraints #####
    @constraint(sub_model, v[1] == 0)
    # Feasibility constraint
    @constraint(sub_model, sum(v_ij[i,j] for i in 1:n for j in 1:n if adj[i,j] > 0.0 && i < j) + sum(v[i] for i in 1:n) == 1)
    #@constraint(sub_model, sum(v_ij[i,j] for i in 1:n for j in 1:n if adj[i,j] > 0.0 && i < j) <= 1e-1)
    #@constraint(sub_model, sum(v[i] for i in 1:n)== 1)


    # Edges constraint
    for i in 1:n
        for j in 1:n
            if adj[i,j] > 0.0 && i < j
                @constraint(sub_model, - v_ij[i,j] - v[i] + v[j] <= 0)
                @constraint(sub_model, - v_ij[i,j] + v[i] - v[j] <= 0)
            end
        end
    end
    
    optimize!(sub_model)
    feasibleSolutionFound = primal_status(sub_model) == MOI.FEASIBLE_POINT
    isOptimal = termination_status(sub_model) == MOI.OPTIMAL
    if !(feasibleSolutionFound && isOptimal)
        println("Optimal not found in subproblem")
    end
    return JuMP.objective_value(sub_model), JuMP.value.(v_ij), JuMP.value.(v), JuMP.solve_time(sub_model)
end


function linksBendersDijkstra(inputFile::String="benders-graphe-hexagone"; showResult::Bool= false,
     timeLimit::Float64=-1.0, bnd::Int64=1)::Any
    start = time()
    readGraph("./tp2/instances/"*inputFile*".txt")

    # Build graph
    graph = Graph(n)

    for i in 1:n
        for j in (i + 1):n
            if adj[i,j] > 0.0
                add_edge!(graph, i, j)
            end
        end
    end
    # Get shortests paths
    source_paths = dijkstra_shortest_paths(graph, 1)
    paths= enumerate_paths(source_paths)

    return sum([demande[i]*(length(paths[i]) - 1) for i in 2:n]), time() - start
end