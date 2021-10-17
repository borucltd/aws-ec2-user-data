# AWS EC2 user data
EC2 user data which reconfigures systemd-resolver to use private hosted zone(s) and sets hostname.

# Dependencies:
1. There should be private Hosted Zone attached to the VPC for EC2
2. EC2 needs an IAM profile with Read-only access to EC2 and Route53 services
3. EC2 needs the following tags (keys):

      * Environment - example values: sit, preprod, prod
      
      * AppType - example values: web, database, proxy 
      
      * InternalDomain - example values: internal.mycompany.com. You can have few domains InternalDomain1, InternalDomain2...
   
      
# Example:

For EC2 instance with the following tags:

| KEY            | VALUE                  |
|----------------|------------------------|
| Environment    | prod                   |
| AppType        | web                    |
| InternalDomain | internal.mycompany.com |
      
The following configuration is set (this is default VPC):

**hostname:**

web-prod-ip-172-31-40-68



**tail -3 /etc/resolv.conf:**

nameserver 127.0.0.53

options edns0

search internal.mycompany.com ap-southeast-2.compute.internal



**systemd-resolve --status:**

Global

DNS Domain: 

            internal.mycompany.com

            ap-southeast-2.compute.internal
            
            

