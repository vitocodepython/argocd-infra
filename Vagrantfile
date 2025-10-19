Vagrant.configure("2") do |config|
  config.vm.box = "hashicorp-education/ubuntu-24-04"
  config.vm.box_version = "0.1.0"

  config.vm.define "cicd" do |cicd|
    cicd.vm.hostname = "cicd"
    cicd.vm.network "private_network", ip: "192.168.56.110"

    # 🔌 Ports exposés
    cicd.vm.network "forwarded_port", guest: 9090, host: 9090, auto_correct: true  # ArgoCD UI
    cicd.vm.network "forwarded_port", guest: 30088, host: 30088, auto_correct: true # vito-app
    cicd.vm.network "forwarded_port", guest: 32080, host: 32080, auto_correct: true # HTTP ArgoCD NodePort
    cicd.vm.network "forwarded_port", guest: 32514, host: 32514, auto_correct: true # HTTPS ArgoCD NodePort

    cicd.vm.synced_folder ".", "/vagrant"

    cicd.vm.provider "virtualbox" do |vb|
      vb.name = "ArgoCD-CICD"
      vb.memory = 8192
      vb.cpus = 4
    end

    #  Délai pour laisser Ubuntu démarrer
    cicd.vm.provision "shell", inline: "sleep 60"

    #  Provision principal — installe tout automatiquement
    cicd.vm.provision "shell",
      path: "script/setup.sh",
      env: {
        "GITHUB_TOKEN" => ENV["GITHUB_TOKEN"],
        "NGROK_AUTHTOKEN" => ENV["NGROK_AUTHTOKEN"]
      }

    #  Reprovision automatique si la VM est redémarrée
    cicd.vm.provision "shell", inline: <<-SHELL
      if [ ! -f /home/vagrant/.setup_done ]; then
        echo "Premier démarrage : exécution du script setup.sh..."
        bash /vagrant/script/setup.sh
        touch /home/vagrant/.setup_done
      else
        echo "La VM a déjà été initialisée. Pour tout réinstaller : vagrant destroy -f && vagrant up"
      fi
    SHELL
  end

  # ⏱ Timeout global de boot
  config.vm.boot_timeout = 600
end
