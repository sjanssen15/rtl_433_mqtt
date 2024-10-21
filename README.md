# rtl_433_mqtt
I created this Docker container in order to run rtl_433 and gather Weather station data. Then, send that data over MQTT to have it integrated into Home Assistant as sensor data.

Tested hardware & Software:
- Raspberry Pi 3 (Ubuntu Server & Docker)
- NESDR Mini 2+ RTL-SDR with RTL2832U & R820T2
- Dipole antenna
- Home Assistant (container) + MQTT integration
- Mosquitto MQTT

# Requirements
## RTL-SDR dongle
The rtl_433 documentation says the following: <br>
It works with RTL-SDR and/or SoapySDR. Actively tested and supported are Realtek RTL2832 based DVB dongles (using RTL-SDR) and LimeSDR (LimeSDR USB and LimeSDR mini engineering samples kindly provided by MyriadRf), PlutoSDR, HackRF One (using SoapySDR drivers), as well as SoapyRemote.

Latest docs: https://github.com/merbanan/rtl_433?tab=readme-ov-file#running

## MQTT setup
### Home Assistant MQTT setup
You have to setup the MQTT integration (with Mosquitto) and make it listen to your newly created topic. This works after you have run the container for the first time.

see: https://www.home-assistant.io/integrations/mqtt

### Topic
A topic is automatically generated when pushing data from rtl_433 to your MQTT instance.
The given mqtt_topic name will be generated when not existing on the MQTT broker.

# Running the container
## Clone
Clone this repository to start building
```Shell
git clone https://github.com/sjanssen15/rtl_433_mqtt.git
cd rtl_433_mqtt
```

## Build image
Build the Docker image for your system. Testen on both arm64 (Pi) and x86_64 (Intel)
```Shell
docker build -t rtl_433_mqtt:latest .
```

## Run docker-compose
### Get RTL-SDR device path
Run the following command to get the correct device location (if you have a device with DVB in the name). You will use this in your docker-compose.yml file.
```
lsusb | grep -i 'DVB' | awk '{print "/dev/bus/usb/" $2 "/" substr($4, 1, length($4)-1)}'
```

### Discover devices
Run the following to start discovering on different frequenties. You have to do this on your local Docker host. Let this run for a while to see if data is sent by devices.
```Shell
# 433MHz default
rtl_433

# 433 MHz default with metric system conversion
rtl_433 -C si

# 868MHz
rtl_433 -f 868M
```

## Docker compose
The following example is used to receive data from a 6 in 1 weather station and output it's data to a MQTT for integration in Home Assistant. Create a file name <b>docker-compose.yml</b> in your current directory and add the correct data.
```yaml
services:
  rtl_433_mqtt:
    container_name: rtl_433_mqtt-container
    restart: always
    image: rtl_433_mqtt:latest
    devices:
      - /dev/bus/usb/001/004
    environment:
      sample_rate: 1024k
      frequency: 868M
      device_id: 172
      mqtt_user: admin
      mqtt_password: <password>
      mqtt_server: <ip or fqdn>
      mqtt_topic: rtl_433/Bresser/6in1
```

| **Parameter** | **Explanation**                                                                                     |
|---------------|-----------------------------------------------------------------------------------------------------|
| sample_rate   | See: https://github.com/merbanan/rtl_433?tab=readme-ov-file#running                                 |
| frequency     | See: https://github.com/merbanan/rtl_433                                                            |
| device_id     | For full list, run rtl_433 -h or see https://github.com/merbanan/rtl_433?tab=readme-ov-file#running |
| mqtt_user     | mqtt user to authenticate with.                                                                     |
| mqtt_password | mqtt password of user.                                                                              |
| mqtt_server   | mqtt broker IP or FQDN.                                                                             |
| mqtt_topic   | mqtt topic to create or use. If it does not exist, it will be created.                               |

## Run container
```
docker compose up -d
```

View the logs and see if data is received by the RTL-SDR
```Shell
docker logs -f rtl_433_mqtt-container
```

# Setting up Home Assistant
## Home Assistant sensor
I use the following mqtt sensor in HA. This sensor will parse the json data in the topic. Since this weatherstation sends 2 different message every so often with different fields, you have to dynamically read the JSON data as it comes in. In the excample we use the value_template and choose value_json.<field>. This field name can be found after rtl_433 pushed some data to it. When no new data is received in certain fields, it will retain the last known value.

You can use <b>MQTT Explorer</b> for instance to discover your topics and find the JSON data. Example payload:
```json
{
  "time": "2024-10-21 20:29:48",
  "model": "Bresser-6in1",
  "id": 554700972,
  "channel": 0,
  "battery_ok": 0,
  "temperature_C": 12.3,
  "humidity": 99,
  "sensor_type": 1,
  "wind_max_m_s": 0,
  "wind_avg_m_s": 0,
  "wind_dir_deg": 45,
  "uv": 0,
  "startup": 1,
  "flags": 0,
  "mic": "CRC"
}
```

Edit your Home Assistant configuration.yaml and add your sensor. This is an example, you have to use your own data and change the value_template values and topic name. Don't forget to reboot.
```yaml
mqtt:
  sensor:
    - name: Tungelroy Temperature
      device_class: temperature
      unit_of_measurement: '°C'
      value_template: '{{ value_json.temperature_C }}'
      state_topic: rtl_433/Bresser/6in1
      json_attributes_topic: rtl_433/Bresser/6in1

    - name: Tungelroy Humidity
      device_class: humidity
      unit_of_measurement: '%'
      value_template: '{{ value_json.humidity }}'
      state_topic: rtl_433/Bresser/6in1

    - name: Tungelroy Wind speed (avg)
      unit_of_measurement: 'm/s'
      value_template: '{{ value_json.wind_avg_m_s }}'
      state_topic: rtl_433/Bresser/6in1
      json_attributes_topic: rtl_433/Bresser/6in1

    - name: Tungelroy Wind speed (max)
      unit_of_measurement: 'm/s'
      value_template: '{{ value_json.wind_max_m_s }}'
      state_topic: rtl_433/Bresser/6in1
      json_attributes_topic: rtl_433/Bresser/6in1

    - name: Tungelroy rain (mm)
      unit_of_measurement: 'mm'
      value_template: '{{ value_json.rain_mm }}'
      state_topic: rtl_433/Bresser/6in1
      json_attributes_topic: rtl_433/Bresser/6in1

    - name: Tungelroy Wind direction (degrees)
      unit_of_measurement: '°'
      value_template: '{{ value_json.wind_dir_deg }}'
      state_topic: rtl_433/Bresser/6in1
      json_attributes_topic: rtl_433/Bresser/6in1
```
