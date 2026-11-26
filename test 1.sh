#!/bin/bash

user_id=$(id -u)

if [ $user_id -ne 0 ]; then
echo " Please run the script with root access... exiting"
exit 1
fi

echo "proceeding"

dnf install nginx -y

if [ $? -ne 0 ]; then
echo "Nginx installation failed"
exit 1
else
echo "Nginx installation Success"
fi
