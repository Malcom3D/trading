#!/bin/bash
case $1 in
	log)
		sudo /usr/bin/tail /var/log/syslog
	;;
	restart)
		sudo /usr/bin/systemctl restart trading
	;;
	reboot)
		sudo /usr/sbin/reboot
	;;
	poweroff)
		sudo /usr/sbin/poweroff
	;;
esac
