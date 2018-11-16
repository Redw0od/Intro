#!/bin/bash
ssh 10.111.4.21 service docker restart
ssh 10.111.4.22 service docker restart
ssh 10.111.4.23 service docker restart
ssh 10.111.4.24 service docker restart
ssh 10.111.4.25 service docker restart
ssh 10.111.4.26 service docker restart

/opt/hpad/docker_service_status.sh | grep Active
