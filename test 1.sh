#!/bin/bash

user_id=$(id -u)

if [ $user_id -ne 0 ]; then
echo " Please run the script with root access... exiting"
exit 1
fi

echo "proceeding"

validate (){

if [ $1 -ne 0 ]; then
echo "$2... Failed"
else 
echo "$2... Success"
fi
}


dnf install nginx -y
validate $? "Nginix installation"

dnf install mysql -y
validate $? "mysql installation"

