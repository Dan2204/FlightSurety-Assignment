const FlightSuretyApp = artifacts.require('FlightSuretyApp');
const FlightSuretyData = artifacts.require('FlightSuretyData');
const fs = require('fs');
const root = '/../flightsurety_app/pages/';

module.exports = function (deployer) {
  deployer.deploy(FlightSuretyData).then(() => {
    return deployer.deploy(FlightSuretyApp, FlightSuretyData.address).then(() => {
      let config = {
        localhost: {
          url: 'http://localhost:7545',
          dataAddress: FlightSuretyData.address,
          appAddress: FlightSuretyApp.address,
        },
      };
      // WRITE CONFIG TO PAGES/JSON_CONFIG //
      fs.writeFileSync(
        __dirname + root + 'json_config/config.json',
        JSON.stringify(config, null, '\t'),
        'utf-8'
      );
      // WRITE CONFIG TO PAGES/SERVER //
      fs.writeFileSync(
        __dirname + root + 'server/config.json',
        JSON.stringify(config, null, '\t'),
        'utf-8'
      );
      // WRITE FSD ABI TO PAGES/JSON_CONFIG //
      fs.writeFileSync(
        __dirname + root + 'json_config/fsData_ABI.json',
        JSON.stringify(FlightSuretyData.abi, null, '\t'),
        'utf-8'
      );
      // WRITE FSA ABI TO PAGES/JSON_CONFIG //
      fs.writeFileSync(
        __dirname + root + 'json_config/fsApp_ABI.json',
        JSON.stringify(FlightSuretyApp.abi, null, '\t'),
        'utf-8'
      );
    });
  });
};
