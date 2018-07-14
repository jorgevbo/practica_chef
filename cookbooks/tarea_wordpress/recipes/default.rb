#
# Cookbook:: tarea_wordpress
# Recipe:: default
#
# Copyright:: 2018, The Authors, All Rights Reserved.

node.default['main']['wp_domain'] = 'book.example.com'
node.default['main']['database_name'] = 'jorgewp'
node.default['main']['database_user'] = 'jorgewp'
node.default['main']['database_password'] = 'bananas98765'
node.default['main']['initial_post_title'] = 'Hola que tal'
node.default['main']['initial_post_content'] = 'Esto es un ejemplo de post. Cambialo por algo interesante'

# Instalar herramientas requeridas
package 'unzip'

# Agregar PPA de PHP
apt_repository 'ondrej-php' do
  uri 'ppa:ondrej/php'
end

apt_repository 'mariadb' do
  uri 'http://nyc2.mirrors.digitalocean.com/mariadb/repo/10.3/ubuntu',
  components ['mariadb-server']
end


apt_update 'Actualizar cache APT' do
  frequency 86_400
  action :periodic
end

# Instalar PHP y dependencias
package 'php'
package 'php-fpm'
package 'php-mysql'
package 'php-xml'

# Quitar Apache2
package 'apache2' do
  action :remove
end

# Instalar MySQL
# package 'mysql-server'
package 'mariadb-server'
# package 'python-mysqldb'
# node.default['main']['mysql_new_root_pass'] = nil
# Generar contraseña para  root de MySQL
#execute 'generar contraseña para root' do
#  command 'openssl rand -hex 7 > /root/mysql_new_root_pass'
#  creates '/root/.my.cnf'
#  creates '/root/mysql_new_root_pass'
#end


# Instalar NGINX
package 'nginx'
service 'nginx' do
  supports :status => true
  action :enable
end

template '/etc/nginx/sites-available/default' do
  source 'nginx/default.erb'
  variables ({
    :wp_domain => node['main']['wp_domain']
  })


  notifies :restart, resources(:service => 'nginx')
end

# Wordpress
cookbook_file '/tmp/wordpress.zip' do
  source 'wordpress.zip'
end

execute 'Descomprimir Wordpress' do
  command 'unzip /tmp/wordpress.zip -d /tmp'
  creates '/tmp/wordpress/wp-settings.php'
end

directory "/var/www/#{node['main']['wp_domain']}"

execute 'copiar los archivos de wordpress' do
  command "cp -a /tmp/wordpress/. /var/www/#{node['main']['wp_domain']}"
  creates "/var/www/#{node['main']['wp_domain']}/wp-settings.php"
end

execute 'Crear base de datos wordpress' do
  command "mysql -e \"CREATE DATABASE IF NOT EXISTS #{node['main']['database_name']}\""
end

execute 'Limpiar el usuario de DB para wordpress' do
  command "mysql -e \"DROP USER IF EXISTS '#{node['main']['database_user']}'@'localhost'\""
end

execute 'Crear el usuario de DB para wordpress' do
  command "mysql -e \"CREATE USER '#{node['main']['database_user']}'@'localhost' IDENTIFIED BY '#{node['main']['database_password']}'\""
end

execute 'Agregar permisos a la DB' do
  command "mysql -e \"GRANT ALL ON #{node['main']['database_name']}.* TO '#{node['main']['database_user']}'@'localhost'\""
end

execute 'Limpiar cache de privilegios' do
  command "mysql -e \"FLUSH PRIVILEGES\""
end

template "/var/www/#{node['main']['wp_domain']}/wp-config.php" do
  source 'wordpress/wp-config.php.erb'
  variables ({
    :database_name => node['main']['database_name'],
    :database_user => node['main']['database_user'],
    :database_password => node['main']['database_password']
  })
end

=begin
# Backups de la base de datos
- name: Existe la base de datos?
  command: mysql -u root {{database_name}} -e "SELECT ID FROM {{database_name}}.wp_users LIMIT 1;"
  register: db_exist
  ignore_errors: true
  changed_when: false
- name: Copiar la DB Wordpress
  template: src=wp-database.sql dest=/tmp/wp-database.sql
  when: db_exist.rc > 0
- name: Importar la DB Wordpress
  mysql_db: target=/tmp/wp-database.sql state=import name={{database_name}}
  when: db_exist.rc > 0
=end

