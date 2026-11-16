#!/bin/bash

# First check if current user has root access
# If yes, proceed. If no, error and exit.

#Pseudo code 
# 1. Get the user id of the current user
# 2. If user id is 0, then user has root access. Proceed.
# 3. If user id is not 0, then error and exit.

user_id=$(id -u)

if [ $user_id -ne 0 ]; then
echo "Please run this script with sudo access...."
exit 1
fi 

echo "proceeding..."


dnf install nginx -y

if [ $? -ne 0 ]; then
echo "Nginx installation failed"
exit 1

else 
    echo "Nginx installed successfully"

fi

dnf install mysql -y

if [ $? -ne 0 ]; then
echo "mysql installation failed"
exit 1

else 
    echo "mysql installation Success"
    fi
