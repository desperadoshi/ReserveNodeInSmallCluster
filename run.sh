node_name=${1}
idle_thres_step=2.5
ncpu=39
if [ "$node_name" = "" ]; then
  # The user does not specify a node
  node_usage=$(/usr/local/bin/SCM_Client | tail -n9 | sed -n "/node/p" | sed '/Not/d')
  node_usage_id=$(echo "$node_usage" | awk -F':' '{print $1}')
  node_usage_val=$(echo "$node_usage" | awk -F'=' '{print $2}' | tr -d %)
  n_node=$(echo "$node_usage_id" | wc -l)
  # < 2.5 means that all cpu are idle
  for j in $(seq 1 ${ncpu}); do
    # echo $j
    idle_thres=$(echo "${idle_thres_step} * ${j}" | bc)
    for i in $(seq 1 ${n_node}); do
      val=$(echo "${node_usage_val}" | sed -n "${i}p")
      if (( $(echo "$val < ${idle_thres}" | bc) )); then
        node_id=$(echo "${node_usage_id}" | sed -n "${i}p" | sed 's/\x1b\[[0-9;]*m//g')
        break 2
      fi
    done
  done
  if [ "$node_id" = "" ]; then
    echo "no node is idle!"
    exit 1
  fi
  node_name=${node_id}
else
  j=1
fi
echo $node_name
cpu_avail_init=$(echo "40-$j+1" | bc)
echo $cpu_avail_init
# Check the cpu usage of the node
cd $HOME/.cache/
occupy_shell_stop_request_fname=stop_occupy_shell
occupy_solver_stop_request_fname=stop_occupy
solver_pid_fname=mpirun_solver.pid
nohup mpirun -n ${cpu_avail_init} -host ${node_name} /home/jcshi/Softwares/solver &
echo $! > ${solver_pid_fname}
echo ${node_name}" running "${cpu_avail_init} >> ${solver_pid_fname}
echo $(date) >> ${solver_pid_fname}
#
while [ ! -f ${occupy_shell_stop_request_fname} ]; do
  node_usage=$(/usr/local/bin/SCM_Client | tail -n9 | sed -n "/${node_name}/p" | sed '/Not/d')
  node_usage_val=$(echo "$node_usage" | awk -F'=' '{print $2}' | tr -d %)
  # echo $node_usage
  cpu_avail=$(echo "${ncpu}-($node_usage_val/${idle_thres_step})/1" | bc)
  if (( $(echo "${cpu_avail} > ${cpu_avail_init}" | bc) )); then
    echo $cpu_avail
    cpu_avail_init=${cpu_avail}
    #
    if (( -f "solver_is_running" )); then
      touch ${occupy_solver_stop_request_fname}
      sleep 1m
    fi
    nohup mpirun -n ${cpu_avail} -host ${node_name} /home/jcshi/Softwares/solver &
    echo $! >> ${solver_pid_fname}
    echo ${node_name}" running "${cpu_avail} >> ${solver_pid_fname}
    echo $(date) >> ${solver_pid_fname}
  fi
  sleep 1m
done
touch ${occupy_solver_stop_request_fname}
rm ${solver_pid_fname}
rm ${occupy_shell_stop_request_fname}
rm nohup.out
cd -

