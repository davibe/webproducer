# Cheatsheet


Connect to server

```
ssh -i ~/.ssh//aws_ce_eu.pem  ubuntu@ec2-54-72-144-42.eu-west-1.compute.amazonaws.com
```
Use docker command

```
docker --host=tcp://localhost:4243 <cmd>
```
List of docker command

```
docker
```
Navigate inside docker fs

```
sudo su -
cd /var/lib/docker
// or
cd /var/lib/docker/containers/d20aee48f1c024b10abd661f4cd20ea274942f02dfbb3f06f3943d10e647c72b/root/static/contents
```
Free space

```
sudo df -h
```
Disk usage

```
sudo du -hs *
```