#!bin/bash

echo "Destroying yandex cloud..."
rm -r certs
rm -r logs
rm -r config
rm ./ansible/inventory

cd ./terraform/
echo "yes" | terraform destroy
cd -
echo "Finished!"
