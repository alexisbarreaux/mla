using JuMP
using CPLEX

include("./instances/exemple-lecture-graphe.jl")
"""
include("./tp2/exercice2.jl")
readGraph("./tp2/instances/benders-graphe-hexagone.txt")
linksBendersRelaxed("benders-graphe-hexagone")
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


function linksBendersRelaxed(inputFile::String="benders-graphe-hexagone"; showResult::Bool= false,
     timeLimit::Float64=-1.0, bnd::Int64=1)::Any
    
    start = time()
    readGraph("./tp2/instances/"*inputFile*".txt")
    # Creating the model
    model = Model(CPLEX.Optimizer)
    set_silent(model)
    if timeLimit >= 0
        set_time_limit_sec(model, timeLimit)
    end

    ##### Variables #####
    @variable(model, y[i in 1:n, j in 1:n] >= 0.)

    ##### Objective #####
    @objective(model, Min, sum(y[i,j] for i in 1:n for j in 1:n if adj[i,j] > 0.0 && i < j))
    
    ##### Constraints #####

    hasAddedConstraint = true
    yIsRelaxed = true
    nbIterRelaxed = 0
    nbIter = 0

    feasibleSolutionFound = false
    isOptimal = false
    y_val = nothing
    value = 0

    while (hasAddedConstraint || yIsRelaxed) && (timeLimit < 0 || (time() - start) < timeLimit)
        if hasAddedConstraint == false
            # Y becomes integer and we go on
            yIsRelaxed = false
            set_integer.(y)
        end
        hasAddedConstraint = false

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
            subVal, v_ij_val, v_val, _= subProblem(y_val, bnd)
            if subVal > 1e-5
                if yIsRelaxed
                    nbIterRelaxed += 1
                else
                    nbIter += 1
                end
                if showResult
                    println("Subproblem value ", subVal)
                    println("Adding optimality cut")
                end
                @constraint(model, - bnd*sum(y[i,j] * v_ij_val[i,j] for i in 1:n for j in 1:n if adj[i,j] > 0.0 && i < j) + 
                sum(demande[i] * v_val[i] for i in 1:n) <= 0)
                hasAddedConstraint = true
            end
        else
            break
        end

    end

    ### Display the solution
    feasibleSolutionFound = primal_status(model) == MOI.FEASIBLE_POINT
    isOptimal = termination_status(model) == MOI.OPTIMAL
    if feasibleSolutionFound
        # If time was exceeded, ensure we have no invalid cuts for the last 
        if (time() - start) > timeLimit
            subVal, _,_,_= subProblem(y_val, bnd)
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

        return isOptimal, value, time() - start, nbIterRelaxed, nbIter
    else
        println("Not feasible!!")
        return
    end


end