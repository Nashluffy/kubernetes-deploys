#!/bin/bash
######################################################
#Purpose: Install k3s on all nodes in our cluster, along with a list of other administrative commands to execute
#Maintainer: Nash Luffman
#Email: nashluffman@gmail.com
#Phone: 919-943-6718
######################################################
#Declaration of masterNode
declare -A masterNode
masterNode['nash@192.168.4.32']='bm.uno'

######################################################
#Declaration of workerNodes
declare -A workerNodes
workerNodes['pi@192.168.4.35']='pi.uno'
workerNodes['mluffman@192.168.4.33']='bm.dos'
workerNodes['pi@192.168.4.36']='pi.dos'
#####################################################
#Declaration of commands to execute in master nodes
IFS=""
declare -a masterCommands

#The reason we wrap this in a command is so we have access to node names and can update on the fly
instantiateMasterCommands(){
    masterCommands+=('echo "#########################################"')
    masterCommands+=('echo "Starting to uninstall master servers"')
    masterCommands+=('echo -e "#########################################\n\n"')
    masterCommands+=('echo "Removing master server with name "'$1)
    masterCommands+=('/usr/local/bin/k3s-uninstall.sh')
}

#####################################################
#Declaration of commands to execute in worker nodes
IFS=""
declare -a workerCommands

instantiateWorkerCommands(){
    unset workerCommands
    workerCommands+=('echo "#########################################"')
    workerCommands+=('echo "Starting to uninstall worker agents"')
    workerCommands+=('echo "#########################################"')
    workerCommands+=('echo "Deleting worker node with name "'$1)
    workerCommands+=('/usr/local/bin/k3s-agent-uninstall.sh')
}

#####################################################
#Abstracting away the execution of commands allows us to change how we execute commands down the line; ie. rsync, ssh, ftp, etc...

executeCommands(){

    #Parse command line arguments
    sshString="$1"
    shift
    commands=("$@")

    #Iterate through all commands
    for command in "${commands[@]}"
    do
	#If we are on the computer running the script, we don't need to run commands in ssh
        if [[ mluffman\@$(hostname -I | awk '{print $1}') == ${sshString} ]]
        then
            eval "$command";
        else
            ssh "${sshString}" "${command}";
        fi
    done
}


#####################################################
#We run our master commands against all nodes listed at beginning of script

for master in ${!masterNode[@]}; do
    sshString=${master}
    nodeName=${masterNode[${master}]}
    instantiateMasterCommands $nodeName
    executeCommands ${sshString} ${masterCommands[@]}
    
    echo -e "Finished uninstalling k3s master server\n\n"
done;

#####################################################
#We run our worker commands against all nodes listed at beginning of script

for worker in ${!workerNodes[@]}; do
    sshString=${worker}
    nodeName=${workerNodes[${worker}]}
    instantiateWorkerCommands $nodeName
    executeCommands  ${sshString} ${workerCommands[@]}
    echo -e "\n\n"
done;

