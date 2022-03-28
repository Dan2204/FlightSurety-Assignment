// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {

    // SAFEMATH NOT REQUIRED FOR ANYTHING AFTER 0.8.0 //

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint256 private constant STATUS_CODE_UNKNOWN = 0;
    uint256 private constant STATUS_CODE_ON_TIME = 10;
    uint256 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint256 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint256 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint256 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner;

    // DECLARE VARIABLE TO HOLD THE DATA CONTRACT //
    IFlightSurety public flightSuretyData;

    struct Flight {
        bool isRegistered;
        uint256 statusCode;
        uint256 flightTime;
        uint256 updatedTimestamp;        
        address airline;
        string flightNumber;
    }
    mapping(bytes32 => Flight) private flights;
    Flight[] private allFlightList;
    uint public flightCount;

 
    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(isOperational(), "Contract is currently not operational");  
        _;
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor(address payable contractAddress) {
        contractOwner = msg.sender;
        flightSuretyData = IFlightSurety(contractAddress);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() public view returns (bool) {
        return flightSuretyData.isOperational();
    }

    function getContractBalance() external requireContractOwner returns (uint) {
      return address(this).balance;
    }

    function getAppOwner() external view returns(address) {
        return contractOwner;
    }

    function authorizeContract(address _contractAddress) external requireContractOwner {
      flightSuretyData.authorizeCaller(_contractAddress);
    }

    function isContractAuthorized() external returns (bool) {
      return flightSuretyData.isContractAuthorized();
    }

    function getFlight(address _airline, string memory _flightNumber, uint256 _timeStamp)
        external 
        view
        returns (
          address airline, 
          string memory flightNumber, 
          uint256 flightTime,
          uint256 latestTimeStamp,
          uint256 statusCode,
          bool isRegistered
          ){
            bytes32 key = getFlightKey(_airline, _flightNumber, _timeStamp);
            // require(flights[key].isRegistered, "Flight not registered");
            Flight memory flight = flights[key];
            airline = flight.airline;
            flightNumber = flight.flightNumber;
            flightTime = flight.flightTime;
            latestTimeStamp = flight.updatedTimestamp;
            statusCode = flight.statusCode;
            isRegistered = flight.isRegistered;
    }

    function getFlight(uint index) 
      external 
      view 
      requireContractOwner
      returns (
        address airline,
        string memory flightNumber,
        uint256 flightTime,
        uint256 latestTimestamp,
        uint256 statusCode,
        bool isRegistered
        ){
          require(index < flightCount, "Index out of bounds");
          Flight memory flight = allFlightList[index];
          airline = flight.airline;
          flightNumber = flight.flightNumber;
          flightTime = flight.flightTime;
          latestTimestamp = flight.updatedTimestamp;
          statusCode = flight.statusCode;
          isRegistered = flight.isRegistered;
        }


    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

  
   /**
    * @dev Add an airline to the registration queue
    *
    */   
    function registerAirline(string memory _name, address _airline) 
      external 
      requireIsOperational
      returns (bool success, uint votes) {

        (success, votes) = flightSuretyData.registerAirline(_name, _airline, msg.sender);
    }


   /**
    * @dev Register a future flight for insuring.
    *
    */  
    function registerFlight(
        address _airline, 
        string memory _flightNumber, 
        uint256 _timeStamp
        ) 
        external requireIsOperational 
        {
            require(flightSuretyData.isAirline(_airline));
            bytes32 key = getFlightKey(_airline, _flightNumber, _timeStamp);
            Flight memory newFlight = Flight(
                {
                    isRegistered: true,
                    statusCode: STATUS_CODE_UNKNOWN,
                    flightTime: _timeStamp,
                    updatedTimestamp: 0,
                    airline: _airline,
                    flightNumber: _flightNumber
                }
            );
            flights[key] = newFlight;
            allFlightList.push(newFlight);
            flightCount++;
    }
    
    event FlightClosed(address airline, string flight, uint256 timestamp, uint256 statusCode);
    event FlightUpdated(address airline, string flight, uint256 timestamp);
   /**
    * @dev Called after oracle has updated flight status
    *
    */  
    function processFlightStatus(address airline, string memory flight, uint256 timestamp, uint256 statusCode)
        internal {
            require(isOperational(), "Unable to proccess at this time");
            bytes32 key = getFlightKey(airline, flight, timestamp);
            require(flights[key].isRegistered, "Flight not registered");
            // UPDATE FLIGHT //
            uint index;
            for (uint i = 0; i < allFlightList.length; i++) {
              bytes32 keyHash = getFlightKey(allFlightList[i].airline, allFlightList[i].flightNumber, allFlightList[i].flightTime);
              if (key == keyHash) {
                flights[key].statusCode = statusCode;
                flights[key].updatedTimestamp = block.timestamp;
                allFlightList[i] = flights[key];
                index = i;
                break;
              }
            }
            oracleResponses[key].isOpen = false;
            // CHECK IF THE CURRENT TIME IS PAST THE FLIGHT TIME //
            if (flights[key].updatedTimestamp > timestamp) {
                flights[key].isRegistered = false;
                allFlightList[index] = flights[key];
                if (statusCode == STATUS_CODE_LATE_AIRLINE) {
                  flightSuretyData.creditInsurees(flight, airline, timestamp);
                }
                emit FlightClosed(airline, flight, timestamp, statusCode);
            } else {
              emit FlightUpdated(airline, flight, timestamp);
            }
    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus(address airline, string memory flight, uint256 timestamp) external {
        // CHECK FLIGHT IS REGISTERED //
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        require(flights[flightKey].isRegistered, "Flight isn't registered");

        // GENERATE REQUEST //
        uint8 index = getRandomIndex(msg.sender);
        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key].requester = msg.sender;
        oracleResponses[key].isOpen = true;

        // EMIT REQUEST //
        emit OracleRequest(index, airline, flight, timestamp);
    } 



                        //////////////////////////////
                        // region ORACLE MANAGEMENT //
                        //////////////////////////////

    uint8 private nonce = 0;
    uint256 public constant REGISTRATION_FEE = 1 ether;
    uint256 private constant MIN_RESPONSES = 3;

    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;   
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;
    address[] private oracleList;
    uint public oracleCount;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;
        bool isOpen;
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;
    // Track all response codes //
    // Key = hash(index, flight, timestamp), key2 = responseCode, array = addresses with key2 //
    mapping(bytes32 => mapping (uint256 => address[])) private responseCodes;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint256 status);
    event OracleReport(address airline, string flight, uint256 timestamp, uint256 status, address oracle);
    event InsufficientData(address airline, string flight, uint256 timestamp, uint256 status, address oracle);
    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 indexed index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle() external payable returns (uint) {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");
        require(!oracles[msg.sender].isRegistered, "Oracle is already registered");
        uint8[3] memory indexes = generateIndexes(msg.sender);
        Oracle memory newOracle = Oracle(
            {
                isRegistered: true,
                indexes: indexes
            }
        );
        oracles[msg.sender] = newOracle;
        oracleList.push(msg.sender);
        oracleCount++;
        return oracleCount;
    }

    function getOracle(uint index) external view returns (address oracleAddress) {
        require(index < oracleCount, "Index out of bounds");
        return oracleList[index];
    }
    
    function getMyIndexes() view external returns (uint8[3] memory) {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");
        
        return oracles[msg.sender].indexes;
    }

    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse(
      uint8 index, 
      address airline, 
      string memory flight, 
      uint256 timestamp, 
      uint256 statusCode) 
      external  {
        require((oracles[msg.sender].indexes[0] == index) || 
                (oracles[msg.sender].indexes[1] == index) || 
                (oracles[msg.sender].indexes[2] == index), 
                "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        responseCodes[key][statusCode].push(msg.sender);
        emit OracleReport(airline, flight, timestamp, statusCode, msg.sender);

        //// CHECK IF REQUIRED RESPONSES HAVE BEEN REACHED TO PROCCESS ////
        //// AND ONLY PROCESS IF IT'S THE GREATEST NUMBER OF THE SAME CODE ////
        if (responseCodes[key][statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        } else {
          emit InsufficientData(airline, flight, timestamp, statusCode, msg.sender);
        }
    }


    function getFlightKey(address airline, string memory flight, uint256 timestamp) pure internal returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-7
    function generateIndexes(address account) internal returns (uint8[3] memory) {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }
        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }
        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-7
    function getRandomIndex(address account) internal returns (uint8) {
        uint8 maxValue = 8;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}

interface IFlightSurety {
    function registerAirline(string memory _name, address _airline, address _caller) external 
        returns (bool success, uint votes);
    function isOperational() external view returns (bool);
    function creditInsurees(string memory _flightNumber, address _airline, uint256 _timestamp) external;
    function isAirline(address _airline) external returns (bool);
    function authorizeCaller(address _contractAddress) external;
    function isContractAuthorized() external returns (bool);
}
