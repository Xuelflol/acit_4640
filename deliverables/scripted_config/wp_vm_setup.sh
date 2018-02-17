#!/bin/bash
#####################################
#
#  File: wp_vm_setup.sh
#  Description: this script will configure virtual networking and the host machine firewall
#  Author: Fan ZHANG @ BCIT
#  ID: A01012536
#
#####################################

###### Simplify Calls to VBoxManage.exe #####
vboxmanage () { VBoxManage.exe "$@"; }
# You will need to change the VM name to match one of your VM's
declare vm_name="WPVM1"
###### Store the Path to the script ######
# get the abosolute path of the current script 
declare script_path="$(readlink -f $0)"
# get the path of its enclosing directory use this to setup relative paths
declare script_dir=$(dirname "${script_path}")
##### Create VM #####
vboxmanage createvm --name ${vm_name} --register
###### Get the Directory of a VM #####
# Cludge to get the path of the directory where the vbox file is stored. 
# Used to create hard disk file in same directory as vbox file without using 
# absolute paths
# vboxmanage showvminfo displays line with the path to the config file -> grep "Config file returns it
declare vm_info="$(VBoxManage.exe showvminfo "${vm_name}")"
declare vm_conf_line="$(echo "${vm_info}" | grep "Config file")"
# Windows: the extended regex [[:alpha:]]:(\\[^\]+){1,}\\.+\.vbox matches everything that is a path 
# i.e. C:\ followed by anything not a \ and then repetitions of that ending in a filename with .vbox extension
declare vm_conf_file="$( echo "${vm_conf_line}" | grep -oE '[[:alpha:]]:(\\[^\]+){1,}\\.+\.vbox' )"
# strip leading text and trailing filename from config file line to leave directory of VM
declare vm_directory_win="$(echo ${vm_conf_file} | sed 's/Config file:\s\+// ; s/\\[^\]\+\.vbox$//')"
# Strip leading text from the config file line and convert from windows path to wsl linux path 
declare vm_directory_linux="$(echo ${vm_conf_file} | sed 's/Config file:\s\+// ; s/\([[:upper:]]\):/\/mnt\/\L\1/ ; s/\\/\//g')"
# Remove file part of path leaving directory
vm_directory_linux="$(dirname "$vm_directory_linux")"
# WSL commands will use the linux path, whereas Windows native commands (most
# importantly VBoxManage.exe) will use the windows style path.
echo "${vm_directory_linux}"
echo "${vm_directory_win}"
##### Create Virtual Hard Disk #####
declare size_in_mb="10240"
vboxmanage createhd --filename ${vm_directory_linux}/${vm_name}.vdi \
                    --size ${size_in_mb} -variant Standard		
##### Add Storage Controllers #####
declare ctrlr_name1="ide_controller"
declare ctrl_type1="ide"
declare ctrlr_name2="sata_controller"
declare ctrl_type2="sata"
vboxmanage storagectl ${vm_name} --name ${ctrlr_name1} --add ${ctrl_type1} --bootable on
vboxmanage storagectl ${vm_name} --name ${ctrlr_name2} --add ${ctrl_type2} --bootable on 
##### Attach an installation ISO #####
declare port_num=0
declare devic_num=0
declare iso_file_path="CentOS-7-x86_64-Minimal-1708.iso"
vboxmanage storageattach ${vm_name} \
            --storagectl ${ctrlr_name1} \
            --port ${port_num} \
            --device ${devic_num} \
            --type dvddrive \
            --medium ${iso_file_path}	
###### Attach a hard disk and specify that its an SSD ######
vboxmanage storageattach ${vm_name} \
            --storagectl ${ctrlr_name2} \
            --port 0 \
            --device 0 \
            --type hdd \
            --medium ${vm_directory_linux}/${vm_name}.vdi \
            --nonrotational on 
###### Configure a vm ######	
##The VM boots from its network card if no other boot option is successful.##
##The VM's MAC address matches the DHCP configuration on the PXE server modify the VM to use the MAC Address: 020000000001##
declare group_name="/"	
declare network_name="sys_net_prov"
vboxmanage modifyvm ${vm_name}\
            --groups "${group_name}"\
            --ostype "RedHat_64"\
            --cpus 1\
            --hwvirtex on\
            --nestedpaging on\
            --largepages on\
            --firmware bios\
            --nic1 natnetwork\
            --nat-network1 "${network_name}"\
            --cableconnected1 on\
            --audio none\
            --boot1 disk\
            --boot2 dvd\
            --boot3 net\
            --boot4 none\
            --memory "1280"
			--macaddress1 "020000000001"

####### It uses ssh to modify any required ownership and permissions on the server. Specifically the user that nginx runs as is nginx.
####### It uses scp to copy any required configuration files to the PXE server so they can be accessed during the kickstart process.


# scp ${script_dir}/kickstart/wp_ks.cfg pxe:/usr/share/nginx/html/
# scp -r ${script_dir}/setup pxe:/usr/share/nginx/html/
# ssh pxe 'sudo chown nginx:wheel /usr/share/nginx/html/wp_ks.cfg'
# ssh pxe 'chmod ugo+r /usr/share/nginx/html/wp_ks.cfg'
# ssh pxe 'chmod ugo+rx /usr/share/nginx/html/setup'
# ssh pxe 'chmod -R ugo+r /usr/share/nginx/html/setup/*'			
			
			
###### Start vm ######				
vboxmanage startvm ${vm_name} --type headless