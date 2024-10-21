#!/bin/bash
rtl_433 -f $frequency -s $sample_rate -R $device_id -F json -F "mqtt://$mqtt_server,events=$mqtt_topic,retain=0,user=$mqtt_user,pass=$mqtt_password" -F log