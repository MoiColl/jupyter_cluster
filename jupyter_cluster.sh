#!/bin/bash

#1. Defining default variables
u="moicoll"
c=1234
l=1234
s="/home/moicoll/jupyter_cluster/job.sh"
w=10
k="empty"
error="empty"
out="empty"


#2. help function
help()
{
    echo "Usage: bash $0 [-u,-c,-l,-w,-s,-h]

  Command                     Explanation                         Default
  -------                     -----------                         -------
  -u, --user <string>         GenomDK user                        ${u}
  -c, --clusterport <int>     cluster port                        ${c}
  -l, --localport <int>       local port                          ${l}
  -w, --waitingtime <int>     waiting time for job status         ${w}
                              checking and shh tunnel connection
  -s, --jobpath <string>      path to the job to be submitted to  ${s}
                              slurm
  -h, --help                  prints this help message
  "
    exit 1
}

#3. parssing variables
while getopts "u:e:c:l:m:n:s:krh:" o; do
    case "${o}" in
        u)
            u=${OPTARG}
            ;;
        c)
            c=${OPTARG}
            ;;
        l)
            l=${OPTARG}
            ;;
        w)
            w=${OPTARG}
            ;;
        s)
            s=${OPTARG}
            ;;
        h)
            help
            ;;
        *)
            help
            ;;
    esac
done
shift $((OPTIND-1))


#1) Checking ports
printf "\n"
printf "1) Checking if the port ${l} is free to use\n"
echo   "-------------------------------------------"
#https://askubuntu.com/questions/447820/ssh-l-error-bind-address-already-in-use
p=`lsof -ti:${l} | wc -l`
if [ ${p} -gt 0 ];
then

	printf "   There are processes that are running on port ${l}. This script tries to open a ssh tunnel from this laptop to the cluster using this port.\n"
	printf "   You will need to kill them before proceding a command like this:\n"
	printf "\n      $ lsof -ti:${l} | xargs kill -9\n\n"
	while [ ! -z ${k} ] && [ ${k} != "Y" ] && [ ${k} != "n" ];
	do
		printf "   Do you want this script to kill the process? [Y]/n: "
		read k
	done;
	if [ -z ${k} ] || [ ${k} == "Y" ];
	then
		printf "   Killing the port!\n"
		lsof -ti:${l} | xargs kill -9
	else
		printf "   Good bye then!\n"
		exit
	fi
else
	printf "   No processes running on port ${l}\n"
fi

#2) Checking old scripts
printf "\n"
printf "2) Checking if there is already a jupyter cluster job\n"
echo   "-----------------------------------------------------"

jobname=`ssh ${u}@login.genome.au.dk 'egrep "#SBATCH -J" '${s}' | awk '\''{print $3}'\'''`
p=`ssh ${u}@login.genome.au.dk 'squeue -n '${jobname}' -u '${u}' -h | wc -l'`

if [ ${p} -gt 0 ];
then
	printf "   Found ${p} jobs with the same name ${jobname}...\n"
	ssh ${u}@login.genome.au.dk 'for job in `squeue -n '${jobname}' -u '${u}' -h | awk '\''{print $1}'\''`; do echo "      - Canceling job" ${job}; scancel ${job}; done';
else
	printf "   No old jobs have been found\n"
fi

#3) Submitting the job to the slurm queue
printf "\n"
printf "3) Submitting the job to the slurm queue\n"
echo   "----------------------------------------"
o=`ssh ${u}@login.genome.au.dk sbatch ${s}`
j=`echo ${o} | awk '{print $4}'`
echo "   Submitting the job ${s} with jobid: " ${j};

#Check if the job is in the slurm system queue (${p}) and has been allocated to any node (${n})
#	${n} : node id where the job is alocated when running
#   ${p} : variable that denotes if the job is still on the slurm queue system (either waiting or running) as 1 and cancelled if 0
n=`ssh ${u}@login.genome.au.dk squeue --noheader | awk '{if($1=='${j}' && $5 == "R"){print $8}}'`
p=`ssh ${u}@login.genome.au.dk squeue --noheader | awk '{if($1=='${j}'){print}}' | wc -l`
while [ "${n}" == "" ] && [ ${p} -eq 1 ];
do
	for x in `seq ${w} -1 0`; do printf "   No node has been assigned yet. Waiting ${w} seconds before checking... %2d\r" ${x}; sleep 1; done;
	printf "\n   Checking again...\n"
	n=`ssh ${u}@login.genome.au.dk squeue --noheader | awk '{if($1=='${j}' && $5 == "R"){print $8}}'`
	p=`ssh ${u}@login.genome.au.dk squeue --noheader | awk '{if($1=='${j}'){print}}' | wc -l`
done

#Check if the job has been cancelled
if [ ${p} -eq 0 ];
then
	echo "   Job has failed"
	#Let the user check the standard output

	while [ ! -z ${out} ] && [ ${out} != "Y" ] && [ ${out} != "n" ];
	do
		printf "      Do you want to see the standard output? [Y]/n: "
		read out
	done;
	if [ -z ${out} ] || [ ${out} == "Y" ];
	then
		outfile=`ssh ${u}@login.genome.au.dk 'egrep "#SBATCH -e" '${s}' | awk '\''{print $3}'\'''`
		echo ""
		echo "--------------------------- OUT ---------------------------"
		ssh ${u}@login.genome.au.dk 'cat '${errorfile}''
		echo "-----------------------------------------------------------"
		echo ""
	fi

	#Let the user check the standard error
	while [ ! -z ${error} ] && [ ${error} != "Y" ] && [ ${error} != "n" ];
	do
		printf "      Do you want to see the standard error? [Y]/n: "
		read error
	done;
	if [ -z ${error} ] || [ ${error} == "Y" ];
	then
		errorfile=`ssh ${u}@login.genome.au.dk 'egrep "#SBATCH -e" '${s}' | awk '\''{print $3}'\'''`
		echo ""
		echo "-------------------------- ERROR --------------------------"
		ssh ${u}@login.genome.au.dk 'cat '${errorfile}''
		echo "-----------------------------------------------------------"
		echo ""
	fi

#If the job is running...
else
	echo "   Job is running in node " ${n};
	#4) Open a shh tunnel to the cluster and open the browser
	printf "\n"
	printf "4) Open a shh tunnel to the cluster and open the browser\n"
	echo   "--------------------------------------------------------"

	echo "   Oppening the ssh tunnel to the cluster";
	ssh -L ${l}:${n}:${c} ${u}@login.genome.au.dk -N &
	for x in `seq ${w} -1 0`; do printf "   Waiting ${w} seconds before connecting... %2d\r" ${x}; sleep 1; done;
	printf "\n   Connecting to cluster and oppening the browser\n"
	open --new -a "Google Chrome" --args "https://localhost:${l}/"


	out="empty"
	while [ ! -z ${out} ] && [ ${out} != "Y" ] && [ ${out} != "n" ];
	do
		printf "      Do you want to see the standard output? [Y]/n: "
		read out
	done;
	if [ -z ${out} ] || [ ${out} == "Y" ];
	then
		outfile=`ssh ${u}@login.genome.au.dk 'egrep "#SBATCH -o" '${s}' | awk '\''{print $3}'\'''`
		echo ""
		echo "--------------------------- OUT ---------------------------"
		ssh ${u}@login.genome.au.dk 'tail -f '${outfile}''
		echo "-----------------------------------------------------------"
		echo ""
	fi
fi


