#!/bin/bash
#fix-scripts.sh
#This script adds the storage driver Overlay to the yml files.
FILES=/opt/hpad/hostShellScripts/*
HAPROXY=/opt/hpad/appdefender/haproxy.tmpl
APPLICATION=/opt/hpad/appdefender/applications.yml
ENVIRONMENT=/opt/hpad/appdefender/applications.env
RED='\033[0;31m'
NC='\033[0m'
for f in $FILES
do
    echo -e "${RED}Adding Storage Driver to ${f}.${NC}"
    sed -i -e 's/docker.sock --c/docker.sock --storage-driver=overlay --c/' $f
    #echo -e "${RED}Adding consul config changes to ${f}.${NC}"
    #sed -i -e 's/data\ -e/data\ -v\ \/opt\/hpad\/consul\/consul.json:\/consul\/consul.json\ -e/g' $f
done
for h in $HAPROXY
do
    echo -e "${RED}Adding check statements to haproxy.${NC}"
    sed -i -e 's/}}{{ end }}/}} check inter 500 rise 2 fall 3 {{ end }}/' $h
    sed -i -e 's/stats:stats/admin:staging\n\ \ stats\ admin\ if\ TRUE/g' $h
done
for a in $APPLICATION
do
    if grep --quiet '-resync\ 60' $a; then
        echo -e "${RED}Applications.yml file already updated.${NC}"
    else
        echo -e "${RED}Update Applications.yml file .${NC}"
        sed -i -e 's/consul-template\/template.d\/consul.tmpl\n/consul-template\/template.d\/consul.tmpl\n\ \ \ \ \ \ -\ \/dev\/log:\/var\/log\/haproxy/g' $a
        sed -i -e 's/consul:\/\//-resync\ 60\ consul:\/\//g' $a
        sed -i -e 's/ui_customer\/:\/usr\/local\/tomcat\/logs\//ui_customer\/:\/usr\/local\/tomcat\/logs\/\n\ \ \ \ \ \ -\ \/opt\/hpad\/license\/appdefender-pdfile.pd:\/config\/appdefender-pdfile.pd\n\ \ \ \ \ \ -\ \/opt\/hpad\/app-config\/stg-customer.yml:\/usr\/local\/tomcat\/application.yml\n\ \ \ \ \ \ -\ \/opt\/hpad\/app-config\/hpssoconfig.xml:\/config\/hpssoconfig.xml/g' $a
        sed -i -e 's/command_channel\/:\/usr\/local\/tomcat\/logs\//command_channel\/:\/usr\/local\/tomcat\/logs\/\n\ \ \ \ \ \ -\ \/opt\/hpad\/license\/appdefender-pdfile.pd:\/config\/appdefender-pdfile.pd\n\ \ \ \ \ \ -\ \/opt\/hpad\/app-config\/stg-command.yml:\/usr\/local\/tomcat\/application.yml\n\ \ \ \ \ \ -\ \/opt\/hpad\/app-config\/hpssoconfig.xml:\/config\/hpssoconfig.xml/g' $a
        sed -i -e 's/backend_jobs\/:\/usr\/local\/tomcat\/logs\//backend_jobs\/:\/usr\/local\/tomcat\/logs\/\n\ \ \ \ \ \ -\ \/opt\/hpad\/license\/appdefender-pdfile.pd:\/config\/appdefender-pdfile.pd\n\ \ \ \ \ \ -\ \/opt\/hpad\/app-config\/stg-scheduler.yml:\/usr\/local\/tomcat\/application.yml\n\ \ \ \ \ \ -\ \/opt\/hpad\/app-config\/hpssoconfig.xml:\/config\/hpssoconfig.xml/g' $a
        sed -i -e 's/edge\/:\/config\/logs\//edge\/:\/config\/logs\/\n\ \ \ \ \ \ -\ \/opt\/hpad\/license\/appdefender-pdfile.pd:\/config\/appdefender-pdfile.pd/g' $a
	sed -i -e ': 1 ; N ; $!b1 ; s/\ -internal//4 ' $a      
	sed -i -e ': 1 ; N ; $!b1 ; s/\ -internal//4 ' $a      
	sed -i -e ': 1 ; N ; $!b1 ; s/\ -internal//4 ' $a      
	sed -i -e '/^.*image.*haproxy:\(.*\)/ s/$/1/' $a
  echo '
  ui_internal:
    image: appdefenderqa/ui-internal:16.7
    restart: always
    ports:
      - "8080"
    extra_hosts:
      - "postgres:10.111.4.27"
      - "vertica:10.111.4.28"
    environment:
      - "constraint:com.defender.server==applications"
    env_file:
      - applications.env
    volumes:
      - /opt/hpad/serverkeys/truststore.jks:/config/truststore.jks
      - /opt/hpad/serverkeys/keystore.jks:/config/keystore.jks
      - /opt/hpad/serverkeys/itemstore.jks:/config/itemstore.jks
      - /opt/defenderlogs/ui_internal/:/usr/local/tomcat/logs/
      - /opt/hpad/license/appdefender-pdfile.pd:/config/appdefender-pdfile.pd
      - /opt/hpad/app-config/stg-internal.yml:/usr/local/tomcat/application.yml
      - /opt/hpad/app-config/hpssoconfig.xml:/config/hpssoconfig.xml' >> $a
    fi
done

for e in $ENVIRONMENT
do
    echo -e "${RED}Adding ENV changes.${NC}"
    sed -i -e 's/^IP_COMMAND_CHANNEL=.*$/IP_COMMAND_CHANNEL=stgcmd.hpeappdefender.com/g' $e
    sed -i -e 's/^IP_EVENT_CHANNEL=.*$/IP_EVENT_CHANNEL=stgevents.hpeappdefender.com/g' $e
    sed -i -e 's/^IP_UI_CUSTOMER=.*$/IP_UI_CUSTOMER=stgui.hpeappdefender.com/g' $e
    sed -i -e 's/^IP_UI_INTERNAL=.*$/IP_UI_INTERNAL=stginternal.hpeappdefender.com/g' $e
    sed -i -e 's/^APPS_HOST=.*$/APPS_HOST=stgapps.hpeappdefender.com/g' $e
done
