#!/bin/bash
#fix-scripts.sh
#This script adds the storage driver Overlay to the yml files.
FILES=/opt/stanton/hostShellScripts/*
HAPROXY=/opt/stanton/devops/haproxy.tmpl
APPLICATION=/opt/stanton/devops/applications.yml
ENVIRONMENT=/opt/stanton/devops/applications.env
RED='\033[0;31m'
NC='\033[0m'
for f in $FILES
do
    echo -e "${RED}Adding Storage Driver to ${f}.${NC}"
    sed -i -e 's/docker.sock --c/docker.sock --storage-driver=overlay --c/' $f
    #echo -e "${RED}Adding consul config changes to ${f}.${NC}"
    #sed -i -e 's/data\ -e/data\ -v\ \/opt\/stanton\/consul\/consul.json:\/consul\/consul.json\ -e/g' $f
done
for h in $HAPROXY
do
    echo -e "${RED}Adding check statements to haproxy.${NC}"
    sed -i -e 's/}}{{ end }}/}} check inter 500 rise 2 fall 3 {{ end }}/' $h
done
for a in $APPLICATION
do
    if grep --quiet '-resync\ 60' $a; then
        echo -e "${RED}Applications.yml file already updated.${NC}"
    else
        echo -e "${RED}Update Applications.yml file .${NC}"
        sed -i -e 's/consul-template\/template.d\/consul.tmpl\n/consul-template\/template.d\/consul.tmpl\n\ \ \ \ \ \ -\ \/dev\/log:\/var\/log\/haproxy/g' $a
        sed -i -e 's/consul:\/\//-resync\ 60\ consul:\/\//g' $a
        sed -i -e 's/ui_customer\/:\/usr\/local\/tomcat\/logs\//ui_customer\/:\/usr\/local\/tomcat\/logs\/\n\ \ \ \ \ \ -\ \/opt\/stanton\/license\/devops-pdfile.pd:\/config\/devops-pdfile.pd\n\ \ \ \ \ \ -\ \/opt\/stanton\/app-config\/stg-customer.yml:\/usr\/local\/tomcat\/application.yml\n\ \ \ \ \ \ -\ \/opt\/stanton\/app-config\/hpssoconfig.xml:\/config\/hpssoconfig.xml/g' $a
        sed -i -e 's/command_channel\/:\/usr\/local\/tomcat\/logs\//command_channel\/:\/usr\/local\/tomcat\/logs\/\n\ \ \ \ \ \ -\ \/opt\/stanton\/license\/devops-pdfile.pd:\/config\/devops-pdfile.pd\n\ \ \ \ \ \ -\ \/opt\/stanton\/app-config\/stg-command.yml:\/usr\/local\/tomcat\/application.yml\n\ \ \ \ \ \ -\ \/opt\/stanton\/app-config\/hpssoconfig.xml:\/config\/hpssoconfig.xml/g' $a
        sed -i -e 's/backend_jobs\/:\/usr\/local\/tomcat\/logs\//backend_jobs\/:\/usr\/local\/tomcat\/logs\/\n\ \ \ \ \ \ -\ \/opt\/stanton\/license\/devops-pdfile.pd:\/config\/devops-pdfile.pd\n\ \ \ \ \ \ -\ \/opt\/stanton\/app-config\/stg-scheduler.yml:\/usr\/local\/tomcat\/application.yml\n\ \ \ \ \ \ -\ \/opt\/stanton\/app-config\/hpssoconfig.xml:\/config\/hpssoconfig.xml/g' $a
        sed -i -e 's/edge\/:\/config\/logs\//edge\/:\/config\/logs\/\n\ \ \ \ \ \ -\ \/opt\/stanton\/license\/devops-pdfile.pd:\/config\/devops-pdfile.pd/g' $a
	sed -i -e ': 1 ; N ; $!b1 ; s/\ -internal//4 ' $a      
	sed -i -e ': 1 ; N ; $!b1 ; s/\ -internal//4 ' $a      
	sed -i -e ': 1 ; N ; $!b1 ; s/\ -internal//4 ' $a      
	sed -i -e '/^.*image.*haproxy:\(.*\)/ s/$/1/' $a
  echo '
  ui_internal:
    image: devopsqa/ui-internal:16.7
    restart: always
    ports:
      - "8080"
    extra_hosts:
      - "postgres:10.0.0.27"
      - "vertica:10.0.0.28"
    environment:
      - "constraint:com.defender.server==applications"
    env_file:
      - applications.env
    volumes:
      - /opt/stanton/serverkeys/truststore.jks:/config/truststore.jks
      - /opt/stanton/serverkeys/keystore.jks:/config/keystore.jks
      - /opt/stanton/serverkeys/itemstore.jks:/config/itemstore.jks
      - /opt/defenderlogs/ui_internal/:/usr/local/tomcat/logs/
      - /opt/stanton/license/devops-pdfile.pd:/config/devops-pdfile.pd
      - /opt/stanton/app-config/stg-internal.yml:/usr/local/tomcat/application.yml
      - /opt/stanton/app-config/hpssoconfig.xml:/config/hpssoconfig.xml' >> $a
    fi
done

for e in $ENVIRONMENT
do
    echo -e "${RED}Adding ENV changes.${NC}"
    sed -i -e 's/^IP_COMMAND_CHANNEL=.*$/IP_COMMAND_CHANNEL=stgcmd.devops.com/g' $e
    sed -i -e 's/^IP_EVENT_CHANNEL=.*$/IP_EVENT_CHANNEL=stgevents.devops.com/g' $e
    sed -i -e 's/^IP_UI_CUSTOMER=.*$/IP_UI_CUSTOMER=stgui.devops.com/g' $e
    sed -i -e 's/^IP_UI_INTERNAL=.*$/IP_UI_INTERNAL=stginternal.devops.com/g' $e
    sed -i -e 's/^APPS_HOST=.*$/APPS_HOST=stgapps.devops.com/g' $e
done
