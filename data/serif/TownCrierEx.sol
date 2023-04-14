pragma solidity 0.7.6;

interface Callback {
    function call(bytes calldata data) external;
}

contract TownCrierEx {
    address requester;
    Callback callback;
    uint FEE;
    address payable SGX_ADDR;
    address constant EMPTY_ADDR = address(0);

    function request(address cb) public payable {
    	address gUser = msg.sender;
        uint paid = msg.value;
        if (msg.value < FEE || requester != EMPTY_ADDR) {
            return;
        }

    	Callback gCb = Callback(cb);
    	
    	requester = gUser;
    	callback = gCb;
    }

    function deliver(bytes memory data) public {
        address sender = msg.sender;
        if (sender != SGX_ADDR || requester == EMPTY_ADDR) {
            return;
        }

        requester = EMPTY_ADDR;
        callback.call(data);
        SGX_ADDR.transfer(FEE);
    }

    function cancel() public {
        address sender = msg.sender;
        if (sender != requester) {
            return;
        }

        requester = EMPTY_ADDR;
        msg.sender.call{value: FEE}("");
    }
}
