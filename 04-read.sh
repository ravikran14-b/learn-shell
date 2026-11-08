#!/bin/bash

# read command is used to take input from user and store it in a variable
# -s option is used to hide the input from user while typing (useful for passwords)
# -p option is used to display a prompt message before taking input from user
# -n option is used to take only a specific number of characters as input from user

echo "Enter your name: "
read name
echo "Hello, $name!"

echo "Enter your password: "
read -s password
echo "Your password is: $password"  

echo "Enter your age: "
read -n 2 age
echo "Your age is: $age"    

