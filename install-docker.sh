#! /bin/bash

install_docker_ubuntu(){
        sudo apt-get update
        sudo apt-get install ca-certificates curl
        sudo install -m 0755 -d /etc/apt/keyrings
        sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update
        sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

install_docker_fedora(){
        sudo dnf -y install dnf-plugins-core
        sudo dnf-3 config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
        sudo dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        sudo systemctl enable --now docker
}

get_ip(){
	ip_a=$(hostname -I | awk '{print $1}')
        gateway=$(ip r | grep ^def | awk '{print $3 }' | head -n 1)
	while [ -z "$ip_a" ]; do
                read -p "ip: " ip_a
                read -p "gateway: " gateway
        done
        device_name=$(ip -o link show | grep -E 'enp|eth' | awk -F ':' '{print $2}' | head -n 1)
}


set_dns_ubuntu_24(){
        echo "network:
  version: 2
  renderer: networkd
  ethernets:
      $device_name:
         dhcp4: no
         addresses: [$ip_a/24]
         routes:
           - to: default
             via: $gateway
         nameservers:
            addresses:
               - 10.202.10.202" >  50-cloud-init.yaml
         sudo netplan apply

}

set_dns_ubuntu_18(){
         echo "network:
  version: 2
  renderer: networkd
  ethernets:
    $device_name:
      dhcp4: false
      dhcp6: false
      addresses: [$ip_a/24]
      routes:
      - to: default
        via:$gateway
      nameservers:
       addresses: 
         -10.202.10.202 " > 50-cloud-init.yaml
        sudo bash -c 'echo "network: {config: disabled}" > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg'
        sudo netplan apply
}

set_dns_ubuntu_20(){
        echo "network:
  version: 2
  renderer: networkd
  ethernets:
    $device_name:
      addresses: [$ip_a/24]
      gateway: $gateway
      nameservers:
        addresses:
        - 10.202.10.202 " >  00-install-config.yaml
        sudo netplan apply
}

name_os=$(grep ^NAME= /etc/os-release | cut -d'=' -f2 | tr -d '"')
version_os=$(grep ^VERSION_ID= /etc/os-release | cut -d'=' -f2 | tr -d '"')

if [ "$name_os" == "Ubuntu" ] || [ "$name_os" == "Debian"]; then
	get_ip
        install_docker_ubuntu
        if ! command -v docker-compose > /dev/null; then
        #if [ $(command -v docker compose) -eq 0 && $(command -v docker ce-cli ) -eq 0 && $(command -v docker ce) -eq 0 ]; then
                cd /etc/netplan/
                if [ $version_os == "24.04" ] ; then
					ls  50-cloud-init.yaml
					if [$? -eq 0 ]; then
						touch  50-cloud-init.yaml
					fi;
                	set_dns_ubuntu_24
                elif [ $version_os == "18.04" ] ; then
					ls  50-cloud-init.yaml
                     if [$? -eq 0 ]; then
                         touch  50-cloud-init.yaml
					 fi;
                     set_dns_ubuntu_18
                elif [ $version_os == "20.04" ] ; then
					ls  50-cloud-init.yaml
                    if [$? -eq 0 ]; then
                       touch  00-install-config.yaml
					fi;
                     set_dns_ubunut_20
                fi;
                install_docker_ubuntu
        fi;

elif [ $name_os == "Fedora" ]; then
	get_ip
        install_docker_fedora
         if ! command -v docker-compose > /dev/null; then
        #if [ $(command -v docker compose) -eq 0 && $(command -v docker ce-cli ) -eq 0 && $(command -v docker ce) -eq 0 ]; then
                cd /etc/sysconfig/network-scripts
				ls ifcfg-$device_name
				if [ $? -eq 0 ]; then
					touch ifcfg-$device_name
				fi;
                echo "DEVICE=$device_name
HWADDR=00:16:3e:65:de:88
BOOTPROTO=static
ONBOOT=yes
NM_CONTROLLED=no
IPADDR= [$ip_a]
NETMASK=255.255.255.0
GATEWAY=$gateway
DNS1=10.202.10.202" >  ifcfg-$device_name 
                sudo systemctl restart NetworkManager
        fi;
fi;
