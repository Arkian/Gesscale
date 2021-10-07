 #!/bin/bash

workspace=`pwd`
#workspace="$bin"
#bin="$bin/TMP/"


HostIP="10.188.71.209:8081"
KafkaBroker="10.188.71.209:9092"

ClusterIP="10.188.180.183:30081"
ClusterURL="http://10.188.180.183:30081"


Producer_JOB="$workspace/DataProducer.jar --input  $workspace/Rides-2days.gz  --speed 10 --broker $KafkaBroker"

Consumer_JOB="$workspace/DataConsumer.jar --broker $KafkaBroker"


#####################################################
###Curve Fitting with TWO parameters
CurveFitter2P(){
Measurements=$(mktemp)
echo -e "$1\t$3\t$5" >> $Measurements
echo -e "$2\t$4\t$6" >> $Measurements
FittingValues=$(mktemp)
 
gnuplot -e "\
set fit errorvariables;\
set fit logfile '/dev/null';\
set fit quiet;\
f(x,y)=a*x - c*y;\
a=30;\
c=10;\
fit f(x,y) '$Measurements' using 1:2:3 via a, c;\
set print '$FittingValues';\
print a;\
print c;\
set print;" 

#Putting the fitting values into the variables
unset -v a c
for var in a c; do
  IFS= read -r "$var" || break
done < $FittingValues

alpha=$(echo "scale=3; $a/1" | bc -l)
gamma=$(printf "%.3f\n" $c)

rm ${Measurements}
rm ${FittingValues}
}
#############################################################  

#####################################################
###Curve Fitting with THREE parameters
CurveFitter3P(){
Measurements=$(mktemp)
echo -e "$1\t$4\t$7" >> $Measurements
echo -e "$2\t$5\t$8" >> $Measurements
echo -e "$3\t$6\t$9" >> $Measurements
FittingValues=$(mktemp)

gnuplot -e "\
set fit errorvariables;\
set fit logfile '/dev/null';\
set fit quiet;\
f(x,y)=a*x**b - c*y;\
a=30;\
b=0.85;\
c=10;\
fit f(x,y) '$Measurements' using 1:2:3 via a, b, c;\
set print '$FittingValues';\
print a;\
print b;\
print c;\
set print;" 

#Putting the fitting values into the variables
unset -v a b c
for var in a b c; do
  IFS= read -r "$var" || break
done < $FittingValues

alpha=$(echo "scale=3; $a/1" | bc -l)
#beta_round=$(echo "scale=3; $beta/1" | bc -l)
beta=$(printf "%.3f\n" $b)
#gamma=$(echo "scale=3; $c/1" | bc -l)
gamma=$(printf "%.3f\n" $c)

rm ${Measurements}
rm ${FittingValues}
}

######################################################################################################
############### AutoScaling part ##############

echo -e "\n*******************************************************"
echo -e "***               Autoscaler program                ***"
echo -e "*******************************************************\n"

#echo -e "MYSCRIPT:: Configuring Flink and starting Task Managers...\n"

#Low Throughput threshold
LowTrptTrsld=30

TMNumber=6   #Number of available nodes
measureNum=1     
StartPara=2  #Initial parallelism of target operator
alpha=0
NewParallelism=0
MST_next=0
HasData=1

#Run resource manager and get current NDmax
. ./ResourceManager.sh 2 $StartPara
ND_MAX=${ND_MAX%"ms"}
NDmax=$ND_MAX


############### Running Flink program ##############
echo -e "MYSCRIPT:: Running the Data Producer and consumer in Flink..."

#First run consumer job on the cluster because takes time
flink run -d -m $ClusterIP -p $StartPara -j $Consumer_JOB
#Then run producer jpb on the host
flink run -d -m $HostIP -p 1 -j $Producer_JOB

while [ $HasData -eq 1 ]
    do
############# Monitoring Throughput ############
    echo -e "\n*******************************************************"
    echo -e "\nMYSCRIPT:: Warming up for 300 seconds... \n"
    sleep 300
#############
echo -e "MYSCRIPT:: Current Throughput and Back Pressure Monitoring..."

    echo -e "MYSCRIPT:: Details about the job:"

    JobID="$(curl -s -G $ClusterURL/jobs |jq -r ".jobs[0].id")"
    url="$ClusterURL/jobs/$JobID"
    echo -e "\t Job ID: $JobID"

    operatorID="$(curl -s -G $url | jq -r '.vertices[1].id')"
    echo -e "\t Target Operator ID: $operatorID"

    operatorName="$(curl -s -G $url | jq -r '.vertices[1].name')"
    echo -e "\t Target Operator Name: $operatorName"

    operatorURL="$ClusterURL/jobs/$JobID/vertices/$operatorID"
    parallelism="$(curl -s -G $url | jq -r '.vertices[1].parallelism')"
    echo -e "\t Target Operator Parallelism: $parallelism"
#################
    THR_CHNG=0    

    echo -e "\nMYSCRIPT:: Monitoring the throughput and back pressure every 1 minute..."
        while [ $THR_CHNG -eq 0 ]
            do
            echo -e "\nMYSCRIPT:: Periodic Monitoring..."
            sleep 60
            JobRunTime="$(curl -s -G $url | jq -r '.duration')"
            echo -e "\t Job Run Time: $JobRunTime ms"

 reconf=0 

#Back pressure of Source
SourceID="$(curl -s -G $url | jq -r '.vertices[0].id')"
SourceURL="$ClusterURL/jobs/$JobID/vertices/$SourceID"
SourcePressureURL="$ClusterURL/jobs/$JobID/vertices/$SourceID/backpressure"     #**NEED TO BE REVIEWED**#
SourcePressureRatio="$(curl -s -G $SourcePressureURL | jq -r '.subtasks[0].ratio')"

if [ "$SourcePressureRatio" == "null" ]
then
SourcePressureRatio=0
fi
echo -e "\t Source BackPressure Ratio: $SourcePressureRatio"
Ratio=$(echo "$SourcePressureRatio * 100" | bc -l)

#Check if dataset is not finished yet then check backpressure and throughpout
SourceThrUrl="$SourceURL/metrics?get=0.numRecordsOutPerSecond"  
SourceThrpt="$(curl -s -G $SourceThrUrl | jq -r '.[].value')"
InRate=${SourceThrpt%.*}
#TODO: It Must not be equal to "null" not zero, but it's not a major
if [ $InRate -eq 0 ]
then
    HasData=0

## First check back pressure if it is not high then check throughput.
elif [ ${Ratio%.*} -le 50 ]
then
    echo -e "\t Back pressure level is NOT HIGH."
    HasData=1
############Begin of Throughput Monitoring ##############
    MetricURLTask="$operatorURL/subtasks/metrics?get=iMap.numRecordsOutPerSecond"  
    CurrentThrpt="$(curl -s -G $MetricURLTask | jq -r '.[].sum')"
    echo -e "\t Target Operator Current Throughput: ${CurrentThrpt%.*} record/second" #sum(iMap.NumberofRecordsOutPerSecond)

    SourceThrUrl="$SourceURL/metrics?get=0.numRecordsOutPerSecond"  
    SourceThrpt="$(curl -s -G $SourceThrUrl | jq -r '.[].value')"
    InRate=${SourceThrpt%.*}

#### If measurement=2 means we had one value for Maximum throughput from first measurement so now we can use the simplest model (alpha=?, beta=1, gamma=0)
    if [ $measureNum -eq 2 ]
    then
	echo "###Measurement is 2"

        CurrentThrptInt=${CurrentThrpt%.*}
        MST_current=$(($parallelism * $alpha))       
        ThrDiffer=$(( $MST_current - $CurrentThrptInt ))
        ThrDiffPercent=$((100 * $ThrDiffer / $MST_current))
        
        if [ $ThrDiffPercent -gt $LowTrptTrsld ] && [ $parallelism -gt 2 ]
            then
            echo -e "\n************************************************************************************************"
            echo "*  Warning :: Current throughput of the operator is $ThrDiffPercent percent less than maximum throughput.   *"
            echo "************************************************************************************************" 
            reconf=1
            NewParallelism=$((($CurrentThrptInt / $alpha) + ($CurrentThrptInt % $alpha > 0))) #Rounded to up
            MST_next=$(($NewParallelism * $alpha))
        fi
            
        if [ $NewParallelism -eq $parallelism ]
        then
            reconf=0
            echo "***Reconfiguration ignored, as the new parallelism is the same.***"
        else
            echo "alpha=$alpha"
            echo "CurrentThrpt=$CurrentThrptInt"
            echo "MST_Current=$MST_current"
            echo "Current Para: $parallelism"
            echo "NewParallelism: $NewParallelism"
            echo "MST_next=$MST_next"
        fi
    fi
###########################
#### If measurement=3 means we had another value for Maximum throughput from second measurement so now we can use the simplest model (alpha=?, beta=1, gamma=?)

    if [ $measureNum -eq 3 ]
    then
	echo "###Measurement is 3"

	. ./ResourceManager.sh 0 $parallelism
	ND_MAX=${ND_MAX%"ms"}
	NDmax_current_n=$ND_MAX        

        CurrentThrptInt=${CurrentThrpt%.*}
        MST_current=$(echo $alpha*$parallelism- $gamma*$NDmax_current_n | bc -l)
        MST_current=${MST_current%.*} 
        ThrDiffer=$(( $MST_current - $CurrentThrptInt ))
        ThrDiffPercent=$((100 * $ThrDiffer / $MST_current))
        
        n_next=$parallelism
        MST_next=$MST_current
        n_old=$n_next
        MST_old=$MST_next
        while [ $ThrDiffPercent -gt $LowTrptTrsld ] && [ $n_next -gt 2 ] && [ $MST_next -gt $CurrentThrptInt ]  
        do
            echo -e "\n************************************************************************************************"
            echo "*  Warning :: Current throughput of the operator is $ThrDiffPercent percent less than maximum throughput.   *"
            echo "************************************************************************************************" 
            
            n_old=$n_next
            MST_old=$MST_next
            
            n_next=$(($n_next - 1))

            . ./ResourceManager.sh 0 $n_next
            ND_MAX=${ND_MAX%"ms"}
            NDmax_next_n=$ND_MAX

            MST_next=$(echo $alpha*$n_next- $gamma*$NDmax_next_n | bc -l)
            MST_next=${MST_next%.*}
            ThrDiffer=$(( $MST_next - $CurrentThrptInt ))
            ThrDiffPercent=$((100 * $ThrDiffer / $MST_next))
            reconf=1
        done
        
            if [ $ThrDiffPercent -lt 0 ]
            then
                n_next=$n_old
                MST_next=$MST_old
            fi
        
        if [ $n_next -eq $parallelism ]
        then
            reconf=0
            echo "***Reconfiguration ignored, as the new parallelism is the same.***"
        else
            NewParallelism=$n_next
            echo "alpha=$alpha"
            echo "gamma=$gamma"
            echo "CurrentThrptInt=$CurrentThrptInt"
            echo "MST_Current=$MST_current"
            echo "MST_next=$MST_next"
            echo "NewParallelism: $NewParallelism"         
        fi
        
    fi  
##################################
#### If measurement=4 means we had another value for Maximum throughput from third measurement so now we can use the simplest model (alpha=?, beta=?, gamma=?)

    if [ $measureNum -ge 4 ]
    then 
	echo "###Measurement is 4+"
             
	. ./ResourceManager.sh 0 $parallelism
	ND_MAX=${ND_MAX%"ms"}
	NDmax_current_n=$ND_MAX        
                            
        CurrentThrptInt=${CurrentThrpt%.*}
        nPowBeta=$(echo "scale=3; e($beta*l($parallelism))" | bc -l)
        MST_current=$(echo $alpha*$nPowBeta- $gamma*$NDmax_current_n | bc -l)
        MST_current=${MST_current%.*}    
        
        ThrDiffer=$(( $MST_current - $CurrentThrptInt ))
        ThrDiffPercent=$((100 * $ThrDiffer / $MST_current))
            
        n_next=$parallelism
        MST_next=$MST_current
        while [ $ThrDiffPercent -gt $LowTrptTrsld ] && [ $n_next -gt 2 ] && [ $MST_next -gt $CurrentThrptInt ]  
        do
            echo -e "\n************************************************************************************************"
            echo "*  Warning :: Current throughput of the operator is $ThrDiffPercent percent less than maximum throughput.   *"
            echo "************************************************************************************************" 
            
            n_old=$n_next
            MST_old=$MST_next
            
            n_next=$(($n_next - 1))

            . ./ResourceManager.sh 0 $n_next
            ND_MAX=${ND_MAX%"ms"}
            NDmax_next_n=$ND_MAX

            nPowBeta=$(echo "scale=3; e($beta*l($n_next))" | bc -l)
            MST_next=$(echo $alpha*$nPowBeta- $gamma*$NDmax_next_n | bc -l)
            MST_next=${MST_next%.*}
            
            ThrDiffer=$(( $MST_next - $CurrentThrptInt ))
            ThrDiffPercent=$((100 * $ThrDiffer / $MST_next))
            
            reconf=1
        done
        
        if [ $ThrDiffPercent -lt 0 ]
        then
            n_next=$n_old
            MST_next=$MST_old
        fi
        
        if [ $n_next -eq $parallelism ]
        then
            reconf=0
            echo "***Reconfiguration ignored, as the new parallelism is the same.***"
        else
            NewParallelism=$n_next
            echo "alpha=$alpha"
            echo "beta=$beta"
            echo "gamma=$gamma"
            echo "CurrentThrptInt=$CurrentThrptInt"
            echo "MST_Current=$MST_current"
            echo "MST_next=$MST_next"
            echo "NewParallelism: $NewParallelism"  
        fi
          
    fi             
#############End of Throughput Monitoring ###############

else #if the back pressure is HIGH then add one para and reconfigure Flink
    HasData=1
    echo -e "\n***************************************************************"
    echo "*     Warning :: Back Pressure Level of Source is HIGH!!      *"
    echo "***************************************************************"

 #adding a delay for doing reconfiguration after observing backpressure
    echo "Waiting to check again the backpressure after 1 minutes..."
    sleep 60
    #Back pressure of Source
    SourcePressureURL="$ClusterURL/jobs/$JobID/vertices/$SourceID/backpressure"     #**NEED TO BE REVIEWED**#
    SourcePressureRatio="$(curl -s -G $SourcePressureURL | jq -r '.subtasks[0].ratio')"
    echo -e "\t Source BackPressure Ratio: $SourcePressureRatio"
    Ratio=$(echo "$SourcePressureRatio * 100" | bc -l)
    if [ ${Ratio%.*} -gt 50 ]
    then
        echo "Backpressure still is high and the system needs a reconfiguration..."
        
        MetricURLTask="$operatorURL/subtasks/metrics?get=iMap.numRecordsOutPerSecond"  
        CurrentThrpt="$(curl -s -G $MetricURLTask | jq -r '.[].sum')"
        echo -e "\t Target Operator Current Throughput: ${CurrentThrpt%.*} record/second" 

        SourceThrUrl="$SourceURL/metrics?get=0.numRecordsOutPerSecond"  
        SourceThrpt="$(curl -s -G $SourceThrUrl | jq -r '.[].value')"
        InRate=${SourceThrpt%.*}
        
        echo -e "\t Current Input rate: $InRate record/second" 
        ####   
        
        reconf=1

#### If measurement=1 means we have to use simplest model (alpha=?, beta=1, gamma=0)
                if [ $measureNum -eq 1 ]
                then
                    echo "###One Measurement:"
                    InputRate=$InRate
                    #Since we have back pressure, maximum throughput is equal to current throughput
                    MST_1=${CurrentThrpt%.*}
                    #n=Number of parallelism of target operator
                    n_1=$parallelism
                
                    . ./ResourceManager.sh 0 $n_1
                    ND_MAX=${ND_MAX%"ms"}
                    NDmax1=$ND_MAX

                    alpha=$(($MST_1/$n_1))
                    #n_next=$((($InputRate / $alpha) + ($InputRate % $alpha > 0))) #Rounded to up
                    ###We Have to only add one new replica (unknown workload rate problem)
                    if [ $n_1 -eq $TMNumber ]
                    then
                        n_next=$n_1
                        echo "Number of replicas can not be more!"
                        reconf=0
                    else
                        n_next=$(($n_1+1))
                    fi
                    
                    MST_next=$(($alpha * $n_next))
                    
                    echo "alpha=$alpha"
                    echo "InputRate: $InputRate"
                    echo "NewParallelism: $n_next"
                    echo "MST_Next: $MST_next"
                    NewParallelism=$n_next
                    measureNum=$(($measureNum+1))

                    . ./ResourceManager.sh 0 $NewParallelism
                    ND_MAX=${ND_MAX%"ms"}
                    NDmax_n_next=$ND_MAX
                
#### If measurement=2 means we can use better model (alpha=?, beta=1, gamma=?)
                elif [ $measureNum -eq 2 ]
                then                 
                    echo "#######Two Measurements:"
                    InputRate=$InRate
                    #Since we have back pressure, maximum throughput is equal to current throughput
                    MST_2=${CurrentThrpt%.*}   
                    #n=Number of parallelism of target operator
                    n_2=$parallelism

                    . ./ResourceManager.sh 0 $n_2
                    ND_MAX=${ND_MAX%"ms"}
                    NDmax2=$ND_MAX

                    MST_next=0
                    n_next=$parallelism
                     
                    

                    ###We Have to only add one new replica (unknown workload rate problem)
                    if [ $n_2 -eq $TMNumber ]
                    then
                        n_next=$n_2
                        echo "Number of replicas can not be more!"
                        reconf=0
                    else
                        n_next=$(($n_2+1))
                        
                        . ./ResourceManager.sh 0 $n_next
                        ND_MAX=${ND_MAX%"ms"}
                        NDmax_n_next=$ND_MAX
                        
                        if [ $n_1 -eq $n_2 ]
                        then
                            echo "The Parallelism is the same with the one for last MST."
                            alpha=$(($MST_2/$n_2))
                            echo "alpha=$alpha"
                            MST_next=$(($alpha * $n_next))
                            MST_next=${MST_next%.*} 
                            
                        else
                            CurveFitter2P $n_1 $n_2 $NDmax1 $NDmax2 $MST_1 $MST_2
                            echo "alpha=$alpha"
                            echo "gamma=$gamma"
                            MST_next=$(echo $alpha*$n_next- $gamma*$NDmax_n_next | bc -l)
                            MST_next=${MST_next%.*} 
			    measureNum=$(($measureNum+1))
                            
                        fi
                        
                        echo "InputRate: $InputRate"
                        echo "NewParallelism: $n_next"
                        echo "MST_Next: $MST_next"
                        echo "ND_Next: $NDmax_n_next"
                        NewParallelism=$n_next
                    fi

#### If measurement=3 means we can use compelete model (alpha=?, beta=?, gamma=?)
                elif [ $measureNum -ge 3 ]
                then                  
                    echo "#######Three Measurements:"
                    InputRate=$InRate
                    #Since we have back pressure, maximum throughput is equal to current throughput
                    MST_3=${CurrentThrpt%.*}   
                    #n=Number of parallelism of target operator
                    n_3=$parallelism

                    . ./ResourceManager.sh 0 $n_3
                    ND_MAX=${ND_MAX%"ms"}
                    NDmax3=$ND_MAX

                    MST_next=0
                    n_next=$parallelism

                    ###We Have to only add one new replica (unknown workload rate problem)
                    if [ $n_3 -eq $TMNumber ]
                    then
                        n_next=$n_3
                        echo "Number of replicas can not be more!"
                        reconf=0
                    else
                        n_next=$(($n_3+1))
                    
                        . ./ResourceManager.sh 0 $n_next
                        ND_MAX=${ND_MAX%"ms"}
                        NDmax_n_next=$ND_MAX
                        
                        if [ $n_3 -eq $n_1 ]
                        then
                            echo "The Parallelism is the same with the previous ones!"
                            CurveFitter2P $n_2 $n_3 $NDmax2 $NDmax3 $MST_2 $MST_3
                            echo "alpha=$alpha"
                            echo "gamma=$gamma"
                            MST_next=$(echo $alpha*$n_next- $gamma*$NDmax_n_next | bc -l)
                            MST_next=${MST_next%.*} 
                            
                        elif [ $n_3 -eq $n_2 ]
                        then
                            echo "The Parallelism is the same with the previous ones!"
                            CurveFitter2P $n_1 $n_3 $NDmax1 $NDmax3 $MST_1 $MST_3
                            echo "alpha=$alpha"
                            echo "gamma=$gamma"
                            MST_next=$(echo $alpha*$n_next- $gamma*$NDmax_n_next | bc -l)
                            MST_next=${MST_next%.*} 
  
                        else
                        
                            CurveFitter3P $n_1 $n_2 $n_3 $NDmax1 $NDmax2 $NDmax3 $MST_1 $MST_2 $MST_3
                            echo "alpha=$alpha"
                            echo "beta=$beta"
                            echo "gamma=$gamma"
                            nPowBeta=$(echo "scale=3; e($beta*l($n_next))" | bc -l)
                            MST_next=$(echo $alpha*$nPowBeta- $gamma*$NDmax_n_next | bc -l)
                            MST_next=${MST_next%.*} 
                            
                            measureNum=$(($measureNum+1))

                        fi

                        echo "InputRate: $InputRate"
                        echo "NewParallelism: $n_next"
                        echo "MST_Next: $MST_next"   
                        echo "ND_Next: $NDmax_n_next"
                        NewParallelism=$n_next  
                        
                    fi
                fi
        fi
#################################################

MST_current=${CurrentThrpt%.*}
 fi            

###Starting Reconfiguration based on the parameters achieved by the model
        if [ $reconf -eq 1 ]
        then
            echo -e "MYSCRIPT:: Stopping Flink for Reconfiguration...\n"
                

# 	###Start Savepointing and Canceling job###
# 		ChekpointNum=0
# 		SavepointPath="null"
# 
# 		while [ $ChekpointNum -eq 0 ]
# 		do
# 		   sleep 5
# 		   ChekpointPath="$(curl -s -G $url/checkpoints |jq -r ".latest.completed.external_path")"
# 		   echo -e "\nMYSCRIPT:: Last completed Checkpoint Path: $ChekpointPath"
# 		   ChekpointNum="$(curl -s -G $url/checkpoints |jq -r ".counts.completed")"
# 		done
# 		
# 		flink savepoint -m $ClusterIP $JobID
# 		
#                 echo -e "\nMYSCRIPT:: Waiting for savepoint path..."
# 		while [ "$SavepointPath" == "null" ]
# 		do
# 		   sleep 5
# 		   SavepointPath="$(curl -s -G $url/checkpoints |jq -r ".latest.savepoint.external_path")"
# 		   echo -e "\nMYSCRIPT:: Last completed Savepoint Path: $SavepointPath"
# 		done
# 		
# 		flink cancel -m $ClusterIP $JobID
# 		sleep 10
# 	###End Savepointing and Canceling job###

 		flink cancel -m $ClusterIP $JobID
 		sleep 10

            echo -e "\nMYSCRIPT:: Rescaling number of TaskManagers..."
            . ./ResourceManager.sh 1 $parallelism $NewParallelism
            ND_MAX=${ND_MAX%"ms"}

            echo -e "\nMYSCRIPT:: Resuming Flink with new configuration..."
               
                #flink run -d -m $ClusterIP -s $SavepointPath  -n -p $NewParallelism -j $JOB
                flink run -d -m $ClusterIP -p $NewParallelism -j $Consumer_JOB
    
            THR_CHNG=1
        fi
###############################################################################
    done

done



flink cancel -m $ClusterIP $JobID
