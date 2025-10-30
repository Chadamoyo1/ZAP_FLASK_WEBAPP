# Automated Web Vulnerability Scanner (Flask + OWASP ZAP)

## Overview
This project presents a Flask web application that automates vulnerability scanning using OWASP ZAP and its Python API. The system allows users to input URLs, initiate scans, allow the user to download the scan results. All reports are securely stored in a MariaDB database via SQLAlchemy. The system is served using Gunicorn and Nginx with SSL certificates, ensuring secure access. This project demonstrates the integration of web automation, cybersecurity tooling, and secure web deployment practices

## Key Components:

α	Flask:                    Provides a simple web interface and backend logic.

α	OWASP ZAP:                Handles spidering, scanning, and report generation.

α	ZAP Python API (zapv2):   Enables programmatic interaction with ZAP.

α	SQLAlchemy + MariaDB:     Stores URLs, scan metadata, and report paths.

α	Gunicorn:                 Runs the Flask app as a WSGI server.

α	Nginx:        Acts as a reverse proxy with SSL termination for secure HTTPS access.

α   Linux Host:               Environment for running and managing all services.

## Features

α	OWASP ZAP Integration – Automates scanning and spidering using the ZAP API  

α	Web Interface – Flask GUI for user input and report access 

α	Database Storage – Saves scan results and reports in MariaDB  

α	Report Generation – Downloadable vulnerability reports (HTML)  

α	HTTPS access via Nginx + SSL

α	Gunicorn service for WSGI deployment

α	Deployment Ready – Compatible with Gunicorn and Nginx  

α	Security Awareness Tool – Demonstrates real-world web security automation


## Tech Stack

 	Frontend:-- Flask (HTML,Jinja2)

 	Backend:-- Flask, Python 3,ZAP API

 	Scanner:-- OWASP ZAP Proxy

 	Database:-- MariaDB + SQLAlchemy

 	Server/Deployment:-- Gunicorn, Nginx

 	Security: TLS/SSL Certificates

 	OS: Linux UBUNTU (AWS EC2 Instance)

## Workflow:

α	User submits a target URL via Flask UI.

α	Flask calls ZAP API → starts spidering and scanning.

α	Scan results are stored in MariaDB using SQLAlchemy ORM.

α	Flask displays and allows download of the generated report.

α	Gunicorn serves the app, and Nginx handles HTTPS connections.


## Problems solved by the project

PROBLEM:                    Manual scanning is repetitive and slow

SOLUTION:                   Automated OWASP ZAP integration

....................................................
PROBLEM:                    Non-technical users can’t use CLI tools 

SOLUTION:                   Web-based interface with Flask
....................................................

PROBLEM:                    Scan results not centralized 

SOLUTION:                   Reports stored in MariaDB
....................................................

PROBLEM:                    Insecure deployments

SOLUTION:                   HTTPS access via Nginx SSL

....................................................
PROBLEM:                    Reproducibility issues

SOLUTION:                   Standardised API-Driven Scans

....................................................

## Usage

You need to have an AWS Account

Avoid using root account.Create a user and implement  MFA (Recommended)

1. Create an EC2 Instance

  -Choose Ubuntu OS

  -At least 4 GB RAM (t3.medium)

  -create a key pair (e.g key.pem) and attach to your instance 

  -Security Group:allow ssh,http ,https and tcp port 5000 from anywhere (0.0.0.0/0)


2. ssh into your ec2 instance 

  $ ssh -i key.pem ubuntu@ec2 _public_ip

  Replace key.pem with your key name and ec2_public IP with the public ip of the ec2 instance you created

3. clone the repository from git and run the script

  $sudo chmod +x script              # make the file executable

  $sudo ./script.sh                  # run the script

you will be pompted to type in/set the following parameters:

  ---- project_username and paasword of your choice

  -----mariadb root password

  -----mariad db username and password 

  -----database name

4. After completing the setup,switch from ubuntu user to the project_user name you created 

   $ su - project_username           

5. switch to the project folder

   $ cd zapproject                   

6. activate virtual environment

   $ source -zapvenv/bin/activate    

Now you can access the flask application by typing your ec2 instance public ip in the
browser  ,type in your url to start spidering and scanning.



