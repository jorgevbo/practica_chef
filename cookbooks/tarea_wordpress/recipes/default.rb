#
# Cookbook:: tarea_wordpress
# Recipe:: default
#
# Copyright:: 2018, The Authors, All Rights Reserved.

node.default['main']['wp_domain'] = '192.168.99.10'
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
package 'mysql-server-5.6'

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
  command "mysql -e \"DROP USER '#{node['main']['database_user']}'@'localhost'\""
  ignore_failure true
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

execute "Comprobar si existe la DB" do
  command "mysql -u root #{node['main']['database_name']} -e \"SELECT ID FROM #{node['main']['database_name']}.wp_users LIMIT 1;\" | tee > /tmp/wp_exists"
  ignore_failure false
end

template "/tmp/wp-database.sql" do
  source 'wordpress/wp-database.sql.erb'
  variables ({
    :wp_domain => node['main']['wp_domain'],
    :initial_post_title => node['main']['initial_post_title'],
    :initial_post_content => node['main']['initial_post_content']
  })
  only_if do
    # Solo si no se encuentran usuarios en la DB
    File.exists?('/tmp/wp_exists') && File.read('/tmp/wp_exists').empty?
  end
end

execute "Importar la DB Wordpress" do
  command "mysql -u root #{node['main']['database_name']} < /tmp/wp-database.sql"
  only_if do
    # Solo si no se encuentran usuarios en la DB
    File.exists?('/tmp/wp_exists') && File.read('/tmp/wp_exists').empty?
  end
end

log 'Mostrar los atributos de la maquina mediante Ohai' do
  node_ip = node[:network][:interfaces][:eth1][:addresses].detect{ |k, v| v[:family] == 'inet' }.first
  message """Maquina con #{node['memory']['total']} de memoria y #{node['cpu']['total']} procesador/es.
          Por favor verificar el acceso a http://#{node_ip}"""
end
