#!/bin/bash

######################################################
#Purpose: Install k3s on all nodes in our cluster, along with a list of other administrative commands to execute
#Maintainer: Nash Luffman
#Email: nashluffman@gmail.com
#Phone: 919-943-6718

######################################################
#Overriding echo command

echo(){
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    NC='\033[0m'
    if [ -z "$1" ]; then
        builtin echo -e \[+\] ${GREEN} "$1" ${NC}
    else
        builtin echo $1
    fi
}

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
    masterCommands+=('echo "Starting to install master servers"')
    masterCommands+=('echo -e "#########################################\n\n"')
    masterCommands+=('echo "Installing master server with name "'$1)
    masterCommands+=('sudo curl -sfL https://get.k3s.io | sh -s - --no-deploy servicelb --write-kubeconfig-mode 644 --node-name '"${1}")
}

#####################################################
#Declaration of commands to execute in worker nodes
IFS=""
declare -a workerCommands

instantiateWorkerCommands(){
    unset workerCommands
    workerCommands+=('echo "#########################################"')
    workerCommands+=('echo "Starting to install worker agents"')
    workerCommands+=('echo "#########################################"')
    workerCommands+=('echo "Installing worker node with name "'$1)
    workerCommands+=('curl -sfL https://get.k3s.io | K3S_NODE_NAME='${1}' K3S_URL=https://'${MASTER_IP}':6443 K3S_TOKEN='${K3S_TOKEN}' sh -')
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
    
    #These are post-server install commands.
    K3S_TOKEN=$(ssh "${sshString}" sudo cat /var/lib/rancher/k3s/server/node-token)
    ssh "${sshString}" sudo cat /etc/rancher/k3s/k3s.yaml > /home/nash/.kube/config
    MASTER_IP=$(ssh "${sshString}" hostname -I | awk '{print $1}')
    sudo sed -i 's/127.0.0.1/'${MASTER_IP}'/g' ~/.kube/config
    echo -e "Finished installing master server on node "${nodeName} "\n\n"
    echo ""
    echo
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

####################################################
#Any post-install commands
echo "Starting post-install commands shortly..."
sleep 10
workerString=$(kubectl get nodes | grep -E '<none>' | awk '{print $1}')
readarray -t workers <<<"$workerString"
for worker in ${workers[@]}; do
    kubectl label node ${worker} node-role.kubernetes.io/worker=worker 
done;
kubectl create namespace pihole
kubectl create namespace metallb-system
kubectl create namespace website
kubectl create namespace kubernetes-dashboard
kubectl create namespace trails
kubectl create secret generic web-password --from-literal=password=$PIHOLE_PASS -n pihole
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
kubectl create secret generic prod-route53-credentials-secret --from-literal=secret-access-key=${secretAccessKey}
kubectl apply -f ~/Code/kubernetes-deploys/ --recursive
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.15.1/cert-manager.yaml

#We force pihole to run on hardwired-bm node in my office 
nodeString=$(kubectl get nodes --no-headers | grep -v bm.uno |awk '{print $1}')
readarray -t nodes <<<"$nodeString"

podString=$(kubectl get pods -n pihole --no-headers| awk '{print $1}')
readarray -t pods <<<"$podString"

for node in ${nodes[@]}; do kubectl cordon $node; done
for pod in ${pods[@]}; do kubectl delete pod ${pod} -n pihole; done
for node in ${nodes[@]}; do kubectl uncordon $node; done

echo 'Install is complete. Do NOT forget to port forward the NodeIP on ingress service'

