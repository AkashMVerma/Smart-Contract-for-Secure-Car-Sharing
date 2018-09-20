pragma solidity ^0.4.19;

contract SmartContractCrypto{
    address public carOwner;
    address public currentDriverAddress;
    uint public ownerBalance;
    uint public clientBalance; 
    uint public extraTime; 
    uint public ownerDeposit;
    uint public clientDeposit;
    uint public balanceToDistribute;
    uint driveStartTime = 0;
    uint driveRequiredEndTime = 0;
    uint constant RATE = 5 ether; 
    bool carIsReady = false;
    bool carFree = false;
    bool ownerReady = false;
    bool clientReady = false;
    uint pickLocation = 0;
    uint dropLocation = 0;
    uint timestamp;
    bytes public accessToken;
    
    DriverInformation currentDriverInfo;
    CarStatus currentCarStatus;
    
    enum DriverInformation{
        Owner,
        Customer,
        None
    }
    
    enum CarStatus{
        Idle,
        Busy,
        Unavailable
    }
    
    modifier carReady{
        assert(carIsReady);
        _;
    }
    
    modifier clientAgrees{
        assert(clientReady);
        _;
    }
    
    modifier ownerAgrees{
        assert(ownerReady);
        _;
    }
    
    modifier tripEnded{
        assert(carFree);
        _;
    }
    
    event E_RentCar(address indexed _currentDriverAddress, uint _rentValue, uint _rentStart, uint rentEnd);
    event E_EndRentCar(address indexed _currentDriverAddress, uint _rentalEnd, bool _endWithinPeriod);
    
    function SmartContractCrypto(address _owner) payable public{
        assert(msg.value == 5 ether);
        carOwner = _owner;
        ownerDeposit = msg.value;
        currentDriverInfo = DriverInformation.None;
        currentCarStatus = CarStatus.Idle;
        carIsReady = true;
    }
    
    /**to ensure no replication of signature**/
    
    string public signPrefix = "SignedBooking";
    
    //keccak256 is a hash function ethereum uses. prefixHash is used to generate a prefixhash of the address
    
    function prefixHash(address _customer) public constant returns(bytes32) {
        bytes32 hash = keccak256(signPrefix,
        address(this), _customer);
        return hash;
    }
    
    function detailHash(address _customer) public constant returns(bytes32) {
        bytes32 hash = keccak256(accessToken,
        address(this), _customer);
        return hash;
    }
    
    function isSignatureValid(address _customer, uint8 v, bytes32 r, bytes32 s) view public returns(bool correct) {
        bytes32 mustBeSigned = prefixHash(_customer);
        address signer = ecrecover(mustBeSigned, v, r, s);
        
        return(signer == carOwner);
    }
    
    function sendEncryptedDetails(bytes bookingDetails) public{
        accessToken = bookingDetails;
    }
    
    
    
    function setRequiredDays(uint requiredDays) public{
        driveRequiredEndTime = requiredDays;
    }
    
     function isBookingValid(address _customer, uint8 v, bytes32 r, bytes32 s) view public returns(bool correct) {
        bytes32 mustBeSigned = detailHash(_customer);
        address signer = ecrecover(mustBeSigned, v, r, s);
        
        return(signer == carOwner);
    }
    
    function rentCar(address _customer, uint8 v, bytes32 r, bytes32 s, uint8 v2, bytes32 r2, bytes32 s2) public carReady payable{
            require(currentCarStatus==CarStatus.Idle);
            require(currentDriverInfo == DriverInformation.None);
            require(isSignatureValid(_customer, v, r, s) == true);
            require(isBookingValid(_customer,v2,r2,s2) == true);
            assert(msg.value == RATE);
            currentDriverAddress = _customer;
            currentDriverInfo = DriverInformation.Customer;
            currentCarStatus = CarStatus.Busy;
            driveStartTime = now;
            clientDeposit = msg.value;
            E_RentCar(currentDriverAddress, msg.value, driveStartTime, driveRequiredEndTime);
    }
    
    bool allowCarUse = false;
    
    function allowCarUsage(address _user) public carReady{
        require(_user == carOwner);
        allowCarUse = true;
    }
    
    bool canAccess = false;
    
    function accessCar(address _user) public carReady{
            require(_user == currentDriverAddress);
            require(allowCarUse);
            canAccess = true;
    }
    
    function nonAccessWithdrawal(address _user) public carReady{
            assert(_user == currentDriverAddress);
            assert(canAccess==false);
            clientBalance = ownerDeposit + clientDeposit;
            msg.sender.transfer(clientBalance);
            ownerBalance = 0;
        
    }
    
    function cancelBooking(address _user) public carReady{
        if(_user == carOwner && allowCarUse == false){
            currentCarStatus = CarStatus.Idle;
            currentDriverInfo = DriverInformation.None;
            //msg.sender.transfer(ownerDeposit);
            currentDriverAddress.transfer(clientDeposit);
        }
        else if(_user == currentDriverAddress && canAccess == false){
            currentCarStatus = CarStatus.Idle;
            currentDriverInfo = DriverInformation.None;
            msg.sender.transfer(clientDeposit);
            //carOwner.transfer(ownerDeposit);
        }
        else if(_user == currentDriverAddress && canAccess == true){
            currentCarStatus = CarStatus.Idle;
            currentDriverInfo = DriverInformation.None;
            msg.sender.transfer(clientDeposit - 500000000000000000);
            ownerDeposit+=500000000000000000;
        }
        else if(_user==carOwner && allowCarUse == true){
            currentCarStatus = CarStatus.Idle;
            currentDriverInfo = DriverInformation.None;
            ownerDeposit = ownerDeposit - 500000000000000000;
            currentDriverAddress.transfer(clientDeposit + 500000000000000000);
        }
        
    }
    
    bool extraTimeTaken = false;
    
    function setExtraTimeTaken(uint extraTijd) public {
        extraTime = extraTijd;
        extraTimeTaken = true;
    }
    
    function endRentCar() public carReady{
        assert(currentCarStatus == CarStatus.Busy);
        assert(currentDriverInfo == DriverInformation.Customer);
        
        balanceToDistribute = RATE - 3.5 ether;
        
        if(extraTimeTaken==true && (driveRequiredEndTime + extraTime) < 4){
            balanceToDistribute += extraTime * 500000000000000000; //0.5 ether for each extra day
        }
        
        if(extraTimeTaken==true && (driveRequiredEndTime + extraTime) >= 4){
           assert(msg.sender == carOwner);
           E_EndRentCar(currentDriverAddress, now, false);
           clientBalance = 0 ether;
           ownerBalance = clientDeposit + ownerDeposit;
           msg.sender.transfer(ownerBalance);
           currentDriverAddress = address(0);
           currentCarStatus = CarStatus.Idle;
           currentDriverInfo = DriverInformation.None;
           driveStartTime = 0;
           driveRequiredEndTime = 0;
        }
        else
        {
            assert(msg.sender == currentDriverAddress);
            E_EndRentCar(currentDriverAddress, now, true);
        
            currentCarStatus = CarStatus.Idle;
            currentDriverInfo = DriverInformation.None;
            driveStartTime = 0;
            driveRequiredEndTime = 0;
            clientReady = true;
            ownerReady = true;
            carFree = true;
            distributeEarnings();
        }
        
    }
    
     function distributeEarnings() internal carReady{
        ownerBalance = ownerDeposit + balanceToDistribute;
        clientBalance = 5 ether - balanceToDistribute;
        
    }
    
    function triggerDistributeEarnings() public carReady{
        assert(balanceToDistribute > 0);
        bool isOwner = false;
        if(carOwner == msg.sender){
            isOwner=true;
        }
        assert(isOwner);
        distributeEarnings();
    }
    
    function withdrawEarnings(address _user) public ownerAgrees clientAgrees tripEnded{
        if(_user == carOwner){
        assert(msg.sender == carOwner);
        msg.sender.transfer(ownerBalance);
        ownerBalance = 0;
        }
        else if(_user == currentDriverAddress){
            assert(msg.sender == currentDriverAddress);
            msg.sender.transfer(clientBalance);
            currentDriverAddress = address(0);
            clientBalance = 0;
        }
        
    }
    
    
}