#!/bin/bash

# variables
apt_packages=("curl" "unzip" "jq")
awscli_latest_url="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
awscli_zip="/tmp/awscliv2.zip"
systemd_resolved="/etc/systemd/resolved.conf"
awsclie_exe="/usr/local/bin/aws"

# EC2 instance requires tags with the following keys
tag_key_environment="Environment"
tag_key_domain="InternalDomain"
tag_key_apptype="AppType"


# install missing packages
sudo updatedb
for apt_package in ${apt_packages[@]}
do
        $(locate -b \\$apt_package  1>/dev/null 2>&1)
        if [ $? -ne 0 ]; then
                missing_packages+="$apt_package "
        fi
done

if [ ! -z "$missing_packages" ]; then
        echo -n Installing $missing_packages...
        sudo apt update 1>/dev/null 2>&1
        sudo apt -y install $missing_packages 1>/dev/null 2>&1
        [ $? -eq 0 ] && echo done || echo error
fi

if [ ! -f "$awsclie_exe" ]; then
        echo -n Installing awscli...
        curl $awscli_latest_url -o $awscli_zip 1>/dev/null 2>&1
        unzip $awscli_zip -d /tmp/ 1>/dev/null 2>&1
        sudo /tmp/aws/install 1>/dev/null 2>&1
        [ $? -eq 0 ] && echo done || echo error
fi

# updating domains
instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
instance_ip=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4 | tr '.' '-')
tagged_domains=$(/usr/local/bin/aws ec2 describe-tags --filters "Name=resource-id,Values=$instance_id" "Name=key,Values=$tag_key_domain*" | jq -j '(.Tags[]|" ",.Value)')
default_domain=$(sudo awk '/^search/{ print $2}' /etc/resolv.conf)
if [ "$tagged_domains" != "null" ]; then
        echo -n Updating domains...
        $(sudo sed -i "s/^#Domains=.*$/Domains=$tagged_domains $default_domain/g;s/^Domains=.*$/Domains=$tagged_domains $default_domain/g" $systemd_resolved  1>/dev/null 2>&1 )
        if [ $? -eq 0 ]; then
                echo done
                echo -n Restarting systemd-resolved.service...
                $(sudo systemctl restart systemd-resolved.service 1>/dev/null 2>&1)
                [ $? -eq 0 ] && echo done || echo error
        else
                echo error
        fi
else
        echo "Could not find EC2 tags with key $tag_key_domain*"
fi

# updating hostname
tagged_type=$(/usr/local/bin/aws ec2 describe-tags --filters "Name=resource-id,Values=$instance_id" "Name=key,Values=$tag_key_apptype" | jq -r '.Tags[0].Value')
tagged_environment=$(/usr/local/bin/aws ec2 describe-tags --filters "Name=resource-id,Values=$instance_id" "Name=key,Values=$tag_key_environment" | jq -r '.Tags[0].Value')
if [ "$tagged_type" != "null" ]; then
        if [ "$tagged_environment" != "null" ] ; then
                echo -n Updating hostname...
                $(sudo hostnamectl set-hostname $tagged_type-$tagged_environment-ip-$instance_ip)
                [ $? -eq 0 ] && echo done || echo error
        else
                echo "Could not find EC2 tags with key $tag_key_environment"
        fi
else
        echo "Could not find EC2 tags with key $tag_key_apptype"
fi

# switch application configuration to desired environment
if [ "$tagged_environment" != "null" ] ; then
        echo -n Linking configuration to $tagged_environment environment...
        $(sudo ln -s /home/ubuntu /etc/$tagged_environment 1>/dev/null &2>/dev/null)
        [ $? -eq 0 ] && echo done || echo error
else
        echo "Could not find EC2 tags with key $tag_key_environment"
fi
