Vagrant.configure("2") do |config|
  config.vm.box = "hashicorp-education/ubuntu-24-04"
  config.vm.box_version = "0.1.0"

  config.vm.define "cicd" do |cicd|
    cicd.vm.hostname = "cicd"
    cicd.vm.network "private_network", ip: "192.168.56.110"

    # Provision automatique
    cicd.vm.provision "shell",
      path: "script/setup.sh",
      env: { "GITHUB_TOKEN" => ENV["GITHUB_TOKEN"] }
  end
end
