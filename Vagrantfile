Vagrant.configure("2") do |config|
  config.vm.box = "hashicorp-education/ubuntu-24-04"
  config.vm.box_version = "0.1.0"

  config.vm.define "cicd" do |cicd|
    cicd.vm.hostname = "cicd"
    cicd.vm.network "private_network", ip: "192.168.56.110"

    # Forwarding ports
    cicd.vm.network "forwarded_port", guest: 9090, host: 9090, auto_correct: true
    cicd.vm.network "forwarded_port", guest: 30088, host: 30088, auto_correct: true
    cicd.vm.network "forwarded_port", guest: 32080, host: 32080, auto_correct: true
    cicd.vm.network "forwarded_port", guest: 32514, host: 32514, auto_correct: true

    cicd.vm.synced_folder ".", "/vagrant"

    cicd.vm.provider "virtualbox" do |vb|
      vb.name = "ArgoCD-CICD"
      vb.memory = 8192
      vb.cpus = 4
    end

    cicd.vm.provision "shell",
      path: "script/setup.sh",
      env: {
        "GITHUB_TOKEN" => ENV["GITHUB_TOKEN"],
        "NGROK_AUTHTOKEN" => ENV["NGROK_AUTHTOKEN"]
      }
  end

  # 🕐 Augmente le temps d’attente de démarrage à 10 minutes
  config.vm.boot_timeout = 600
end