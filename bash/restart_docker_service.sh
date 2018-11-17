#!/bin/bash
ssh 10.0.0.21 service docker restart
ssh 10.0.0.22 service docker restart
ssh 10.0.0.23 service docker restart
ssh 10.0.0.24 service docker restart
ssh 10.0.0.25 service docker restart
ssh 10.0.0.26 service docker restart

/opt/stanton/docker_service_status.sh | grep Active
