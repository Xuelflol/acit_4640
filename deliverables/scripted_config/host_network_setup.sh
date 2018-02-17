#####################################
#
#  File: host_network_setup.sh
#  Description: this script will configure virtual networking and the host machine firewall
#  Author: Fan ZHANG @ BCIT
#  ID: A01012536
#
#####################################

###### Simplify Calls to VBoxManage.exe #####
vboxmanage () { VBoxManage.exe "$@"; }


##### Adding a NAT Network #####

#Network Type: NAT Network
#Network Name: sys_net_prov
#IP Address: 192.168.254.0/24
#VirtualBox DHCP: Off
#Gateway: 192.168.254.1
#Port Forwarding:
#External Port	Internal IP		Internal Port
##	50022		192.168.254.10		  22
##	50080		192.168.254.10		  80
##	50443		192.168.254.10		  443

declare network_name="sys_net_prov"
declare network_address="192.168.254.0"
declare cidr_bits="24"
declare global_ip=""
declare local_ip="192.168.254.10"

vboxmanage natnetwork add \
            --netname ${network_name} \
            --network ${network_address}/${cidr_bits} \
            --dhcp off
			

			
##1- VBoxManage natnetwork modify --netname sys_net_prov --port-forward-4 "ssh:tcp:[]:50022:[192.168.254.10]:22"		
declare rule_name1="ssh"
declare protocol1="tcp"
declare global_port1="50022"
declare local_port1="22"
			
vboxmanage natnetwork modify \
            --netname ${network_name} \
            --port-forward-4 "${rule_name1}:${protocol1}:[${global_ip}]:${global_port1}:[${local_ip}]:${local_port1}"
			
##2- VBoxManage natnetwork modify --netname sys_net_prov --port-forward-4 "http:tcp:[]:50080:[192.168.254.10]:80"		
declare rule_name2="http"
declare protocol2="tcp"
declare global_port2="50080"
declare local_port2="80"
			
vboxmanage natnetwork modify \
            --netname ${network_name} \
            --port-forward-4 "${rule_name2}:${protocol2}:[${global_ip}]:${global_port2}:[${local_ip}]:${local_port2}"

##3- VBoxManage natnetwork modify --netname sys_net_prov --port-forward-4 "https:tcp:[]:50443:[192.168.254.10]:443"		
declare rule_name3="https"
declare protocol3="tcp"
declare global_port3="50443"
declare local_port3="443"
			
vboxmanage natnetwork modify \
            --netname ${network_name} \
            --port-forward-4 "${rule_name3}:${protocol3}:[${global_ip}]:${global_port3}:[${local_ip}]:${local_port3}"


##Add a rule to forward port host IP port 50222 to PXE IP Port 22	
#Port Forwarding:	
#External Port	Internal IP		Internal Port
##	50222		192.168.254.5		  22

declare pxe_ip="192.168.254.5"	
declare rule_name4="pxe_ssh"
declare protocol4="tcp"
declare global_port4="50222"
declare pxe_port4="22"
			
vboxmanage natnetwork modify \
            --netname ${network_name} \
            --port-forward-4 "${rule_name4}:${protocol4}:[${global_ip}]:${global_port4}:[${pxe_ip}]:${pxe_port4}"

			

##List vbox NAT networks
vboxmanage list natnetworks

##Remove vbox NAT network
##vboxmanage natnetwork remove --netname ${network_name}


