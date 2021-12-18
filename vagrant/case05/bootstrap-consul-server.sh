#!/usr/bin/env bash

VMHOSTNAME=$1
CONSUL_CONFIG=$2
CONSUL_EXTRA_CONFIGS=$3
CONSUL_UI=$4
TIMEZONE="Australia/Melbourne"

echo -e "*** Start $VMHOSTNAME provisioning script"


# Update dependencies and upgrade the system
#if [ ! -f /var/log/0_upgrade_system ]
#then
#    echo -e "==> 0. Update dependencies and upgrade the system"
#    echo Updating linux
#    sudo apt-get update && sudo apt-get -y upgrade
#
#	touch /var/log/0_upgrade_system
#else
#    echo -e "==> 0. System upgrade is already done"
#fi

# Set the Server Timezone to Australia/Melbourne
if [ ! -f /var/log/1_setup_timezone ]
then
	echo -e "==> 1. Setting timezone"
	echo $TIMEZONE > /etc/timezone
	sudo dpkg-reconfigure -f noninteractive tzdata

	touch /var/log/1_setup_timezone
else
    echo -e "==> 1. Timezone is already setup"
fi

# Enable Ubuntu Firewall and allow SSH & Consul agent
if [ ! -f /var/log/2_setup_firewall ]
then
	echo -e "==> 2. Setup firewall"
	yes y | sudo ufw enable
	sudo ufw allow 22
	sudo ufw allow 8300/tcp
	sudo ufw allow 8301/tcp
	sudo ufw allow 8301/udp
	sudo ufw allow 8302/tcp
	sudo ufw allow 8302/udp
	sudo ufw allow 8400/tcp
	sudo ufw allow 8500/tcp
	sudo ufw allow 8600/tcp
	sudo ufw allow 53/udp
    sudo ufw status verbose

	touch /var/log/2_setup_firewall
else
    echo -e "==> 2. Firewall is already setup"
fi

# Add consul user
if [ ! -f /var/log/3_setup_consul_user ]
then
    echo -e "==> 3. Add consul user"
    sudo adduser --disabled-password --gecos "" consul

	touch /var/log/3_setup_consul_user
else
    echo -e "==> 3. Consul user is already added"
fi


# Install necessary packages
if [ ! -f /var/log/4_install_packages ]
then
    echo -e "==> 4. Install necessary packages"
    sudo apt-get install -y unzip

    touch /var/log/4_install_packages
else
    echo -e "==> 4. Packages are already installed"
fi

# Copy an upstart script to /etc/init so the Consul agent will be restarted if we restart the virtual machine.
if [ ! -f /var/log/5_copy_upstart_script ]
then
    echo -e "==> 5. Copy a Consul upstart script to /etc/init, so the Consul agent will be restarted if the virtual machine is restarted"
    sudo cp /vagrant/config/common-files/consul-upstart.conf /etc/init/consul.conf

    touch /var/log/5_copy_upstart_script
else
    echo -e "==> 5. The Consul upstart script is already copied"
fi


# Get the Consul Zip file and extract it.
if [ ! -f /var/log/6_install_consul_agent ]
then
    echo -e "==> 6. Get the Consul agent zip file and install it"
    sudo mkdir -p /tmp/consul
    cd /tmp/consul
    sudo wget https://releases.hashicorp.com/consul/0.6.4/consul_0.6.4_linux_amd64.zip -O consul.zip --quiet
    unzip consul.zip
    sudo chmod +x consul
    sudo mv consul /usr/bin/consul


    # Install Consul Web UI

    if [ $CONSUL_UI == 'Y' ]
    then
        echo -e "==> 6-1. Consul UI needs to be installed"
        sudo mkdir -p /tmp/web_ui
        cd /tmp/web_ui
        sudo wget https://releases.hashicorp.com/consul/0.6.4/consul_0.6.4_web_ui.zip -O web_ui.zip --quiet
        sudo unzip web_ui.zip
        sudo rm web_ui.zip
        sudo mkdir -p /opt/consul/web
        sudo mv /tmp/web_ui/* /opt/consul/web
        sudo rm -rf /tmp/web_ui
        # Set consul user to own /opt/consul/web
        sudo chown consul:consul -R /opt/consul/web
    else
        echo -e "==> 6-1. Consul UI does not need to be installed"
    fi

    touch /var/log/6_install_consul_agent
else
    echo -e "==> 6. Consul agent is already installed"
fi


# Make the Consul directory.
if [ ! -f /var/log/7_set_consul_configuration_directory ]
then
    echo -e "==> 7. Create the Consul configuration directory and consul log file"
    sudo mkdir /etc/consul.d
    sudo chmod a+w /etc/consul.d
    sudo mkdir -p /var/consul
    # Set consul user to own /var/consul directory
    sudo chown consul:consul /var/consul
    sudo chmod a+w /var/consul
    # Create empty file /var/log/consul.log
    sudo touch /var/log/consul.log
    sudo chmod 777 /var/log/consul.log

    touch /var/log/7_set_consul_configuration_directory
else
    echo -e "==> 7. Consul configuration directory is already created"
fi


# Copy the server configuration.
echo -e "==> 8. Copy the Consul configurations"
sudo cp $CONSUL_CONFIG /etc/consul.d/config.json
sudo cp $CONSUL_EXTRA_CONFIGS/* /etc/consul.d/
sudo chmod a+wrx $CONSUL_EXTRA_CONFIGS/*.*


# Start Consul agent
echo -e "==> 9. Start Consul agent"
sudo service consul restart