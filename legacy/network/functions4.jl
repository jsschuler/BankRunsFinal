# initialization functions


function modelGen(key::String,
                  seed1::Int64,
                  seed2::Int64,
                  agtCnt::Int64,
                  probThresh::Float64,
                  network::SimpleGraph{Int64},
                  depositDistribution::Distribution,
                  reserveRatio::Float64,
                  depositInsurance::Float64,
                  exogProb::Distribution)
    # generate the deposits
    Random.seed!(seed1)
    deposits=rand(depositDistribution,agtCnt)
    # generate the agents
    agtList::Array{Agent}=Agent[]
    for i in 1:agtCnt
        push!(agtList,Agent(i,deposits[i],true))
    end

    agtDF=DataFrame(key=key,idx=1:agtCnt,deposit=deposits)

    CSV.write(dataDir*"/"*"agents"*string(workerCore)*".csv",agtDF,writeheader=false,append=true)

    bankingList::Array{Agent}=Agent[]

    for agt in agtList
            push!(bankingList,agt)
    end
    # generate the bank
    theBank=Bank(
        reserveRatio*sum(deposits),
        bankingList,
        Agent[]
    )
    mod=Model(
        key,
        agtList,
        reserveRatio,
        theBank,
        depositInsurance,
        seed1,
        seed2,
        depositDistribution,
        network,
        probThresh,
        exogProb
    )
    return mod
end

function neighborList(mod::Model,agt::Agent)
    # get the neighbors of the agent
    neighbors=all_neighbors(mod.network,agt.idx)
    # get the list of agents that are neighbors
    neighborAgents=Agent[]
    for n in neighbors
        push!(neighborAgents,mod.agtList[n])
    end
    return neighborAgents
end

function deposit(agt::Agent)
    return agt.deposit
end
function deposit(agt::simAgent)
    return agt.deposit
end

# now the cloning function
function clone(mod::Model)
    # clone the model
   cloneAgtList::Array{simAgent}=simAgent[]
    for agt in mod.agtList
        push!(cloneAgtList,simAgent(agt.idx,agt.deposit,agt.banked))
    end

    theBank=simBank(
        mod.theBank.vault,
        simAgent[],
        simAgent[]
    )
    for agt in cloneAgtList
        if agt.banked
            push!(theBank.bankingList,agt)
        else
            push!(theBank.withdrawHistory,agt)
        end
    end
    return simModel(
        cloneAgtList,
        theBank,
        mod.depositInsurance,
        mod.depositDistribution
    )
end

function clone(mod::simModel)
    # clone the model
    cloneAgtList::Array{simAgent}=simAgent[]
    for agt in mod.agtList
        push!(cloneAgtList,simAgent(agt.idx,agt.deposit,agt.banked))
    end

    theBank=simBank(
        mod.theBank.vault,
        simAgent[],
        simAgent[]
    )
    for agt in cloneAgtList
        if agt.banked
            push!(theBank.bankingList,agt)
        else
            push!(theBank.withdrawHistory,agt)
        end
    end
    return simModel(
        cloneAgtList,
        theBank,
        mod.depositInsurance,
        mod.depositDistribution
    )
end

# and a function to perform the withdrawal
function withdraw(mod::Model,agt::Agent)
    # what is the status of the deposit insurance? 
    # the deposit insurance is either a quantile (0 to 1) of the deposit distribution
    # or if not in this range, we apply the adaptive deposit insurance scheme
    maxDepositInsurance=0.0
    # what is the maximum deposit insurance payout?
    if !(0.0<= mod.depositInsurance < 1.0)
        if length(mod.theBank.withdrawHistory)==0
            maxDepositInsurance=0.0
        else
            # get the maximum deposit insurance payout
            # this is the maximum deposit of the agents that have withdrawn
            # and is the adaptive deposit insurance scheme
            # we need to check if there are any agents that have withdrawn
            # if not, we set the maximum deposit insurance to 0.0
            # otherwise, we set it to the maximum deposit of the agents that have withdrawn
            # get the maximum deposit insurance payout
            maxDepositInsurance=maximum(deposit.(mod.theBank.withdrawHistory))
        end
    else
        # if the deposit insurance is a quantile, we apply the adaptive deposit insurance scheme
        # get the quantile of the deposit distribution
        maxDepositInsurance=quantile(mod.depositDistribution,mod.depositInsurance)
    end

    # withdraw the agent
    agt.banked=false
    # add the agent to the withdraw history
    push!(mod.theBank.withdrawHistory,agt)
    # remove the agent from the banking list
    mod.theBank.bankingList=filter(x->x.idx!=agt.idx,mod.theBank.bankingList)
    # what does the agent get out?
    if agt.deposit>mod.theBank.vault
        agtReturn=max(0.0,mod.theBank.vault,min(agt.deposit,maxDepositInsurance))
    else
        agtReturn=agt.deposit
    end
    mod.theBank.vault-=agt.deposit
    return agtReturn
end

function withdraw(mod::simModel,agt::simAgent)
        # what is the status of the deposit insurance? 
    # the deposit insurance is either a quantile (0 to 1) of the deposit distribution
    # or if not in this range, we apply the adaptive deposit insurance scheme
    maxDepositInsurance=0.0
    # what is the maximum deposit insurance payout?
    if !(0.0<= mod.depositInsurance < 1.0)
        if length(mod.theBank.withdrawHistory)==0
            maxDepositInsurance=0.0
        else
            # get the maximum deposit insurance payout
            # this is the maximum deposit of the agents that have withdrawn
            # and is the adaptive deposit insurance scheme
            # we need to check if there are any agents that have withdrawn
            # if not, we set the maximum deposit insurance to 0.0
            # otherwise, we set it to the maximum deposit of the agents that have withdrawn
            # get the maximum deposit insurance payout
            maxDepositInsurance=maximum(deposit.(mod.theBank.withdrawHistory))
        end
    else
                # if the deposit insurance is a quantile, we apply the adaptive deposit insurance scheme
        # get the quantile of the deposit distribution
        maxDepositInsurance=quantile(mod.depositDistribution,mod.depositInsurance)
    end

    
    # withdraw the agent
    agt.banked=false
    # add the agent to the withdraw history
    push!(mod.theBank.withdrawHistory,agt)
    # remove the agent from the banking list
    mod.theBank.bankingList=filter(x->x.idx!=agt.idx,mod.theBank.bankingList)
    # what does the agent get out?
    if agt.deposit>mod.theBank.vault
        agtReturn=max(0.0,mod.theBank.vault,min(agt.deposit,maxDepositInsurance))
    else
        agtReturn=agt.deposit
    end
    mod.theBank.vault-=agt.deposit
    # update the bank vault
    return agtReturn
end


# we need a function to withdraw exogenously
function exogWithdrawals(mod::Model)
    # get the number of agents that will withdraw
    numWithdrawals=rand(mod.exogProb,1)[1]
    # get the list of agents that will withdraw
    withdrawList=sample(mod.agtList,numWithdrawals,replace=false)
    # set the banked status to false
    global dataDir
    global workerCore
    for agt in withdrawList
        #println("Exogenous Withdrawal Agent ",agt.idx)
        withdraw(mod,agt)
        reportRow=DataFrame(key=mod.key,agent=agt.idx,exogenous=true,deposit=agt.deposit,tick=0,vault=mod.theBank.vault)
        CSV.write(dataDir*"/"*"bankRunExogenous"*string(workerCore)*".csv",reportRow,writeheader=false,append=true)
    end
    return withdrawList
end

function index(agt::Agent)
    return agt.idx
end
function index(agt::simAgent)
    return agt.idx
end

function subModelRun(mod::simModel,agt::Agent,withdrawingAgents::Array{Agent},additionalWithdrawals::Int64)
    # Phase 1: force withdrawals of observed (exogenous) neighbors in the submodel.
    #println("Agent ",agt.idx," sees ",length(withdrawingAgents)," withdrawing agents and anticipates ",additionalWithdrawals," additional withdrawals.")
    for idx in index.(withdrawingAgents)
        # get the agent
        currAgt=mod.agtList[idx]
        # withdraw the agent
        withdraw(mod,currAgt)
    end
    stillBanking=Random.shuffle(mod.theBank.bankingList)
    # Phase 2: remove additional agents to reflect expected endogenous withdrawals.
    # if the current agent is among them, we skip it. 
    numWithdrawn::Int64=0
    idx::Int64=1
    #println(additionalWithdrawals)
    while numWithdrawn < additionalWithdrawals && idx <= length(stillBanking)
        if stillBanking[idx].idx!=agt.idx
            withdraw(mod,stillBanking[idx])
            numWithdrawn+=1
        end
        idx+=1
    end
    # Now simulate the focal agent withdrawing.
    #println("Chk")
    #println(agt in mod.agtList
    currAgt=filter(x->x.idx==agt.idx,mod.agtList)[1]
    result=withdraw(mod,currAgt)
    #println("Agent ",agt.idx," Deposit was ",agt.deposit," with result ", result)
    return (result,result < agt.deposit)
end

# now the main model function
function modelRun(mod::Model)
    runState::Bool=false
    # set the seed
    Random.seed!(mod.seed2)



    exogWithdrawals(mod)
    
    # make a copy of the model
    simModel=clone(mod)

    # now, whenever an agent withdraws, we reset a state variable since this means all other agents will
    # re-examing their decision to bank
    halt::Bool=false
    # now, randomize the order of the agents still banking
    t=0
    if mod.theBank.vault<=0.0
        # if the bank is bankrupt, we need to stop the simulation
        runState=true
        #println("Bankrupt at tick ",t," with vault ",mod.theBank.vault)
        return runState
    end
    while !halt && !runState
        halt=true
        t=t+1
        stillBanking=Random.shuffle(mod.theBank.bankingList)
        # each agent observes the percentage of its neighbors that have withdrawn
        for agt in stillBanking
            #println("Running Agent ",agt.idx)
            # get the neighbors of the agent
            neighbors=neighborList(mod,agt)
            #println("Agent ",agt.idx," has ",length(neighbors)," neighbors")
            withdrawnNeighbors::Array{Agent}=Agent[]
            for n in neighbors
                if !n.banked
                    push!(withdrawnNeighbors,n)
                end
            end
            #println("Agent ",agt.idx," has ",length(withdrawnNeighbors)," withdrawn neighbors")
            # now calculate the proportion of neighbors that have withdrawn
            propWithdrawn = isempty(neighbors) ? 0.0 : (length(withdrawnNeighbors) / length(neighbors))
            #println("Prop Withdrawn for Agent ",agt.idx," is ",propWithdrawn)
            # Infer total withdrawals in population from neighbor sample.
            totalWithdrawn=round(Int64,propWithdrawn*length(mod.agtList))
            #println("Total Withdrawn for Agent ",agt.idx," is ",totalWithdrawn)
            # Draw possible total withdrawals and convert to additional (endogenous) count.
            totalWithdrawnRaw = totalWithdrawn
            totalWithdrawn = clamp(totalWithdrawn, 0, length(mod.agtList)-1)
            if totalWithdrawn != totalWithdrawnRaw
                println(
                    "Clamp triggered. key=", mod.key,
                    " totalWithdrawnRaw=", totalWithdrawnRaw,
                    " totalWithdrawn=", totalWithdrawn,
                    " N=", length(mod.agtList),
                    " neighbors=", length(neighbors),
                    " withdrawnNeighbors=", length(withdrawnNeighbors),
                    " propWithdrawn=", propWithdrawn
                )
            end
            newGeometric=truncated(mod.exogProb,totalWithdrawn,length(mod.agtList)-1)
            totalWithdrawn=rand(newGeometric,depth)

            additionalWithdrawals=totalWithdrawn.-length(withdrawnNeighbors)
            additionalWithdrawals=map(x -> max(0, x), additionalWithdrawals)
            # Monte Carlo: compare outcomes if the agent withdraws now vs. stays.
            subModResults=[]
            initWithdrawResults=[]
            global depth
            #println("Simulating for agent ",agt.idx)
            for k in 1:depth
                #println("Simulating for agent ",agt.idx)
                push!(subModResults,subModelRun((clone(simModel),agt,withdrawnNeighbors,additionalWithdrawals[k])...))
                baseMod=clone(simModel)
                currAgt=filter(x->x.idx==agt.idx,baseMod.agtList)[1]
                push!(initWithdrawResults,withdraw(baseMod,currAgt))
            end
            # now, have the agent calculate its probability of getting less than its deposit
            resultsStay::Array{Bool}=Bool[]
            for el in subModResults
                push!(resultsStay,el[2])
            end
            resultsWD::Array{Bool}=Bool[]
            for el in initWithdrawResults
                push!(resultsWD,el < agt.deposit)
            end
            #println("submodel results for agent ",agt.idx," are ",subModResults)
            #println("initial withdrawal results for agent ",agt.idx," are ",initWithdrawResults)

            # now calculate the probability of getting less than its deposit
            # should this be 1-?
            probLessThanDepositStay=1-mean(resultsStay)
            probLessThanDepositWD=1-mean(resultsWD)
            # now if the probability is greater than the threshold, withdraw
            global dataDir
            if probLessThanDepositWD > probLessThanDepositStay || probLessThanDepositWD==0.0
                #println("Endogenous Withdawal Agent ",agt.idx," at p(WD)=",probLessThanDepositWD, " where deposit was ",agt.deposit," and vault was ",mod.theBank.vault," and P(Stay)=",probLessThanDepositStay, " at tick=",t)
                withdraw(mod,agt)
                reportRow=DataFrame(key=mod.key,agent=agt.idx,withdraw=true,deposit=agt.deposit,
                tick=t,vault=mod.theBank.vault,wdProb=probLessThanDepositWD,stayProb=probLessThanDepositStay)
                CSV.write(dataDir*"/"*"bankRunEndogenous"*string(workerCore)*".csv",reportRow,writeheader=false,append=true)
                halt=false
            else
                #println("No Endogenous Withdawal Agent ",agt.idx," at p(WD)=",probLessThanDepositWD, " where deposit was ",agt.deposit," and vault was ",mod.theBank.vault," and P(Stay)=",probLessThanDepositStay, " at tick=",t)
                reportRow=DataFrame(key=mod.key,agent=agt.idx,withdraw=false,deposit=agt.deposit,
                tick=t,vault=mod.theBank.vault,wdProb=probLessThanDepositWD,stayProb=probLessThanDepositStay)
                CSV.write(dataDir*"/"*"bankRunEndogenous"*string(workerCore)*".csv",reportRow,writeheader=false,append=true)
            end

            if mod.theBank.vault<=0.0
                # if the bank is bankrupt, we need to stop the simulation
                runState=true
                break
            end
            #readline()   
        end
        #if  !halt && !runState
        #    println("Halting at tick ",t," with vault ",mod.theBank.vault)
        #end
    end
    return runState
end

# now the parallelization functions
    

function isReady(arg::Future)
    return isready(arg)
end
function isReady(arg::Symbol)
    return false
end
function isReady(arg::Nothing)
    return false
end

# Lock used by the master process to avoid row assignment races.
const rowLock = ReentrantLock()

# we need a function that calls the model generation function from other workers and fetches the result
function rowPull()
    global jointFrame
    lock(rowLock)
    try
        startIndex = findfirst(!, jointFrame.started)
        if startIndex === nothing
            return nothing
        end
        jointFrame[startIndex, :started] = true
        return (jointFrame[startIndex, :], startIndex)
    finally
        unlock(rowLock)
    end
end

function checkOff(currentIndex)
    global jointFrame
    # check off the row
    jointFrame[currentIndex,:completed]=true
end

function modelCall()
    # pull the first row of data
        proc=@spawnat 1 rowPull()
        while !isReady(proc)
            sleep(1)
        end
        # now we need to fetch the result
        results=fetch(proc)
        if !isnothing(results)
            startIndex=results[1]
            currentIndex=results[2]
            mod=modelGen(startIndex[:key],
                         startIndex[:seed1],
                         startIndex[:seed2],
                                1000,
                                .1,
                                startIndex[:network],
                                startIndex[:depositDist],
                                startIndex[:reserveRatio],
                                startIndex[:depositInsuranceQuantile],
                                startIndex[:withdrawRV])
                rMod=modelRun(mod)
                # write result immediately after modelRun so a worker death
                # between here and checkOff cannot lose the outcome
                resultRow=DataFrame(key=results[1][:key],result=rMod)
                CSV.write(dataDir*"/"*"bankRunResults"*string(workerCore)*".csv",resultRow,writeheader=false,append=true)
                proc2=@spawnat 1 checkOff(currentIndex)
                while !isReady(proc2)
                    sleep(1)
                end
                # now we need to fetch the result
                fetch(proc2)
        end

    return nothing
end

# we need a function to set a global variable for each worker indicating its core
function myCore(c)
    global workerCore
    workerCore=c
    #println("Worker Core is ",workerCore)
end
