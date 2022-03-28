=============================<br/>

Flight Surety Dapp set up instructions.<br/>

=============================<br/>

The boilerplate code provided was using 4 year old dependency versions and proved too painfull to get working. After sepending days trying everything 
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
  
If you are using Ganache-ui, you won't need to change anything, but if using ganache cli, you will need to change the network address
in truffle-config.js and 2_deploy_contracts.js (in the migrations folder)<br/>

you will need a minimum of 40 accounts as 30 oracles will be generated when running the server (I was testing using 100 accounts).

With ganache up and running, navigate back to the FlightSurety-Assignment project folder.<br/>
  
Truffle compile and migrate, 4 .json files should be generated, one in the server folder and 3 in the json_config folder.
  
Open an new terminal, navigate into the FLightSurety_Dapp project folder and enter: npm run server. The server launches on localhost:8000<br />

The server boots up and generates 30 oracles... This is where you 'may' find, due to an issue with ganache, the generateOracle call reverts
before all oracles are generated. This only happens when you load a fresh instance of ganache... Type truffle migrate --reset then restart the server... you may need to do this several times before it generates all 30. Once it has generated them all once, it will generate them every time (till you start a fresh instance of ganache).

I've noticed a few people in the Udacity Knowledge section have had the same issue but there wasn't a solution advised at all.

Once the server has generated the oracles, it will then sit and wait for event calls.

Open a new terminal, navigate into the FlightSurety_Dapp project folder and type: npm run dapp. The next app will launch on localhost: 3000.

=============================<br />

Working the Dapp

=============================<br />

The app will initialize on start. It checks for registered oracles. These are listed on the right and are there for display purposes.

The idea with the app is to select an address from the lefthand sidebar. It is divided into registered airlines, passengers and free accounts.

When submitting for a flight update, the flight will only dissapear if the update time has passed the flight time, at which point the flight closes.

If the flight closed 'late: airline', the passenger will stay in the passenger box until the owed insurance ether has been claimed.

Once 4 airlines are registered and paid up their 10 ether, they can add a new airline, and participate in registration consensus.

=================================<br />





