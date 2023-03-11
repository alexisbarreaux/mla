using JuMP
using CPLEX
using Graphs

include("./instances/exemple-lecture-graphe.jl")
"""
include("./tp2/exercice1.jl")
readGraph("./tp2/instances/benders-graphe-hexagone.txt")
linksBenders("benders-graphe-hexagone")
"""

function subProblem(y_val::Matrix{Float64}, bnd::Int64)::Any
    # Creating the model
    sub_model = Model(CPLEX.Optimizer)
    set_silent(sub_model)

    ##### Variables #####
    @variable(sub_model, v_ij[i in 1:n, j in 1:n] >= 0.0)
    @variable(sub_model, v[i in 1:n] >= 0.0)
    #@variable(sub_model, v[i in 1:n])

    ##### Objective #####
    @objective(sub_model, Max, -bnd * sum(y_val[i, j] * v_ij[i, j] for i in 1:n for j in 1:n if adj[i, j] > 0.0 && i < j) +
                               sum(demande[i] * v[i] for i in 1:n))

    ##### Constraints #####
    @constraint(sub_model, v[1] == 0)
    # Feasibility constraint
    @constraint(sub_model, sum(v_ij[i, j] for i in 1:n for j in 1:n if adj[i, j] > 0.0 && i < j) + sum(v[i] for i in 1:n) == 10)
    #@constraint(sub_model, sum(v_ij[i, j] for i in 1:n for j in 1:n if adj[i, j] > 0.0 && i < j) <= 1e-1)
    #@constraint(sub_model, sum(v[i] for i in 1:n) <= 1)
    #@constraint(sub_model, -bnd * sum(y_val[i, j] * v_ij[i, j] for i in 1:n for j in 1:n if adj[i, j] > 0.0 && i < j) + sum(demande[i] * v[i] for i in 1:n) <= 1)


    # Edges constraint
    for i in 1:n
        for j in 1:n
            if adj[i, j] > 0.0 && i < j
                @constraint(sub_model, -v_ij[i, j] - v[i] + v[j] <= 0)
                @constraint(sub_model, -v_ij[i, j] + v[i] - v[j] <= 0)
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


function linksBenders(inputFile::String="benders-graphe-hexagone"; showResult::Bool=false,
    timeLimit::Float64=-1.0, bnd::Int64=1)::Any
    start = time()
    readGraph("./tp2/instances/" * inputFile * ".txt")
    # Creating the model
    model = Model(CPLEX.Optimizer)
    set_silent(model)

    ##### Variables #####
    @variable(model, y[i in 1:n, j in 1:n] >= 0.0, Int)

    ##### Objective #####
    @objective(model, Min, sum(y[i, j] for i in 1:n for j in 1:n if adj[i, j] > 0.0 && i < j))

    ##### Bounds #####
    lower_bound, upper_bound = boundDijkstra(inputFile, bnd=bnd)
    #@constraint(model, sum(y[i, j] for i in 1:n for j in 1:n if adj[i, j] > 0.0 && i < j) <= upper_bound)
    #@constraint(model, sum(y[i, j] for i in 1:n for j in 1:n if adj[i, j] > 0.0 && i < j) >= lower_bound)

    ##### Pre-cuts #####
    #@constraint(model, -bnd * sum(y[i, j] for i in 1:n for j in 1:n if adj[i, j] > 0.0 && i < j) + sum(demande) <= 0)

    ##### Constraints #####

    hasAddedConstraint = true
    nbIter = 0
    feasibleSolutionFound = false
    isOptimal = false
    y_val = nothing
    value = 0

    while hasAddedConstraint && (timeLimit < 0 || (time() - start) < timeLimit)
        hasAddedConstraint = false
        # Solve current state

        # Benders
        if timeLimit >= 0
            set_time_limit_sec(model, timeLimit - (time() - start))
        end
        optimize!(model)
        feasibleSolutionFound = primal_status(model) == MOI.FEASIBLE_POINT
        isOptimal = termination_status(model) == MOI.OPTIMAL
        y_val = JuMP.value.(y)

        if feasibleSolutionFound && isOptimal
            value = JuMP.objective_value(model)
            # Solve sub problems with current optimum
            if showResult
                println("Current value ", value)
            end
            subVal, v_ij_val, v_val, subTime = subProblem(y_val, bnd)
            if subVal > 1e-5
                nbIter += 1
                if showResult
                    println("Subproblem value ", subVal)
                    println("Adding optimality cut")
                end
                @constraint(model, -bnd * sum(y[i, j] * v_ij_val[i, j] for i in 1:n for j in 1:n if adj[i, j] > 0.0 && i < j) +
                                   sum(demande[i] * v_val[i] for i in 1:n) <= 0)
                hasAddedConstraint = true
            end
        else
            break
        end
    end

    ### Display the solution
    if feasibleSolutionFound
        # If time was exceeded, ensure we have no invalid cuts for the last 
        if (time() - start) > timeLimit
            subVal, _, _, _ = subProblem(y_val, bnd)
            if subVal > 1e-5
                println("There are still invalid cuts after time limit")
                return
            end
        end

        if showResult
            println()
            println("Results : ")
            println("Value : ", value, " Time ", time() - start, "s.")
        end

        return isOptimal, value, time() - start, nbIter
    else
        println("Not feasible!!")
        return
    end


end

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