#!/bin/bash

# Functions are used to follow the DRY (Don't Repeat Yourself) principle—instead of copy-pasting the same 5 lines of code over and over, 
# you write that block once, give it a name, and call it whenever you need it. 

user_id=$(id -u)
 
if [$user_id -ne 0]; then
     echo "Please run the script with sudo accesss"
     exit 1
fi

validate(){
    if [$1 -ne 0]; then
       echo "$2....FAILED"
       exit 1
else 
   echo "$2... SUCCESS"
fi
}

echo "proceeding"
dnf install nginx -y
validate $? "Nginx Installation"

dnf install mysql -y
validate $? "mysql installation"

if [$? = 0]; then
echo "SUCCESS"