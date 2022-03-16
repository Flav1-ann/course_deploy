# course_deploy

### 1. Containerizing the application with Docker

##### Creating the DockerFile

``` dockerfile
FROM openjdk:15-jdk-alpine


LABEL MAINTENER="Flavien ANNAIX"


RUN apk update && \
    apk upgrade && \
    apk add git &&\
    apk add maven &&\
    apk add bash

RUN git clone https://github.com/Flav1-ann/course /course

WORKDIR /course

RUN mvn clean package -DskipTests=true

RUN cp target/*.jar app.jar

#RUN addgroup -S spring && adduser -S spring -G spring

EXPOSE 80

#USER spring:spring

ENTRYPOINT ["java","-jar","app.jar"]
```

##### Creating the docker image and hosting it on the docker hub

1. Login to docker hub from host

   > docker login

2. Build Docker image with tag name shop-crm-server

   > docker build . -t course

3. Tag the image in order to push on docker hub 

   > docker tag course:latest flav1ann/course

4. Push image to docker hub

   > docker push flav1ann/course



### 2. Create docker compose file to add a MySQL database container

```dockerfile
version: '3.4'
services:
  server:
    image: flav1ann/course # use image from docker hub
    restart: always     # restart if failure at runtime
    depends_on:
      - db              # indicate that the server depends on our database defined as db
    network_mode: host  # indicate that the server should be exposed to the host network 

  db:
    image: mysql        # this service uses the mysql docker image
    command: --default-authentication-plugin=mysql_native_password # use the native password generator to define a password
    restart: always     # restart if failure at runtime
    cap_add:
      - SYS_NICE        # CAP_SYS_NICE handle error silently
    environment:        # environment variable for the MySQL server
      - MYSQL_USER=${MYSQL_USER} 
      - MYSQL_PASSWORD=${MYSQL_PASSWORD}
      - MYSQL_DATABASE=${MYSQL_DATABASE}
      - MYSQL_ALLOW_EMPTY_PASSWORD=no
    ports:              # indicate that the port should be exposed to the host. This allows the server to acces the database.
      - 3306:3306
```



### 3. Automating creation of the runtime environment for our application with Ansible

```
+ ansible.cfg			#Configuration of ansible
+ secret.ini 			#aws credentials to work with aws services
+ docker_usr_config.sh 	#Add user to docker group on ubuntu 20.04LTS
+ playbook.yml 			#Ansible playbook to create the runtime environment of our app
+ docker-compose.yml 	#Docker compose file run by Ansible
+ private_settings.yml  #Environment variables used by the playbook
+ hosts.ini 			#Created on runtime by terraform EC2 Module to define the EC2
						#instance public ip and used by ansible to create the runtime 
						#environment.
```



### 4. Deployment on AWS cloud with terraform 


We need to init a terraform project before being able to deploy to aws cloud.

> cd app/
>
> terraform init

To deploy to aws, we use this command:

> terraform validate	  #Validate configuration syntax
>
> terraform plan			#Create execution plan
>
> terraform apply		  #Execute plan 

### 5. Quick look up to our terraform EC2 configuration


> Changer les variables private_key_path,secret_path,main_dir de ce fichier terraform.tvars dans le dossier /app
> Le nom du .perm doit etre le meme que l'auteur


````
# Create an EC2 instance
resource "aws_instance" "ec2" {
  ami                    = data.aws_ami.ami-ubuntu-bionic.id
  instance_type          = var.instance_type
  security_groups        = ["${var.sg_name}"]
  availability_zone      = var.availability_zone
  key_name               = "${var.author_name}-kp"

  tags = {
    Name : "ec2-${var.author_name}"
  }
  # Get some information about this container (static ip address, aws instance and availability zone )
  provisioner "local-exec" {
    command = "echo IP : ${var.public_ip}, ID: ${aws_instance.ec2.id}, Zone: ${aws_instance.ec2.availability_zone} >> private_data.txt"
  }
  
  # get instance ip in order to pass it to ansible playbook
  provisioner "local-exec" {
    command = "echo '[webserver]\n${self.public_ip}' > ${var.main_directory}/hosts.ini"
  }
  
  # configure ssh
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.private_key_path)
      host        = self.public_ip
    }

    inline = [
      "sudo apt update -y"
    ]
  }
  
  #Run ansible playbook
  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=false ansible-playbook -u ubuntu -b -i ${var.main_directory}/hosts.ini --private-key ${var.private_key_path} ${var.main_directory}/playbook.yml"
  }
}

data "aws_ami" "ami-ubuntu-bionic" {
  most_recent = true
  owners      = ["099720109477"]
  tags = {
    Name = "${var.author_name}-ec2-ami-t2-ubuntu-bionic"
  }
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server*"]
  }
}
````

