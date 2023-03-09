using JuMP
using CPLEX

"""
include("./tp2/exercice1.jl")
include("./tp2/instances/exemple-lecture-graphe.jl")
readGraph("./tp2/instances/benders-graphe-hexagone.txt")
linksBenders(1000)
"""

function subProblem(y_val::Vector{Float64}, bnd::Int64, d::Vector{Int64}, n::Int64, E::Matrix)::Any
    # Creating the model
    sub_model = Model(CPLEX.Optimizer)
    set_silent(sub_model)

    ##### Variables #####
    @variable(sub_model, v_ij[i in 1:n, j in 1:n if adj[i,j] > 0.0] >= 0.)
    @variable(sub_model, v[i in 1:n] >= 0.)

    ##### Objective #####
    @objective(sub_model, Max, - bnd*sum(y_val[i,j] * v_ij[(i,j)] for i in 1:n for j in 1:n if adj[i,j] > 0.0) + 
                sum(d[i] * v[i] for i in 1:n))
    
    ##### Constraints #####
    @constraint(sub_model, v[1] == 0)
    # Feasibility constraint
    @constraint(sub_model, sum(v_ij) + sum(v[i] for i in 1:n)== 1)

    # Edges constraint
    for i in 1:n
        for j in 1:n
            if adj[i,j] > 0.0
                @constraint(sub_model, v[(i,j)] - v[i] + v[j] <= 0)
                @constraint(sub_model, v[(i,j)] + v[i] - v[j] <= 0)
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


function linksBenders(inputFile::String="benders-graphe-hexagone.txt", showResult::Bool= false, timeLimit::Float64=-1.0)::Any
    readGraph("./tp2/instances/"*inputFile)
    # Creating the model
    model = Model(CPLEX.Optimizer)
    set_silent(model)
    if timeLimit >= 0
        set_time_limit_sec(model, timeLimit)
    end

    ##### Variables #####
    @variable(model, y[i in 1:n, j in 1:n if adj[i,j] > 0.0] >= 0., Int)

    ##### Objective #####
    @objective(model, Min, sum(y))
    
    ##### Constraints #####

    hasAddedConstraint = true
    runTime = 0
    while hasAddedConstraint
        hasAddedConstraint = false
        # Solve current state

        # Benders
        optimize!(model)
        feasibleSolutionFound = primal_status(model) == MOI.FEASIBLE_POINT
        isOptimal = termination_status(model) == MOI.OPTIMAL
        runTime += JuMP.solve_time(model)

        if feasibleSolutionFound
            value = JuMP.objective_value(model)
            # Solve sub problems with current optimum
            y_val = JuMP.value.(y)
            if showResult && !silent
                println("Current value ", value, " y ", y_val)
            end
            subVal, v_ij_val, v_val, subTime= subProblem(y_val, w_val, n, c, d)
            runTime += subTime
            if subVal > 1e-5
                if !silent
                    println("Subproblem value ", subVal)
                    println("Adding optimality cut")
                end
                @constraint(model, - bnd*sum(y[i,j] * v_ij_val[(i,j)] for i in 1:n for j in 1:n if adj[i,j] > 0.0) + 
                sum(d[i] * v_val[i] for i in 1:n) <= 0)
                hasAddedConstraint = true
            end
        else
            break
        end

    end

    ### Display the solution
    feasibleSolutionFound = primal_status(model) == MOI.FEASIBLE_POINT
    isOptimal = termination_status(model) == MOI.OPTIMAL
    if feasibleSolutionFound && isOptimal
        # Il faut checker si on a encore des plans non valides
        value = JuMP.objective_value(model)
        # Solve sub problems with current optimum
        w_val = JuMP.value.(w)
        y_val = JuMP.value.(y)
        if showResult
            println()
            println("Results : ")
            println("Value : ", value, " Time ", runTime, "s.")
        end

        return isOptimal, value, runTime
    else
        println("Not feasible!!")
        return
    end


end