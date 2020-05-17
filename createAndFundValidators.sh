#!/bin/bash

declare -i startValidator=0
declare -i endValidator=5

Eth1GoerliAccount="0x0000000000000000000000000000000000000000"
Eth1GoerliPassword="test"

walletName="Validators"  # Name of account containing the wallets
validatorPassword="test"

safeMode=true # In case safe mode is set to "true", existing validator wallets will not be funded, although they might be empty

# Create a list of existing accounts
existingAccounts=$(ethdo wallet accounts --wallet=${walletName})

for i in $(seq ${startValidator} ${endValidator}); do
  # Check every loop if beacon chain is still running (might be sufficient to check once outside of the loop)
  ethdo chain status --quiet
  if  [ ! $? -eq 0 ] ; then
    echo "Beacon chain is offline. Cannot check validators. Exit script"
    exit 1
  fi

  # Check if Goerli account has sufficient balance
  goerliBalance="$(ethereal ether balance --network=goerli --address=${Eth1GoerliAccount} 2>&1)"
  if [ ! $? -eq 0 ] || [[ "${goerliBalance}" == "Failed to obtain address: could not parse address" ]] ; then
    echo "Failed to obtain access to the provided Goerli address:" ${Eth1GoerliAccount}
    echo "Make sure the Goerli address can be located and accessed by 'ethereal'. The following Goerli addresses were detected: "
    echo $(ethereal --network=goerli account list)
    echo "Exit script"
    exit 1
  fi

  # In case a balance was found remove " Ether" from the string and check if the balance is sufficient to fund a validator
  # Also account for a transaction fee
  goerliBalance="${goerliBalance// Ether}"
  if (( $(echo "$goerliBalance < 32.01 " |bc -l) )); then
    echo "Balance from Goerli acount  is too low to add a validator."
    echo "Public key Goerli account: " ${Eth1GoerliAccount}
    echo "Balance: ${goerliBalance} Ether"
    echo "Exit script"
    exit 1
  fi

  # Get id of  validator account
  id=`printf '%05d' ${i}`;
  currentAccount="Validator"${id}

  # Only create the validator account in case the account doesn't exist yet.
  # In case you want to be sure no double deposits are made, you could choose to enable the "continue"
  if ! echo "$existingAccounts" | grep -q "$currentAccount"; then
     echo "Creating account: "${currentAccount}
     ethdo account create --account=${walletName}"/"${currentAccount} --passphrase="${validatorPassword}";
  else
     echo 'Account "'${currentAccount}'" already exists in wallet "'${walletName}'". Do not try to deposit in this account to prevent a double deposit'
     if [ $safeMode = true ] ; then
       continue
     fi
  fi

  # Only create a deposit in case no validator is found
  validatorState="$(ethdo validator info --account=${walletName}"/"${currentAccount}   2>&1)"
  if [[ "${validatorState}" == "Not known as a validator" ]] ; then
        echo "Creating deposit data"
        DEPOSITDATA=`ethdo validator depositdata \
                   --validatoraccount=${walletName}"/"${currentAccount} \
                   --withdrawalaccount=Withdrawal/Primary \
                   --depositvalue=32Ether \
                   --passphrase="${validatorPassword}"`;

        echo 'Sending Goerli transaction'
      	# Submit transaction on Goerli
      	ethereal beacon deposit --network=goerli \
            --data="${DEPOSITDATA}" \
            --from="${Eth1GoerliAccount}" \
            --passphrase="${Eth1GoerliPassword}";
  else
      echo 'Account "'${currentAccount}'" already has a balance, so no depost is created for this account'
  fi
done



