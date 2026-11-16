user_id=$(id -u)

if [ $user_id -ne 0 ]; then
echo "you are not root"
exit 1

else
echo "you are admin"
fi


echo "I'm exiting with $?"