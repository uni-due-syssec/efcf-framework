pragma solidity 0.7.6;

interface Callback {
    function call(bytes calldata data) external;
}

contract TownCrier{
    mapping(uint => address payable) requesters;
    mapping(uint => uint) fees;
    mapping(uint => address) callbacks;
    mapping(uint => bytes) callbackFIDs;
    mapping(uint => bytes32) paramsHashes;
    
    address payable SGX_ADDR;
    
    uint GAS_PRICE = 1000;
    uint MIN_FEE = 10000;
    uint CANCEL_FEE = 10000;
    
    uint public constant CANCELLED_FEE_FLAG = uint(-1);
    uint public constant DELEVERERED_FEE_FLAG = uint(-2);
    uint public constant FAIL_FLAG = uint(-1);
    /* uint public constant SUCC_FLAG = 0; */

    address constant EMPTY_ADDR = address(0);
    
    bool killswitch = false;
    
    uint requestCnt = 0;
    uint unrespondedCnt = 0;
    
    address public newVersion;
    
    constructor() payable {
        requestCnt = 1;
        requesters[0] = msg.sender;
        killswitch = false;
        unrespondedCnt = 0;
    }
    
    function upgrade(address newAddr) public {
        require (msg.sender == requesters[0] && unrespondedCnt == 0);
            newVersion = newAddr;
            killswitch = true;
    }
    
    function reset(uint price, uint minGas, uint cancelGas) public {
        require(msg.sender == requesters[0] && unrespondedCnt == 0);
            GAS_PRICE = price;
            MIN_FEE = price * minGas;
            CANCEL_FEE = price * cancelGas;
    }
    
    function suspend() public {
        require(msg.sender == requesters[0]);
            killswitch = true;
    }
    
    function restart() public {
        require(msg.sender == requesters[0] && newVersion == EMPTY_ADDR); 
            killswitch = false;
    }
    
    function withdraw() public {
        require(msg.sender == requesters[0] && unrespondedCnt == 0);
        payable(requesters[0]).transfer(address(this).balance);
    }
    
    function request(address cb, bytes memory callbackFID, uint timestamp,
                     bytes memory requestData) public payable returns(bool, uint) {
        address payable gUser = payable(msg.sender);
        uint paid = msg.value;
        
        if (killswitch) {
            gUser.transfer(msg.value);
            return (false, 0);
        }
        
        if (paid < MIN_FEE) {
            return (false, 0);
        }
        
        uint requestId = requestCnt;
        requestCnt = requestCnt + 1;
        unrespondedCnt = unrespondedCnt + 1;
        
        bytes32 paramsHash = keccak256(requestData);
        requesters[requestId] = gUser;
        fees[requestId] = msg.value;
        callbacks[requestId] = cb;
        callbackFIDs[requestId] = callbackFID;
        paramsHashes[requestId] = paramsHash;
        
        return (true, requestId);
    }
    
    function deliver(uint requestId, bytes32 paramsHash, uint error, bytes
                     memory data) public {
        address sender = msg.sender;
        
        if (sender != SGX_ADDR ||
            requestId <= 0 ||
            requesters[requestId] == EMPTY_ADDR ||
            fees[requestId] == DELEVERERED_FEE_FLAG) {
            return;
        }
        
        uint fee = fees[requestId];
        
        if (paramsHashes[requestId] != paramsHash) {
            return;
        }
        
        if (fee == CANCELLED_FEE_FLAG) {
            SGX_ADDR.transfer(CANCEL_FEE);
            fees[requestId] = DELEVERERED_FEE_FLAG;
            unrespondedCnt = unrespondedCnt - 1;
            return;
        }
        
        fees[requestId] = DELEVERERED_FEE_FLAG;
        unrespondedCnt = unrespondedCnt - 1;
        
        if (error < 2) {
            Callback cb = Callback(callbacks[requestId]);
            cb.call(data);
            SGX_ADDR.transfer(fee);
        } else {
            requesters[requestId].transfer(fee);
        }
    }
    
    function cancel(uint requestId) public returns(bool) {
        address sender = msg.sender;
        
        if (killswitch) {
            return false;
        }
        
        uint id = requestId;
        uint fee = fees[id];
        
        if (requesters[id] == sender && fee >= CANCEL_FEE) {
            fees[id] = CANCELLED_FEE_FLAG;
            msg.sender.transfer(fee - CANCEL_FEE);
            return true;
        } else {
            return false;
        }
    }
}
