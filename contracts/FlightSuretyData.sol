// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract FlightSuretyData {
  

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;
    bool private operational = true;

    struct Caller {
      address callerAddress;
      address backUp;
    }
    Caller private authorizedCaller;

    // AIRLINE DATA //
    uint constant private MIN_REGISTERED_AIRLINES = 4;

    struct Airline {
        string name;
        bool isRegistered;
        bool canParticipate;
        uint numberOfPayouts;
    }
    address[] private registeredAirlines;
    uint private participatingCount;
    mapping(address => Airline) private airlines;

    mapping(address => address[]) private airlineConsensus;
    address[] public consensusList;

    // CUSTOMER DATA //
    struct Customer {
        address customerAddress;
        address airline;
        string flightNumber;
        uint timestamp;
        uint balance;
        uint owed;
    }
    mapping (bytes32 => Customer[]) private insuredFlights;
    bytes32[] private insuredFlightsList;


    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    event AirlineConsensusVote(address airline, uint votes, uint votesTillApproved);
    event AirlineRegistration(address airline, string name);

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    modifier requireIsOperational() {
        require(operational, "Contract is currently not operational");    
        _;
    }

    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier isAuthorizedCaller() {
      require(msg.sender == authorizedCaller.callerAddress, "Not authorized");
      _;
    }

    // CALLED FROM FLIGHTSURETY APP SO NEED ORIGINAL CALLER //
    modifier isRegisteredAirline(address _caller) {
        require(airlines[_caller].isRegistered, "Not a registered Airline");
        _;
    }

    // CALLED FROM FLIGHTSURETY APP SO NEED ORIGINAL CALLER //
    modifier canParticipate(address _caller) {
        require(airlines[_caller].canParticipate, "Caller can't participate until 10 ether has been funded");
        _;
    }

    modifier requiredValue {
      require(msg.value >= 10 ether, "Insufficient Ether Sent. Requires 10 ether");
      _;
    }

    modifier maxInsuranceDeposit {
        require(msg.value <= 1 ether && msg.value > 0, "Can only deposit upto 1 ether");
        _;
    }


    /**************************************************************************************/
    /*                                       CONSTRUCTOR                                  */
    /**************************************************************************************/

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor() {
        contractOwner = msg.sender;
        // REGISTER 1st AIRLINE //
        airlines[msg.sender] = Airline({ name: 'BA', isRegistered: true, canParticipate: false, numberOfPayouts: 0 });
        registeredAirlines.push(msg.sender);
        participatingCount = 0;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function getContractBalance() external requireContractOwner returns (uint) {
      return address(this).balance;
    }

    function getContractOwner() public view returns (address) {
      return contractOwner;
    }
    
    function authorizeCaller(address _authAddress) external {
      if (authorizedCaller.callerAddress != address(0)) {
        require(authorizedCaller.callerAddress == msg.sender ||
                authorizedCaller.backUp == msg.sender, "Invalid Code");
      }
      authorizedCaller.callerAddress = _authAddress;
      authorizedCaller.backUp = msg.sender;
    }

    function isContractAuthorized() public view returns (bool) {
      return authorizedCaller.callerAddress != address(0);
    }

    function getInsuredFlights() external view returns (bytes32[] memory) {
        return insuredFlightsList;
    }

    function getInsuredCount(bytes32 flight) external view returns (uint) {
        return insuredFlights[flight].length;
    }

    function getInsuree(bytes32 flight, uint _index) external view
      returns (
        address customerAddress,
        address airline,
        string memory flightNumber,
        uint timestamp,
        uint balance,
        uint owed
      ) {
        require(_index < insuredFlights[flight].length, "Error: Insuree doesn't exist");
        Customer memory insuree = insuredFlights[flight][_index];
        customerAddress = insuree.customerAddress;
        airline = insuree.airline;
        flightNumber = insuree.flightNumber;
        timestamp = insuree.timestamp;
        balance = insuree.balance;
        owed = insuree.owed;
    }

    function isOperational() public view returns (bool) {
        return operational;
    }

    function setOperatingStatus(bool mode) external isAuthorizedCaller requireContractOwner {
        operational = mode;
    }

    function isAirline(address _airline) public view returns (bool) {
        return airlines[_airline].canParticipate;
    }

    function getRegisteredAirlines() public view returns (address[] memory) {
        return registeredAirlines;
    }
    
    function getAirline(address _airline) 
      external 
      view 
      returns (
        address _airlineAddress, 
        string memory _name, 
        bool _isRegistered, 
        bool _canParticipate,
        uint _numberOfPayouts
        ) {
        Airline storage airline = airlines[_airline];
        _airlineAddress = _airline;
        _name = airline.name;
        _isRegistered = airline.isRegistered;
        _canParticipate = airline.canParticipate;
        _numberOfPayouts = airline.numberOfPayouts;
      }

      function getConsensusList() public view returns (address[] memory) {
        return consensusList;
      }

      function getNumVotes(address _airline) public view returns (uint) {
        return airlineConsensus[_airline].length;
      }
    
    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline(string memory _name, address _airline, address _caller) 
        external
        requireIsOperational
        isAuthorizedCaller
        isRegisteredAirline(_caller)
        canParticipate(_caller)
        returns (bool success, uint votes)
        {
            require(!airlines[_airline].isRegistered, "Airline is already registered");
            require(bytes(_name).length > 0 && _airline != address(0), "Invalid name or address");
            // CHECK IF AMOUNT OF REGISTERED AIRLINES HAS REACHED THE REQUIRED VALUE //
            if (registeredAirlines.length < MIN_REGISTERED_AIRLINES) {
                require(registeredAirlines[0] == _caller, "Caller can't register new airlines yet");
                airlines[_airline] = Airline(
                    { 
                        name: _name, 
                        isRegistered: true, 
                        canParticipate: false, 
                        numberOfPayouts: 0 
                    }
                );
                registeredAirlines.push(_airline);
                emit AirlineRegistration(_airline, _name);
                success = true;
                votes = 1;
            // RUN THROUGH CONSENSUS REGISTRATION //
            } else {
                // CHECK IF CALLER HAS ALREADY REGISTERED THIS AIRLINE //
                bool isDuplicate = false;
                for (uint i = 0; i < airlineConsensus[_airline].length; i++) {
                    if (airlineConsensus[_airline][i] == _caller) {
                        isDuplicate = true;
                        break;
                    }
                }
                require(!isDuplicate, "Caller has already registered this airline");
                // ADD CALLER TO CONENSUS FOR _airline //
                if(airlineConsensus[_airline].length < 1) {
                  consensusList.push(_airline);
                }
                airlineConsensus[_airline].push(_caller);
                votes = airlineConsensus[_airline].length;
                // CHECK IF _airline HAS REACHED 50% CONSENSUS REQUIREMENT //
                if (votes >= participatingCount / 2) {
                    airlines[_airline] = Airline(
                        { 
                            name: _name, 
                            isRegistered: true, 
                            canParticipate: false,
                            numberOfPayouts: 0 
                        }
                    );
                    registeredAirlines.push(_airline);
                    delete airlineConsensus[_airline];
                    for (uint i = 0; i < consensusList.length; i++) {
                      if (consensusList[i] == _airline) {
                        delete consensusList[i];
                        break;
                      }
                    }
                    emit AirlineRegistration(_airline, _name);
                    success = true;
                } else {
                    uint votesTillApproved = (registeredAirlines.length / 2) - airlineConsensus[_airline].length;
                    emit AirlineConsensusVote(_airline, airlineConsensus[_airline].length, votesTillApproved);
                    success = false;
                }
            }
    }

   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy(string memory _flightNumber, address _airline, uint256 _timestamp) 
        external 
        payable 
        requireIsOperational
        maxInsuranceDeposit 
        isRegisteredAirline(_airline)
        returns (bytes32 flightHash, uint id) 
        {
            flightHash = getFlightKey(_airline, _flightNumber, _timestamp);
            bool duplicate = false;
            for (uint i = 0; i < insuredFlights[flightHash].length; i++) {
              if (insuredFlights[flightHash][i].customerAddress == msg.sender) {
                duplicate = true;
                break;
              }
            }
            require(!duplicate, "Caller has already insured");
            Customer memory insuree = Customer(
                {
                    customerAddress: msg.sender,
                    airline: _airline,
                    flightNumber: _flightNumber,
                    timestamp: _timestamp,
                    balance: msg.value,
                    owed: 0
                }
            );
            insuredFlights[flightHash].push(insuree);
            if (insuredFlights[flightHash].length < 2) {
              insuredFlightsList.push(flightHash);
            }
            id = insuredFlights[flightHash].length;
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees(string memory _flightNumber, address _airline, uint256 _timestamp) 
        external
        isAuthorizedCaller
        requireIsOperational
        {
            bytes32 flightHash = getFlightKey(_airline, _flightNumber, _timestamp);
            uint payouts = insuredFlights[flightHash].length;
            airlines[_airline].numberOfPayouts += payouts;
            for (uint i = 0; i < payouts; i++) {
                uint balance = insuredFlights[flightHash][i].balance;
                uint payout = balance + (balance / 2);
                insuredFlights[flightHash][i].owed = payout;
                insuredFlights[flightHash][i].balance = 0;
            }
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay(bytes32 _flight, uint _index) external {
        require(insuredFlights[_flight][_index].owed > 0, "There is nothing to withdraw.");
        require(insuredFlights[_flight][_index].customerAddress == msg.sender, "Not Authorized");
        uint balance = insuredFlights[_flight][_index].owed;
        insuredFlights[_flight][_index].owed = 0;
        payable(msg.sender).transfer(balance);
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund() public payable isRegisteredAirline(msg.sender) requiredValue {
        require(!airlines[msg.sender].canParticipate, "Caller has already deposited funds");
        airlines[msg.sender].canParticipate = true;
        participatingCount++;
    }

    function getFlightKey(address airline, string memory flight, uint256 timestamp)
        pure
        internal
        returns (bytes32) {

        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    fallback() external payable {
        fund();
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    receive() external payable {
        fund();
    }
}

