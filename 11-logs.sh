#!/bin/bash


user_id=$(id -u)
logs_folder="/var/log/shell-practice"
logs_file="${logs_folder}/$0.log"


if [ $user_id -ne 0 ]; then
     echo "Please run the script with sudo accesss"
     exit 1
fi

mkdir -p $logs_folder

echo "script started executing at $(date +"%F %T")"

validate(){
    if [ $1 -ne 0 ]; then
       echo "$2....FAILED" | tee -a $logs_file
       exit 1
else 
   echo "$2... SUCCESS" | tee -a $logs_file
fi
}

echo "proceeding"
dnf install nginx -y &>> $logs_file
validate $? "Nginx Installation"

dnf install mysql -y
validate $? "mysql installation"

echo "script execution completed at ${date +"%F %T"}"
