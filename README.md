=============================<br/>

Flight Surety Dapp set up instructions.<br/>

=============================<br/>

The boilerplate code provided proved too painfull to get working. After sepending days trying everything 
and anything to get it functioning, I gave up and opted to upgrade the solidity code to version 8, and
start from scratch with the dapp. I was able to use snippets from the dapp boilerplate code, i.e. contract.js
and the server.js starting code. Everything else was built from scratch using next.js.

On reflection, the idea in my head was far bigger when put into practice. The code is fully functional but 
due to time restraints, I didn't spend much time on style and responsivness... Definately an app for desktop monitors!

-------------------------------<br/>

Required dependency versions:

  truffle: v5.5.4, <br/>
  node: v16.14.0, <br/>
  ganache: v2.5.4, <br/>
  npm: v8.3.1, <br/>
  solidity: v0.8.0, <br/>
  web3: v1.7.1 <br/>
  
-------------------------------<br/>
  
You will need to clone both this repository and the FlightSurety_Dapp repository (The dapp sits inside the main truffle folder).<br/>

Clone THIS repository first, then cd into the FlightSurety-Assignment project folder.<br/>

Clone the FlightSurety_Dapp repository, then cd into the FLightSurety_Dapp project folder and type: npm install<br/>
  
If you are using Ganache-ui, you won't need to change anything, but if using ganache cli, you will need to change the network
in truffle-config.js and 2_deploy_contracts.js (in the migrations folder)<br/>
you will need a minimum of 40 accounts as 30 oracles will be generated when running the server (I was testing using 100 accounts).

With ganache up and running, navigate back to the <FlightSurety-Assignment> project folder.<br/>
  
truffle compile and migrate, 4 json files should be generated, one in the server folder and 3 in the json_config folder.
  
Open an new terminal, navigate into the <FLightSurety_Dapp> project folder and enter: npm run server<br />

