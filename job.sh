#!/bin/sh                                                                                                               
#BATCH --mem-per-cpu 6g                                                                                                 
#SBATCH -t 02:00:00                                                                                                     
#SBATCH -o /home/moicoll/jupyter_cluster/jupyter_cluster_moi.out                                                        
#SBATCH -e /home/moicoll/jupyter_cluster/jupyter_cluster_moi.err                                                        
#SBATCH -J jupyter_cluster_moi                                                                                          
#SBATCH -A GenerationInterval                                                                                           

source ~/.bashrc
conda activate GenerationInterval
jupyter lab --no-browser --port=1234
