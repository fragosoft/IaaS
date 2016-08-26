###################
#######
#####
# CloudWatchMonitor_RHEL.sh
# Descripcion:      Configura un ambiente para recolectar metricas customizadas de un instancia Red Hat Enterprise
# Bugs Conocidos:	En caso de marcar el error No credential methods are specified. Trying default IAM role
#				   favor de revisar el archivo awscreds.template ya que a veces el echo mete bytes de desconocidos
# Autor fragosoft
###################
#######
#####

# Estas 2 primeras variables seran los valores que se setearan en el archivo de credenciales
# !!! Favor de modificarlos segun el caso
AWSAccessKeyId='hkaposksld'
AWSSecretKey='R4kjbuygsdop/iuahgsG'

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

#Hacemos un switch para tener intercambiar entre la version de perl a utilizar
#con la instruccion perlbrew  off regresamos a la version default de RHEL
$HOME/perl5/perlbrew/bin/perlbrew  switch perl-5.16.3

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

#Algunos paquetes que usa perl en https usan librerias de openssl 
sudo yum install openssl-devel

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

#Dentro de RHEL vamos a ejecutar los scripts de perl con la version especifica de perlbrew previamente configurada
#perlbrew exec perl
echo "*/5 * * * * $HOME/perl5/perlbrew/bin/perlbrew exec perl ~/aws-scripts-mon/mon-put-instance-data.pl --mem-util --mem-used --mem-avail --disk-space-util --disk-path=/ --from-cron --aws-credential-file=$HOME/aws-scripts-mon/awscreds.template" >> CloudWatchCron

crontab CloudWatchCron
rm CloudWatchCron

# Para validar que la instalacion fue correcta y no esperar los 5min para que se ejecute el cron puedes ejecutar 
### $HOME/perl5/perlbrew/bin/perlbrew exec perl ~/aws-scripts-mon/mon-put-instance-data.pl --mem-util --mem-used --mem-avail --disk-space-util --disk-path=/ --verbose --aws-credential-file=$HOME/aws-scripts-mon/awscreds.template 

## La salida del comando previo debe ser la siguiente
#MemoryUtilization: 16.3710852649234 (Percent)
#MemoryUsed: 162.8046875 (Megabytes)
#MemoryAvailable: 831.66015625 (Megabytes)
#DiskSpaceUtilization [/]: 6.54049506601621 (Percent)
#Using AWS credentials file </home/ec2-user/aws-scripts-mon/awscreds.template>
#Endpoint: https://monitoring.us-west-2.amazonaws.com
#Payload: {"MetricData":[{"Timestamp":1472146299,"Dimensions":[{"Value":"i-0fa1bab221c2ed6cb","Name":"InstanceId"}],"Value":16.3710852649234,"Unit":"Percent","MetricName":"MemoryUtilization"},{"Timestamp":1472146299,"Dimensions":[{"Value":"i-0fa1bab221c2ed6cb","Name":"InstanceId"}],"Value":162.8046875,"Unit":"Megabytes","MetricName":"MemoryUsed"},{"Timestamp":1472146299,"Dimensions":[{"Value":"i-0fa1bab221c2ed6cb","Name":"InstanceId"}],"Value":831.66015625,"Unit":"Megabytes","MetricName":"MemoryAvailable"},{"Timestamp":1472146299,"Dimensions":[{"Value":"/dev/xvda1","Name":"Filesystem"},{"Value":"i-0fa1bab221c2ed6cb","Name":"InstanceId"},{"Value":"/","Name":"MountPath"}],"Value":6.54049506601621,"Unit":"Percent","MetricName":"DiskSpaceUtilization"}],"Namespace":"System/Linux","__type":"com.amazonaws.cloudwatch.v2010_08_01#PutMetricDataInput"}
###########ESTATUS 200 debe ser el correcto, un 400 es not found, 500 error de conexion, 403 el servicio no esta disponible
#Received HTTP status 200 on attempt 1
#Successfully reported metrics to CloudWatch. Reference Id: c810d7f2-6ae9-11e6-b836-7bbc0e5c84c6
