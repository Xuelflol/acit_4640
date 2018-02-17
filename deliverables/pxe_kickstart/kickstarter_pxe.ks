#version=DEVEL
# System authorization information
auth --passalgo=sha512 --useshadow
# License agreement
eula --agreed
repo --name="epel" --baseurl=http://download.fedoraproject.org/pub/epel/$releasever/$basearch
# Use CDROM installation media
cdrom
# Use text mode install
text
# Firewall configuration
firewall --enabled --service=ssh
firstboot --disable
ignoredisk --only-use=sda
# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'
# System language
lang en_CA.UTF-8

# Network information
network  --bootproto=dhcp --device=link --ipv6=auto --activate
network  --bootproto=dhcp --hostname=base
# Reboot after installation
reboot
# Root password
rootpw --plaintext temp
# SELinux configuration
selinux --permissive
# System services
services --enabled="sshd,chronyd"
# Do not configure the X Window System
skipx
# System timezone
timezone America/Vancouver --isUtc
user --groups=wheel --name=admin --password=temp --gecos="admin"
# System bootloader configuration
bootloader --append="rhgb crashkernel=auto" --location=mbr --boot-drive=sda
autopart --type=lvm
# Partition clearing information
clearpart --all --initlabel --drives=sda

%post --logfile=/root/ks-post.log

#Update System
yum -y update

#Turn Down Swapiness for SSD disk
echo "vm.swappiness = 10" >> /etc/sysctl.conf

#Sudo Modifications
#Allow all wheel members to sudo all commands without a password by uncommenting line from /etc/sudoers
sed -i 's/^#\s*\(%wheel\s*ALL=(ALL)\s*NOPASSWD:\s*ALL\)/\1/' /etc/sudoers
#Enable sudo over ssh without a terminal
sed -i 's/^\(Defaults    requiretty\)/#\1/' /etc/sudoers

%end

%packages --excludedocs --nobase
@core
chrony
epel-release
kexec-tools
python

%end

%addon com_redhat_kdump --enable --reserve-mb='auto'

%end
