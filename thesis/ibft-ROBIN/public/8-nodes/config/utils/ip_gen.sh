#!/bin/bash
found=false
random=
while [ $found = false ]
do
	random=$(( ( $RANDOM % 255 ) + 2 ))
	for ip in ${ips[*]}
	do
		tmp=`echo $ip | cut -d . -f 4`
		if [ "$random" = "$tmp" ]; 
		then
			found=false			
			break
		fi	
		found=true
	done
done

new_ip="172.13.0.$random"
ips+=($new_ip)

echo $new_ip
