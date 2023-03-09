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
    @variable(sub_model, v_ij[(i,j) in eachrow(E)] >= 0.)
    @variable(sub_model, v[i in 1:n] >= 0.)

    ##### Objective #####
    @objective(sub_model, Max, - bnd*sum(y_val[i,j] * v_ij[(i,j)] for (i,j) in eachrow(E)) + 
                sum(d[i] * v[i] for i in 1:n))
    
    ##### Constraints #####
    @constraint(sub_model, v[1] == 0)
    # Feasibility constraint
    @constraint(sub_model, sum(v[(i,j)] for (i,j) in eachrow(E)) + sum(v[i] for i in 1:n)== 1)

    # Edges constraint
    for (i,j) in eachrow(E)
        @constraint(sub_model, v[(i,j)] - v[i] + v[j] <= 0)
        @constraint(sub_model, v[(i,j)] + v[i] - v[j] <= 0)
    end
    
    optimize!(sub_model)
    feasibleSolutionFound = primal_status(sub_model) == MOI.FEASIBLE_POINT
    isOptimal = termination_status(sub_model) == MOI.OPTIMAL
    if !(feasibleSolutionFound && isOptimal)
        println("Optimal not found in subproblem")
    end
    return JuMP.objective_value(sub_model), JuMP.value.(v_ij), JuMP.value.(v)
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
    @variable(model, y[(i,j) in eachrow(E)] >= 0., Int)
    @variable(model, X[i in 1:n, j in 1:n] >= 0.)

    ##### Objective #####
    @objective(model, Min, sum(y[(i,j) for (i,j) in eachrow(E)]) + w)
    
    ##### Constraints #####
    # Constraint on y
    @constraint(model, y[1] >= y[2])
    @constraint(model, y[1] >= y[3])
    @constraint(model, (d - sum(y[i] for i in 1:n)) <= 0)

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
            w_val = JuMP.value.(w)
            y_val = JuMP.value.(y)
            if showResult && !silent
                println("Current value ", value, " w ", w_val, " y ", y_val)
            end
            subVal, v, b, subTime= subProblem(y_val, w_val, n, c, d)
            runTime += subTime
            if subVal > (w_val + 1e-5)
                if !silent
                    println("Subproblem value ", subVal)
                    println("Adding optimality cut")
                end
                @constraint(model, w >= d * b - sum(y[i] * v[i] for i in 1:n))
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