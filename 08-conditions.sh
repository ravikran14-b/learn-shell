#!/bin/bash

#lt - Less than
#gt - Greater than
#eq - Equal to

echo "Enter the marks"
read marks

if [ $marks -lt 33 ]; then
echo "Fail"
elif [ $marks -lt 50 ]; then
echo "C rank"
elif [ $marks -lt 60 ]; then
echo "B rank"
elif [ $marks -lt 80 ]; then
echo "A rank"
else
echo "A+ rank"      
fi

echo "End"
