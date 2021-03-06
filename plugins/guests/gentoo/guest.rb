require 'tempfile'

require "vagrant"
require 'vagrant/util/template_renderer'

require Vagrant.source_root.join("plugins/guests/linux/guest")

module VagrantPlugins
  module GuestGentoo
    class Guest < VagrantPlugins::GuestLinux::Guest
      # Make the TemplateRenderer top-level
      include Vagrant::Util

      def configure_networks(networks)
        # Remove any previous host only network additions to the interface file
        vm.communicate.sudo("sed -e '/^#VAGRANT-BEGIN/,/^#VAGRANT-END/ d' /etc/conf.d/net > /tmp/vagrant-network-interfaces")
        vm.communicate.sudo("cat /tmp/vagrant-network-interfaces > /etc/conf.d/net")
        vm.communicate.sudo("rm /tmp/vagrant-network-interfaces")

        # Configure each network interface
        networks.each do |network|
          entry = TemplateRenderer.render("guests/gentoo/network_#{network[:type]}",
                                          :options => network)

          # Upload the entry to a temporary location
          temp = Tempfile.new("vagrant")
          temp.binmode
          temp.write(entry)
          temp.close

          vm.communicate.upload(temp.path, "/tmp/vagrant-network-entry")

          # Configure the interface
          vm.communicate.sudo("ln -fs /etc/init.d/net.lo /etc/init.d/net.eth#{network[:interface]}")
          vm.communicate.sudo("/etc/init.d/net.eth#{network[:interface]} stop 2> /dev/null")
          vm.communicate.sudo("cat /tmp/vagrant-network-entry >> /etc/conf.d/net")
          vm.communicate.sudo("rm /tmp/vagrant-network-entry")
          vm.communicate.sudo("/etc/init.d/net.eth#{network[:interface]} start")
        end
      end

      def change_host_name(name)
        if !vm.communicate.test("sudo hostname --fqdn | grep '#{name}'")
          vm.communicate.sudo("echo 'hostname=#{name.split('.')[0]}' > /etc/conf.d/hostname")
          vm.communicate.sudo("sed -i 's@^\\(127[.]0[.]0[.]1[[:space:]]\\+\\)@\\1#{name} #{name.split('.')[0]} @' /etc/hosts")
          vm.communicate.sudo("hostname #{name.split('.')[0]}")
        end
      end
    end
  end
end
