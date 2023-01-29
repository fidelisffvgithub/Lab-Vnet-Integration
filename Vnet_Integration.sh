!/bin/bash
### Autor: Felipe Fidelis
## Script bash para criação de ambiente Vnet Integration.
## O modelo de VM utilizado para esse lab é o Standard_B2s. 
## Verifique a disponibilidade na região que escolher para o lab.
## Utilize o comando abaixo ou simule uma criação no portal. 
## az vm list-skus --size Standard_B2s --output table



let "randomIdentifier=$RANDOM*$RANDOM"
rg="RG-LABV"
loc1="koreacentral"
loc2="francecentral"
vnet1="vnet-lan1"
sub1="sub-lan1"
subv="sub-vintegration"
vnet2="vnet-lan2"
sub2="sub-lan2"
vm1="vm-korea"
vm2="vm-france"
nsg1="nsg-lan1"
nsg2="nsg-lan2"
appplan="appplankorea"
webapp="webappkorea$randomIdentifier"



### Criar Resource Group ###
az group create -l $loc1 -n $rg

### Criar App Plan e App Service ###
az appservice plan create --name $appplan --resource-group $rg --sku s1 
az webapp create -g $rg -p $appplan -n $webapp --runtime "aspnet|v4.8"

### Criar vnet ###
az network vnet create --address-prefixes 10.10.0.0/16 --name $vnet1 --resource-group $rg
az network vnet subnet create -g $rg --vnet-name $vnet1 -n $sub1 --address-prefixes 10.10.0.0/24
az network vnet subnet create -g $rg --vnet-name $vnet1 -n $subv --address-prefixes 10.10.10.0/27

az network vnet create --address-prefixes 192.168.0.0/24 --name $vnet2 --resource-group $rg --location $loc2
az network vnet subnet create -g $rg --vnet-name $vnet2 -n $sub2 --address-prefixes 192.168.0.0/24 

# Criar peering 
az network vnet peering create -n vnetkorea-to-vnetfrance -g $rg --vnet-name $vnet1 --remote-vnet $vnet2 --allow-vnet-access
az network vnet peering create -n vnetfrance-to-vnetkorea -g $rg --vnet-name $vnet2 --remote-vnet $vnet1 --allow-vnet-access




### Criar NSG,regra e asssociar à sub-lan ###
az network nsg create -g $rg -n $nsg1
az network vnet subnet update -g $rg -n $sub1 --vnet-name $vnet1 --network-security-group $nsg1
az network nsg rule create -g $rg --nsg-name $nsg1 -n Allow-80 --access Allow --protocol Tcp --direction Inbound --priority 110 --source-address-prefix "*" --source-port-range "*" --destination-address-prefixes 10.10.0.4 --destination-port-range 80
az network nsg rule create -g $rg --nsg-name $nsg1 -n Allow-3389 --access Allow --protocol Tcp --direction Inbound --priority 120 --source-address-prefix "*" --source-port-range "*" --destination-address-prefixes 10.10.0.4 --destination-port-range 3389

az network nsg create -g $rg -n $nsg2 --location $loc2
az network vnet subnet update -g $rg -n $sub2 --vnet-name $vnet2 --network-security-group $nsg2
az network nsg rule create -g $rg --nsg-name $nsg2 -n Allow-80 --access Allow --protocol Tcp --direction Inbound --priority 110 --source-address-prefix "*" --source-port-range "*" --destination-address-prefixes 192.168.0.4 --destination-port-range 80
az network nsg rule create -g $rg --nsg-name $nsg2 -n Allow-3389 --access Allow --protocol Tcp --direction Inbound --priority 120 --source-address-prefix "*" --source-port-range "*" --destination-address-prefixes 192.168.0.4 --destination-port-range 3389


### Criar VM ###
az vm create --resource-group $rg --name $vm1 --image "Win2016Datacenter" --size Standard_B2s --public-ip-sku Standard --vnet-name $vnet1 --subnet $sub1 --nsg "" --admin-username azwin --admin-password P@ssword123@
az vm create --resource-group $rg --name $vm2 --location $loc2 --image "Win2016Datacenter" --size Standard_B2s --public-ip-sku Standard --vnet-name $vnet2 --subnet $sub2 --nsg "" --admin-username azwin --admin-password P@ssword123@ 


### Instalar IIS nas VMs ###
vms=$(az vm list --resource-group $rg --query "[].name" --output tsv)

for vm_iis in $vms
do
	az vm extension set -n "CustomScriptExtension" --publisher Microsoft.Compute --version 1.8 --vm-name $vm_iis --resource-group $rg --settings '{"commandToExecute":"powershell.exe Install-WindowsFeature -Name Web-Server; Add-Content -Path \"C:\\inetpub\\wwwroot\\Default.htm\" -Value $($env:computername)"}'
done


### Desativar o FW na VM ###
for vm_fw in $vms
do
	az vm run-command invoke  --command-id RunPowerShellScript --name $vm_fw -g $rg --scripts "Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled False" 
done


### Listar recursos ###
echo "#### RECURSOS CRIADOS #####"
az resource list -g $rg --output table





