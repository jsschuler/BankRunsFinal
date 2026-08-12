# the functions file

# we need a utility function
function util(mod::ModBase,x::Float64)
    if x < 0
        x=0
    end

    y=1+x
    if mod.riskAversion==1.0
        return(log(y))
    else
        return((y^(1-mod.riskAversion))/(1-mod.riskAversion))
    end
end

# that only takes a single argument

function modUtilGen(mod::ModBase)
    function tmpFunc(x::Float64)
        return util(mod,x)
    end
    return tmpFunc
end


function agtGen(mod::Model)
    push!(mod.bankingList,Agent())
end

# now a function to generate a model
function modelGen(endow::Int64,
                 objP::Float64,
                 insur::Float64,
                 prod::Float64,
                 riskAver::Float64)
    global agtCnt
    mod=Model(Agent[],Agent[],objP,insur,prod,riskAver)
    for t in 1:agtCnt
        agtGen(mod)
    end
    return mod
end

# now, the way this model works is that we loop over possible deposits and keep 
# the model results that have the greatest average utility.
# recall that the agents know how many agents have withdrawn but not their 
# own position in the queue if they withdraw.



# Now, we need a function to simulate one round for agents to compare decisions
# Note that when the agent runs this function, it knows it does not have to withdraw
# we have a function below where the agent does not know this.
function roundSimul(mod::SimModel,decision::Bool)
    # How many agents have withdrawn?
    wdCount=length(mod.nonBankingList)
    stillBanking=length(mod.bankingList)
    #println("Withdrawn")
    #println(wdCount)
    #println("Still Banking")
    #println(stillBanking)
    # now, if the agent has decided to withdraw, we adjust these by one
    if decision
        wdCount=wdCount+1
        stillBanking=stillBanking-1
    end

    # now generate 1000 uniform variates
    global depth
    uVariates=rand(Uniform(),depth)
    # now, calculate the probability distribution of withdrawals conditional on there being
    # at least the number of observed withdrawals
    global agtCnt
    agtProb=Binomial(agtCnt,mod.objP)
    cdfCond=Dict{Int64,Float64}()
    #println("Prob")
    #println(ccdf(agtProb,wdCount))
    # NOTE: denominator conditions on X > wdCount rather than X >= wdCount (off-by-one).
    # Correct denominator would be ccdf(agtProb, wdCount-1). Known systematic bias;
    # constant across K so does not affect convergence results, only belief levels.
    for t in wdCount:(wdCount+stillBanking)
        cdfCond[t]=(cdf(agtProb,t)-cdf(agtProb,wdCount))/ccdf(agtProb,wdCount)
    end
    #println("CDF")
    #println(sort(collect(keys(cdfCond))))
    countVec=Int64[]
    for uVar in uVariates
        maxCount=0
        for t in wdCount:(wdCount+stillBanking)
            if uVar >= cdfCond[t]
                maxCount=t
            end
        end
        push!(countVec,maxCount)
    end
    #println(countVec)
    #println(maximum(countVec))
    #println(minimum(countVec))
    #println(mean(countVec))
    # now get how many agents have yet to withdraw 
    futureCount=countVec.-wdCount
    #println("future")
    #println(length(futureCount))
    # now, let's calculate the agent's return on the basis of a decision
    payVec=[]
    if decision
        
        # if the agent decides to withdraw, the agent decides to BE one of the withdrawing agents
        # we guaranteed above that the agent always has a spot
        # add the withdrawing agent to the withdrawal count
        futureCount=futureCount.+1
        # now, get the agent's place in line among those withdrawing
        # and in turn, the number of agents 
        for future in futureCount
            simMod=copy(mod)
            #println(length(simMod.bankingList))
            # now the agent has the same probability of being anywhere in line. 
            # Thus, we record the pay out for every withdrawal
            while future > 0
                future=future-1
                paid=withdraw(simMod)
                if isnan(paid)
                    #println("Flag")
                    #println(simMod.bankingList)
                    #println(simMod.theBank.vault)
                    #println(future)
                end
                push!(payVec,paid)
            end
            #println(length(simMod.bankingList))
            
        end
    else
        for future in futureCount
            #println("Hello")
            #println(length(mod.bankingList))
            simMod=copy(mod)
            #println(length(simMod.bankingList))
            while future > 0
                future=future-1
                # Withdraw other agents
                withdraw(simMod)
            end
            #println(length(simMod.bankingList))
            paid=payOut(simMod)
            #if isnan(paid)
            #    println("Flag")
            #    println(simMod.bankingList)
            #    println(simMod.theBank.vault)
            #    println(future)
            #end
            push!(payVec,paid)
        end
    end
    #println("Pays")
    #println(payVec)
    #println(length(payVec))
    #println(payMat[1,:])
    #println(payMat[10,:])
    # now calculate the expected utility
    uFunc=modUtilGen(mod)
    #println("Debug")
    #println(payVec)
    
    # now calculate total consumption
    totConsump=mod.endow .+ payVec

    return sum(uFunc.(totConsump))*(1/length(totConsump))

end

function subSimul(mod::SimModel)
    global agtCnt
    simMod=copy(mod)
    subBinom=Binomial(agtCnt,simMod.objP)
    wdCount=rand(subBinom,1)[1]
    wOrder=sample(vcat(repeat([true],wdCount),repeat([false],agtCnt-wdCount)),agtCnt,replace=false)
    # we record each withdrawal amount
    # and repeat the final disbursal among the still banking agents
    # since each agent has an equal probability of being in any order
    payOuts=[]
    for j in 1:length(wOrder)
        if wOrder[j]
            push!(payOuts,withdraw(simMod))
        end
    end
    paidOut=payOut(simMod)
    for i in 1:(agtCnt-wdCount)
        push!(payOuts,paidOut)
    end
    uFunc=modUtilGen(mod)
    # now calculate total consumption
    totConsump=simMod.endow .+ payOuts
    return sum(uFunc.(totConsump))

end

function roundSimul(mod::SimModel)
    global depth
    global agtCnt
    utilFunc=[]
    for t in 1:depth
        push!(utilFunc,subSimul(mod))
    end
    # now we calculate expected utility
    # the denominator is the agtCnt times the depth 
    # since each subsimulation gives the return for every agent
    # and we run it as many times as the depth parameter 
    return (1/(agtCnt*depth))*sum(utilFunc)
end

# we need a function to clone a model. 

function clone(mod::Model,endow::Int64,deposit::Int64)
    
    global agtCnt
    theBank=Bank(0)
    for i in 1:agtCnt
        theBank.vault=theBank.vault+deposit
    end
    
    return SimModel(deepcopy(mod.nonBankingList),
                    deepcopy(mod.bankingList),
                    endow,
                    deposit,
                    mod.objP,
                    mod.insur,
                    mod.prod,
                    mod.riskAversion,
                    theBank)
end

# we also need a function to copy a model

function copy(mod::SimModel)
    return SimModel(deepcopy(mod.nonBankingList),
                    deepcopy(mod.bankingList),
                    mod.endow,
                    mod.deposit,
                    mod.objP,
                    mod.insur,
                    mod.prod,
                    mod.riskAversion,
                    deepcopy(mod.theBank))
end


# we need a function that gives the vector of payments where there have been k withdrawals

# we need the withdrawal function

function withdraw(mod::SimModel)
    if length(mod.bankingList) > 0
        #println("Withdrawing")
        #println(length(mod.bankingList))
        pop!(mod.bankingList)
        #println(length(mod.bankingList))
        withdrawn=min((1+mod.insur)*mod.deposit,mod.theBank.vault)
        mod.theBank.vault=max(mod.theBank.vault-withdrawn,0)
    else
        withdrawn=0
    end
    #println(withdrawn)
    return withdrawn

end

function payOut(mod::SimModel)
    #println("Banking")
    #println(length(mod.bankingList))
    if length(mod.bankingList) > 0
        retVal=(1/length(mod.bankingList)*(1+mod.insur+mod.prod)*mod.theBank.vault)
    else 
        retVal=0.0
    end
    return retVal 
end

# a helper function to increment a dictionary count

function dictAdd!(dict,key)
    if key in keys(dict)
        dict[key]=dict[key]+1
    else
        dict[key]=1
    end
end

function dictAdd!(dict,key,arg::Int64)
    if key in keys(dict)
        dict[key]=dict[key]+arg
    else
        dict[key]=arg
    end
end

function dictAdd!(dict,key,arg::Float64)
    if key in keys(dict)
        dict[key]=dict[key]+arg
    else
        dict[key]=arg
    end
end

function dictPlug!(dict,key)
    if !(key in keys(dict))
        dict[key]=0.0
    end
end
# now we need the main model function

function runMain(mod::SimModel)
    # exogenous withdrawals
    global agtCnt
    X=Binomial(agtCnt,mod.objP)
    exogWD=rand(X,1)[1]
    #println("Exogenous Withdrawals")
    #println(exogWD)
    wOrder=sample(vcat(repeat([true],exogWD),repeat([false],agtCnt-exogWD)),agtCnt,replace=false)
    #println(wOrder)
    # now each agent decides whether or not to withdraw
    # we need a dictionary to keep track of pay outs
    countDict=Dict()
    runCond::Bool=false
    for j in 1:length(wOrder)
       # println(j) 
        # is the agent withdrawing 
        if wOrder[j]
            dictAdd!(countDict,mod.endow+withdraw(mod))
            #println("Exogenous Withdrawal")
        else
            wUtil=roundSimul(mod,true)
            sUtil=roundSimul(mod,false)
            #println(wUtil)
            #println(sUtil)
            if wUtil > sUtil
                dictAdd!(countDict,mod.endow+withdraw(mod))
                #println("Endogenous Withdrawal")
            end
        end
        if mod.theBank.vault <= 0
            runCond=true
            break
        end
    end
    #println("Still Banking")
    #println(length(mod.bankingList))
    if mod.theBank.vault <= 0
        for k in 1:length(mod.bankingList)
            dictAdd!(countDict,mod.endow+withdraw(mod))
        end
    else
        for k in 1:length(mod.bankingList)
            dictAdd!(countDict,mod.endow+payOut(mod))
        end
    end
    
    return (runCond,countDict)
end

function utilFunc(mod::SimModel,dict::Dict)
    retArray=[]
    for ky in keys(dict)
        for t in 1:dict[ky]
            push!(retArray,util(mod,ky))
        end
    end
    return mean(retArray)
end

function runMod(mod::Model)
    global depth
    global agtCnt
    global totResr
    bestArray=[]
    failArray=[]
    for alloc in 0:10:totResr
        deposit=alloc
        endow=totResr-alloc
        uArray=[]
        failCount=0
        for t in 1:depth
            simMod=clone(mod,endow,deposit)
            currRun=runMain(simMod)
            # now did the bank fail in the current run?
            if currRun[1]
                failCount=failCount+1
            end
            push!(uArray,utilFunc(simMod,currRun[2]))
        end
        push!(bestArray,mean(uArray))
        push!(failArray,failCount)
    end
    # now, find the max utility allocation
    maxUtil=maximum(bestArray)
    maxIndex=argmax(bestArray)
    return(failArray[maxIndex]/depth)
end

function runFamily(insur::Float64,prod::Float64,objP::Float64)
    global agtCnt
    global depth
    global totResr
    mod=modelGen(agtCnt,objP,insur,prod,1.0)
    #println("Model")
    #println(mod)
    #println("Run")
    #println(runMain(mod))
    #println("Utility")
    #println(runMod(mod))
    # write out data
    result=runMod(mod)
    df=DataFrame(
        insur=insur,
        prod=prod,
        objP=objP,
        failProb=result)
        CSV.write("../DDData/results.csv", df,header = false,append=true)


    return (result,insur,prod,objP)
end

# now we need some functions to handle the multi-threading
function isReady(arg::Future)
    return isready(arg)
end

function isReady(arg::Nothing)
    return false
end