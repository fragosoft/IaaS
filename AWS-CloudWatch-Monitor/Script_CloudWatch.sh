###################
#######
#####
# Script_CloudWatch.sh
# Descripcion: Configura un ambiente para recolectar metricas customizadas de un instancia
# Autor mfragoso
###################
#######
#####

# Estas 2 primeras variables seran los valores que se setearan en el archivo de credenciales
# !!! Favor de modificarlos segun el caso
AWSAccessKeyId='hkaposksld'
AWSSecretKey='R4kjbuygsdop/iuahgsG'

# Borramos el cache para que nuestro script se ejecute inmediatamente 
# y no esperemos el time to live 
rm /var/tmp/aws-mon/instance-id

# Revisamos que version de linux tenemos instalada para decidir que comando ejecutar
SO=$(cat /etc/*-release)

# Validamos que sistema operativo estamos trabajando
# Ya que de eso dependera los comandos a ejecutar.
if echo $SO | grep -q 'Red Hat Enterprise'
then
   # La validacion incial sera revisar que el SO sea RedHat Enterprise 
   # RHEL tiene por default perl 5.8, esta version de RHEL no permite la instalacion de los paquetes requeridos
   # para que pueda correr el script de CloudWatch. 
   # Se requiere instalar perlbrew para manejar una version mas actual de perl almenos la 5.16
   curl -kL http://install.perlbrew.pl | bash

   #Inicializamos perlbrew 
   $HOME/perl5/perlbrew/bin/perlbrew init

   # Ponemos en el Path perlbrew
   echo "source $HOME/perl5/perlbrew/etc/bashrc" >> ~/.bashrc

   # Recargamos bashrc
   source ~/.bashrc

   # Instalamos la version de perl 5.16.3
   perlbrew  --notest install perl-5.16.3
   $HOME/perl5/perlbrew/bin/perlbrew  --notest install perl-5.16.3

   #Instalamos los paquetes 
   #Switch 
   #DateTime 
   #Sys-Syslog 
   #LWP-Protocol-https 
   #Digest-SHA
   cpan -fi Switch
   cpan -fi DateTime 
   cpan -fi Sys::Syslog 
   cpan -fi LWP::Protocol::https
   cpan -fi Digest::SHA

   # Para perlbrew se necesitaran paquetes adicionales, se deberan instalar estos paquetes.
   cpan -fi Net::LDAP
   cpan -fi URI
   cpan -fi URI::Escape
   cpan -fi LWP::UserAgent
   cpan -fi IO::Socket::SSL

   #Instalamos programas para descomprimir archivos en caso de que no los tenga
   sudo yum install zip unzip -y

else
	## Instalamos los paquetes de perl para que podamos ejecutar mas adelante los scripts
	sudo yum install perl-Switch perl-DateTime perl-Sys-Syslog perl-LWP-Protocol-https -y 
fi

## Descargamos los scripts de perl para las metricas especificas en el home de ec2-user
## Descomprimimos el zip y nos posicionamos en el path del script
curl http://aws-cloudwatch.s3.amazonaws.com/downloads/CloudWatchMonitoringScripts-1.2.1.zip -O
unzip CloudWatchMonitoringScripts-1.2.1.zip
rm CloudWatchMonitoringScripts-1.2.1.zip
cd aws-scripts-mon

## WARNING!! si las instancias no se estan manejando por role tambien se puede modificar el archivo template 
## para agregar el WSAccessKeyId  y AWSSecretKey
rm awscreds.template

echo 'WSAccessKeyId='$WSAccessKeyId >> awscreds.template
echo 'AWSSecretKey='$AWSSecretKey >> awscreds.template


## Cargamos en un cron que la recoleccion de datos por el script de perl sea enviado a cloud watch cada 5 min.
## Estas nuevas metricas se encuentran en CloudWatch bajo el nombre de Linux System Metrix. 
crontab -l > CloudWatchCron
## Configuracion para role 
#echo "*/5 * * * * ~/aws-scripts-mon/mon-put-instance-data.pl --mem-util --mem-used --mem-avail --disk-space-util --disk-path=/ --from-cron" >> CloudWatchCron
# Configuracion para credenciales
if echo $SO | grep -q 'Red Hat Enterprise'
then
	#Dentro de RHEL vamos a ejecutar los scripts de perl con la version especifica de perlbrew previamente configurada
	#perlbrew exec perl
	echo "*/5 * * * * $HOME/perl5/perlbrew/bin/perlbrew exec perl ~/aws-scripts-mon/mon-put-instance-data.pl --mem-util --mem-used --mem-avail --disk-space-util --disk-path=/ --from-cron --aws-credential-file=$HOME/aws-scripts-mon/awscreds.template" >> CloudWatchCron
else
	echo "*/5 * * * * ~/aws-scripts-mon/mon-put-instance-data.pl --mem-util --mem-used --mem-avail --disk-space-util --disk-path=/ --from-cron --aws-credential-file=$HOME/aws-scripts-mon/awscreds.template" >> CloudWatchCron
fi
crontab CloudWatchCron
rm CloudWatchCron