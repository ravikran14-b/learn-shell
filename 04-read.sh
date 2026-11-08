#!/bin/bash

# read command is used to take input from user and store it in a variable
# -s option is used to hide the input from user while typing (useful for passwords)
# -p option is used to display a prompt message before taking input from user
# -n option is used to take only a specific number of characters as input from user
# -t option is used to set a timeout for the input command, if user does not provide input within the specified time, the command will exit with a non-zero status

echo "Enter your name: "
read name
echo "Hello, $name!"

echo "Enter your password: "
read -s password
echo "Your password is: $password"  

echo "Enter your age: "
read -n 2 age
echo "Your age is: $age"    

echo "Enter your favorite color (you have 5 seconds to answer): "
if read -t 5 color; then
    echo "Your favorite color is: $color"           
else
    echo "You did not answer in time!"  

echo "Your favorite color is: $color"           
else
    echo "You did not answer in time!"  
fi      
