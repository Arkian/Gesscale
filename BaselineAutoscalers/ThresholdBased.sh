 #!/bin/bash

workspace=`pwd`
#workspace="$bin"
#bin="$bin/TMP/"


HostIP="10.188.71.209:8081"
KafkaBroker="10.188.71.209:9092"

ClusterIP="10.188.180.183:30081"
ClusterURL="http://10.188.180.183:30081"



Producer_JOB="$workspace/DataProducer-3Sink.jar --input  $workspace/Rides-2days.gz  --speed 10 --broker $KafkaBroker"

Consumer_JOB="$workspace/DataConsumer.jar --broker $KafkaBroker"


######################################################################################################
############### AutoScaling part ##############

echo -e "\n*******************************************************"
echo -e "***               Autoscaler program                ***"
echo -e "*******************************************************\n"


TMNumber=6

measureNum=1     
StartPara=2  #Initial parallelism of target operator
alpha=0
NewParallelism=0
MST_next=0
HasData=1

#THR-BASED
HighThreshold=50
LowThreshold=30
#THR-BASED

#Run resource manager 
. ./ResourceManager.sh 2 $StartPara


############### Running Flink program ##############
echo -e "Running the Data Producer and consumer in Flink..."

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
echo -e "MYSCRIPT:: Current Throughput and CPU Usage Monitoring..."

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

    echo -e "\nMYSCRIPT:: Monitoring the throughput and CPU Usage every 30 seconds..."
        while [ $THR_CHNG -eq 0 ]
            do
            echo -e "\nMYSCRIPT:: Periodic Monitoring..."
            sleep 30
            JobRunTime="$(curl -s -G $url | jq -r '.duration')"
            echo -e "\t Job Run Time: $JobRunTime ms"

 reconf=0 


 
 
###########Updating Throughput#######################
   
    MetricURLTask="$operatorURL/subtasks/metrics?get=iMap.numRecordsOutPerSecond"  
    CurrentThrpt="$(curl -s -G $MetricURLTask | jq -r '.[].sum')"
    echo -e "\t Target Operator Current Throughput: ${CurrentThrpt%.*} record/second"

   
    SourceID="$(curl -s -G $url | jq -r '.vertices[0].id')"
    SourceURL="$ClusterURL/jobs/$JobID/vertices/$SourceID"
    SourceThrUrl="$SourceURL/metrics?get=0.numRecordsOutPerSecond"  
    SourceThrpt="$(curl -s -G $SourceThrUrl | jq -r '.[].value')"
    InRate=${SourceThrpt%.*}
    echo -e "Debug::Source throughput (InRate): $InRate"
    

#######################################################
CPU_AVG=0
#############Threshold-based Scaling Decsion#########
 for j in $(eval echo "{0..$(($parallelism-1))}")
 do
     TM_ID="$(curl -s "$ClusterURL/taskmanagers/" | jq -r '.taskmanagers['$j'].id')"
     
#      #CPU Load
#       TM_CPULoadURL="$ClusterURL/taskmanagers/$TM_ID/metrics?get=Status.JVM.CPU.Load"
#       TM_Load="$(curl -s -G $TM_CPULoadURL | jq -r '.[].value')"
#       TM_CPULoad=${TM_Load%.*}
#       echo -e "\t TaskManager $j CPU Load: $TM_CPULoad"
     
     #CPU Usage
     TM_CPUUsageURL="$ClusterURL/taskmanagers/$TM_ID/metrics?get=System.CPU.Usage"
     TM_CPUtil="$(curl -s -G $TM_CPUUsageURL | jq -r '.[].value')"
     CPUUsage=${TM_CPUtil%.*}
     echo -e "\t TaskManager $j CPU Usage: $CPUUsage"
    
    CPU_AVG=$(($CPU_AVG+$CPUUsage))
done


#Calculate CPU average
CPU_AVG=$(($CPU_AVG / $parallelism))
echo -e "\t CPU Usage Average: $CPU_AVG"

#######Scaling up check

     
     if [ $CPU_AVG -gt $HighThreshold ]
     then
        echo -e "\t **************CPU Usage is HIGH (TM_$j).***************"
        if [ $parallelism -lt $TMNumber ]
        then
            NewParallelism=$(($parallelism+1))
            echo "NewParallelism: $NewParallelism"
            reconf=1
            
        fi
        
#######Scaling down check        
     elif [ $CPU_AVG -lt $LowThreshold ]
     then
        echo -e "\t *************CPU Usage is LOW (TM_$j).*****************"
        if [ $parallelism -gt 1 ]
        then
            NewParallelism=$(($parallelism-1))
            echo "NewParallelism: $NewParallelism"
            reconf=1
        fi
     else
        echo -e "\t *************CPU Usage is NORMAL (TM_$j).***************"
     fi


######################################################### 

        

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
            
            echo -e "\nMYSCRIPT:: Resuming Flink with new configuration..."
               
                #flink run -d -m $ClusterIP -s $SavepointPath  -n -p $NewParallelism -j $JOB
                flink run -d -m $ClusterIP -p $NewParallelism -j $Consumer_JOB

    
            THR_CHNG=1
        fi
###############################################################################
    done

done

flink cancel -m $ClusterIP $JobID
